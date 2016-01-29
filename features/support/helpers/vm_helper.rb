require 'libvirt'
require 'rexml/document'

class ExecutionFailedInVM < StandardError
end

class VMNet

  attr_reader :net_name, :net

  def initialize(virt, xml_path)
    @virt = virt
    @net_name = LIBVIRT_NETWORK_NAME
    net_xml = File.read("#{xml_path}/default_net.xml")
    rexml = REXML::Document.new(net_xml)
    rexml.elements['network'].add_element('name')
    rexml.elements['network/name'].text = @net_name
    rexml.elements['network'].add_element('uuid')
    rexml.elements['network/uuid'].text = LIBVIRT_NETWORK_UUID
    update(rexml.to_s)
  rescue Exception => e
    destroy_and_undefine
    raise e
  end

  # We lookup by name so we also catch networks from previous test
  # suite runs that weren't properly cleaned up (e.g. aborted).
  def destroy_and_undefine
    begin
      old_net = @virt.lookup_network_by_name(@net_name)
      old_net.destroy if old_net.active?
      old_net.undefine
    rescue
    end
  end

  def update(xml)
    destroy_and_undefine
    @net = @virt.define_network_xml(xml)
    @net.create
  end

  def bridge_name
    @net.bridge_name
  end

  def bridge_ip_addr
    net_xml = REXML::Document.new(@net.xml_desc)
    IPAddr.new(net_xml.elements['network/ip'].attributes['address']).to_s
  end

  def guest_real_mac
    net_xml = REXML::Document.new(@net.xml_desc)
    net_xml.elements['network/ip/dhcp/host/'].attributes['mac']
  end

  def bridge_mac
    File.open("/sys/class/net/#{bridge_name}/address", "rb").read.chomp
  end
end


class VM

  attr_reader :domain, :display, :vmnet, :storage

  def initialize(virt, xml_path, vmnet, storage, x_display)
    @virt = virt
    @xml_path = xml_path
    @vmnet = vmnet
    @storage = storage
    @domain_name = LIBVIRT_DOMAIN_NAME
    default_domain_xml = File.read("#{@xml_path}/default.xml")
    rexml = REXML::Document.new(default_domain_xml)
    rexml.elements['domain'].add_element('name')
    rexml.elements['domain/name'].text = @domain_name
    rexml.elements['domain'].add_element('uuid')
    rexml.elements['domain/uuid'].text = LIBVIRT_DOMAIN_UUID
    update(rexml.to_s)
    @display = Display.new(@domain_name, x_display)
    set_cdrom_boot(TAILS_ISO)
    plug_network
  rescue Exception => e
    destroy_and_undefine
    raise e
  end

  def update(xml)
    destroy_and_undefine
    @domain = @virt.define_domain_xml(xml)
  end

  # We lookup by name so we also catch domains from previous test
  # suite runs that weren't properly cleaned up (e.g. aborted).
  def destroy_and_undefine
    @display.stop if @display && @display.active?
    begin
      old_domain = @virt.lookup_domain_by_name(@domain_name)
      old_domain.destroy if old_domain.active?
      old_domain.undefine
    rescue
    end
  end

  def real_mac
    @vmnet.guest_real_mac
  end

  def set_hardware_clock(time)
    assert(not(is_running?), 'The hardware clock cannot be set when the ' +
                             'VM is running')
    assert(time.instance_of?(Time), "Argument must be of type 'Time'")
    adjustment = (time - Time.now).to_i
    domain_rexml = REXML::Document.new(@domain.xml_desc)
    clock_rexml_element = domain_rexml.elements['domain'].add_element('clock')
    clock_rexml_element.add_attributes('offset' => 'variable',
                                       'basis' => 'utc',
                                       'adjustment' => adjustment.to_s)
    update(domain_rexml.to_s)
  end

  def set_network_link_state(state)
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/devices/interface/link'].attributes['state'] = state
    if is_running?
      @domain.update_device(domain_xml.elements['domain/devices/interface'].to_s)
    else
      update(domain_xml.to_s)
    end
  end

  def plug_network
    set_network_link_state('up')
  end

  def unplug_network
    set_network_link_state('down')
  end

  def set_boot_device(dev)
    if is_running?
      raise "boot settings can only be set for inactive vms"
    end
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/os/boot'].attributes['dev'] = dev
    update(domain_xml.to_s)
  end

  def set_cdrom_image(image)
    image = nil if image == ''
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.attribute('device').to_s == "cdrom"
        if image.nil?
          e.elements.delete('source')
        else
          if ! e.elements['source']
            e.add_element('source')
          end
          e.elements['source'].attributes['file'] = image
        end
        if is_running?
          @domain.update_device(e.to_s)
        else
          update(domain_xml.to_s)
        end
      end
    end
  end

  def remove_cdrom
    set_cdrom_image(nil)
  rescue Libvirt::Error => e
    # While the CD-ROM is removed successfully we still get this
    # error, so let's ignore it.
    acceptable_error =
      "Call to virDomainUpdateDeviceFlags failed: internal error: unable to " +
      "execute QEMU command 'eject': (Tray of device '.*' is not open|" +
      "Device '.*' is locked)"
    raise e if not(Regexp.new(acceptable_error).match(e.to_s))
  end

  def set_cdrom_boot(image)
    if is_running?
      raise "boot settings can only be set for inactive vms"
    end
    set_boot_device('cdrom')
    set_cdrom_image(image)
  end

  def list_disk_devs
    ret = []
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      ret << e.elements['target'].attribute('dev').to_s
    end
    return ret
  end

  def plug_drive(name, type)
    if disk_plugged?(name)
      raise "disk '#{name}' already plugged"
    end
    removable_usb = nil
    case type
    when "removable usb", "usb"
      type = "usb"
      removable_usb = "on"
    when "non-removable usb"
      type = "usb"
      removable_usb = "off"
    end
    # Get the next free /dev/sdX on guest
    letter = 'a'
    dev = "sd" + letter
    while list_disk_devs.include?(dev)
      letter = (letter[0].ord + 1).chr
      dev = "sd" + letter
    end
    assert letter <= 'z'

    xml = REXML::Document.new(File.read("#{@xml_path}/disk.xml"))
    xml.elements['disk/source'].attributes['file'] = @storage.disk_path(name)
    xml.elements['disk/driver'].attributes['type'] = @storage.disk_format(name)
    xml.elements['disk/target'].attributes['dev'] = dev
    xml.elements['disk/target'].attributes['bus'] = type
    xml.elements['disk/target'].attributes['removable'] = removable_usb if removable_usb

    if is_running?
      @domain.attach_device(xml.to_s)
    else
      domain_xml = REXML::Document.new(@domain.xml_desc)
      domain_xml.elements['domain/devices'].add_element(xml)
      update(domain_xml.to_s)
    end
  end

  def disk_xml_desc(name)
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      begin
        if e.elements['source'].attribute('file').to_s == @storage.disk_path(name)
          return e.to_s
        end
      rescue
        next
      end
    end
    return nil
  end

  def disk_rexml_desc(name)
    xml = disk_xml_desc(name)
    if xml
      return REXML::Document.new(xml)
    else
      return nil
    end
  end

  def unplug_drive(name)
    xml = disk_xml_desc(name)
    @domain.detach_device(xml)
  end

  def disk_type(dev)
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.elements['target'].attribute('dev').to_s == dev
        return e.elements['driver'].attribute('type').to_s
      end
    end
    raise "No such disk device '#{dev}'"
  end

  def disk_dev(name)
    rexml = disk_rexml_desc(name) or return nil
    return "/dev/" + rexml.elements['disk/target'].attribute('dev').to_s
  end

  def disk_name(dev)
    dev = File.basename(dev)
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if /^#{e.elements['target'].attribute('dev').to_s}/.match(dev)
        return File.basename(e.elements['source'].attribute('file').to_s)
      end
    end
    raise "No such disk device '#{dev}'"
  end

  def udisks_disk_dev(name)
    return disk_dev(name).gsub('/dev/', '/org/freedesktop/UDisks/devices/')
  end

  def disk_detected?(name)
    dev = disk_dev(name) or return false
    return execute("test -b #{dev}").success?
  end

  def disk_plugged?(name)
    return not(disk_xml_desc(name).nil?)
  end

  def set_disk_boot(name, type)
    if is_running?
      raise "boot settings can only be set for inactive vms"
    end
    plug_drive(name, type) if not(disk_plugged?(name))
    set_boot_device('hd')
    # For some reason setting the boot device doesn't prevent cdrom
    # boot unless it's empty
    remove_cdrom
  end

  # XXX-9p: Shares don't work together with snapshot save+restore. See
  # XXX-9p in common_steps.rb for more information.
  def add_share(source, tag)
    if is_running?
      raise "shares can only be added to inactive vms"
    end
    # The complete source directory must be group readable by the user
    # running the virtual machine, and world readable so the user inside
    # the VM can access it (since we use the passthrough security model).
    FileUtils.chown_R(nil, "libvirt-qemu", source)
    FileUtils.chmod_R("go+rX", source)
    xml = REXML::Document.new(File.read("#{@xml_path}/fs_share.xml"))
    xml.elements['filesystem/source'].attributes['dir'] = source
    xml.elements['filesystem/target'].attributes['dir'] = tag
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/devices'].add_element(xml)
    update(domain_xml.to_s)
  end

  def list_shares
    list = []
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/filesystem') do |e|
      list << e.elements['target'].attribute('dir').to_s
    end
    return list
  end

  def set_ram_size(size, unit = "KiB")
    raise "System memory can only be added to inactive vms" if is_running?
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/memory'].text = size
    domain_xml.elements['domain/memory'].attributes['unit'] = unit
    domain_xml.elements['domain/currentMemory'].text = size
    domain_xml.elements['domain/currentMemory'].attributes['unit'] = unit
    update(domain_xml.to_s)
  end

  def get_ram_size_in_bytes
    domain_xml = REXML::Document.new(@domain.xml_desc)
    unit = domain_xml.elements['domain/memory'].attribute('unit').to_s
    size = domain_xml.elements['domain/memory'].text.to_i
    return convert_to_bytes(size, unit)
  end

  def set_arch(arch)
    raise "System architecture can only be set to inactive vms" if is_running?
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/os/type'].attributes['arch'] = arch
    update(domain_xml.to_s)
  end

  def add_hypervisor_feature(feature)
    raise "Hypervisor features can only be added to inactive vms" if is_running?
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/features'].add_element(feature)
    update(domain_xml.to_s)
  end

  def drop_hypervisor_feature(feature)
    raise "Hypervisor features can only be fropped from inactive vms" if is_running?
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/features'].delete_element(feature)
    update(domain_xml.to_s)
  end

  def disable_pae_workaround
    # add_hypervisor_feature("nonpae") results in a libvirt error, and
    # drop_hypervisor_feature("pae") alone won't disable pae. Hence we
    # use this workaround.
    xml = <<EOF
  <qemu:commandline xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
    <qemu:arg value='-cpu'/>
    <qemu:arg value='qemu32,-pae'/>
  </qemu:commandline>
EOF
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain'].add_element(REXML::Document.new(xml))
    update(domain_xml.to_s)
  end

  def set_os_loader(type)
    if is_running?
      raise "boot settings can only be set for inactive vms"
    end
    if type == 'UEFI'
      domain_xml = REXML::Document.new(@domain.xml_desc)
      domain_xml.elements['domain/os'].add_element(REXML::Document.new(
        '<loader>/usr/share/ovmf/OVMF.fd</loader>'
      ))
      update(domain_xml.to_s)
    else
      raise "unsupported OS loader type"
    end
  end

  def is_running?
    begin
      return @domain.active?
    rescue
      return false
    end
  end

  def execute(cmd, options = {})
    options[:user] ||= "root"
    options[:spawn] ||= false
    if options[:libs]
      libs = options[:libs]
      options.delete(:libs)
      libs = [libs] if not(libs.methods.include? :map)
      cmds = libs.map do |lib_name|
        ". /usr/local/lib/tails-shell-library/#{lib_name}.sh"
      end
      cmds << cmd
      cmd = cmds.join(" && ")
    end
    return VMCommand.new(self, cmd, options)
  end

  def execute_successfully(*args)
    p = execute(*args)
    begin
      assert_vmcommand_success(p)
    rescue Test::Unit::AssertionFailedError => e
      raise ExecutionFailedInVM.new(e)
    end
    return p
  end

  def spawn(cmd, options = {})
    options[:spawn] = true
    return execute(cmd, options)
  end

  def wait_until_remote_shell_is_up(timeout = 90)
    VMCommand.wait_until_remote_shell_is_up(self, timeout)
  end

  def host_to_guest_time_sync
    host_time= DateTime.now.strftime("%s").to_s
    execute("date -s '@#{host_time}'").success?
  end

  def has_network?
    return execute("/sbin/ifconfig eth0 | grep -q 'inet addr'").success?
  end

  def has_process?(process)
    return execute("pidof -x -o '%PPID' " + process).success?
  end

  def pidof(process)
    return execute("pidof -x -o '%PPID' " + process).stdout.chomp.split
  end

  def select_virtual_desktop(desktop_number, user = LIVE_USER)
    assert(desktop_number >= 0 && desktop_number <=3,
           "Only values between 0 and 3 are valid virtual desktop numbers")
    execute_successfully(
      "xdotool set_desktop '#{desktop_number}'",
      :user => user
    )
  end

  def focus_window(window_title, user = LIVE_USER)
    def do_focus(window_title, user)
      execute_successfully(
        "xdotool search --name '#{window_title}' windowactivate --sync",
        :user => user
      )
    end

    begin
      do_focus(window_title, user)
    rescue ExecutionFailedInVM
      # Often when xdotool fails to focus a window it'll work when retried
      # after redrawing the screen.  Switching to a new virtual desktop then
      # back seems to be a reliable way to handle this.
      select_virtual_desktop(3)
      select_virtual_desktop(0)
      sleep 5 # there aren't any visual indicators which can be used here
      do_focus(window_title, user)
    end
  end

  def file_exist?(file)
    execute("test -e '#{file}'").success?
  end

  def directory_exist?(directory)
    execute("test -d '#{directory}'").success?
  end

  def file_content(file, user = 'root')
    # We don't quote #{file} on purpose: we sometimes pass environment variables
    # or globs that we want to be interpreted by the shell.
    cmd = execute("cat #{file}", :user => user)
    assert(cmd.success?,
           "Could not cat '#{file}':\n#{cmd.stdout}\n#{cmd.stderr}")
    return cmd.stdout
  end

  def file_append(file, lines, user = 'root')
    lines = lines.split("\n") if lines.class == String
    lines.each do |line|
      cmd = execute("echo '#{line}' >> '#{file}'", :user => user)
      assert(cmd.success?,
             "Could not append to '#{file}':\n#{cmd.stdout}\n#{cmd.stderr}")
    end
  end

  def set_clipboard(text)
    execute_successfully("echo -n '#{text}' | xsel --input --clipboard",
                         :user => LIVE_USER)
  end

  def get_clipboard
    execute_successfully("xsel --output --clipboard", :user => LIVE_USER).stdout
  end

  def internal_snapshot_xml(name)
    disk_devs = list_disk_devs
    disks_xml = "    <disks>\n"
    for dev in disk_devs
      snapshot_type = disk_type(dev) == "qcow2" ? 'internal' : 'no'
      disks_xml +=
        "      <disk name='#{dev}' snapshot='#{snapshot_type}'></disk>\n"
    end
    disks_xml += "    </disks>"
    return <<-EOF
<domainsnapshot>
  <name>#{name}</name>
  <description>Snapshot for #{name}</description>
#{disks_xml}
  </domainsnapshot>
EOF
  end

  def VM.ram_only_snapshot_path(name)
    return "#{$config["TMPDIR"]}/#{name}-snapshot.memstate"
  end

  def save_snapshot(name)
    # If we have no qcow2 disk device, we'll use "memory state"
    # snapshots, and if we have at least one qcow2 disk device, we'll
    # use internal "system checkpoint" (memory + disks) snapshots. We
    # have to do this since internal snapshots don't work when no
    # such disk is available. We can do this with external snapshots,
    # which are better in many ways, but libvirt doesn't know how to
    # restore (revert back to) them yet.
    # WARNING: If only transient disks, i.e. disks that were plugged
    # after starting the domain, are used then the memory state will
    # be dropped. External snapshots would also fix this.
    internal_snapshot = false
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.elements['driver'].attribute('type').to_s == "qcow2"
        internal_snapshot = true
        break
      end
    end

    # Note: In this case the "opposite" of `internal_snapshot` is not
    # anything relating to external snapshots, but actually "memory
    # state"(-only) snapshots.
    if internal_snapshot
      xml = internal_snapshot_xml(name)
      @domain.snapshot_create_xml(xml)
    else
      snapshot_path = VM.ram_only_snapshot_path(name)
      @domain.save(snapshot_path)
      # For consistency with the internal snapshot case (which is
      # "live", so the domain doesn't go down) we immediately restore
      # the snapshot.
      # Assumption: that *immediate* save + restore doesn't mess up
      # with network state and similar, and is fast enough to not make
      # the clock drift too much.
      restore_snapshot(name)
    end
  end

  def restore_snapshot(name)
    @domain.destroy if is_running?
    @display.stop if @display and @display.active?
    # See comment in save_snapshot() for details on why we use two
    # different type of snapshots.
    potential_ram_only_snapshot_path = VM.ram_only_snapshot_path(name)
    if File.exist?(potential_ram_only_snapshot_path)
      Libvirt::Domain::restore(@virt, potential_ram_only_snapshot_path)
      @domain = @virt.lookup_domain_by_name(@domain_name)
    else
      begin
        potential_internal_snapshot = @domain.lookup_snapshot_by_name(name)
        @domain.revert_to_snapshot(potential_internal_snapshot)
      rescue Libvirt::RetrieveError
        raise "No such (internal nor external) snapshot #{name}"
      end
    end
    @display.start
  end

  def VM.remove_snapshot(name)
    old_domain = $virt.lookup_domain_by_name(LIBVIRT_DOMAIN_NAME)
    potential_ram_only_snapshot_path = VM.ram_only_snapshot_path(name)
    if File.exist?(potential_ram_only_snapshot_path)
      File.delete(potential_ram_only_snapshot_path)
    else
      snapshot = old_domain.lookup_snapshot_by_name(name)
      snapshot.delete
    end
  end

  def VM.snapshot_exists?(name)
    return true if File.exist?(VM.ram_only_snapshot_path(name))
    old_domain = $virt.lookup_domain_by_name(LIBVIRT_DOMAIN_NAME)
    snapshot = old_domain.lookup_snapshot_by_name(name)
    return snapshot != nil
  rescue Libvirt::RetrieveError
    return false
  end

  def VM.remove_all_snapshots
    Dir.glob("#{$config["TMPDIR"]}/*-snapshot.memstate").each do |file|
      File.delete(file)
    end
    old_domain = $virt.lookup_domain_by_name(LIBVIRT_DOMAIN_NAME)
    old_domain.list_all_snapshots.each { |snapshot| snapshot.delete }
  rescue Libvirt::RetrieveError
    # No such domain, so no snapshots either.
  end

  def start
    return if is_running?
    @domain.create
    @display.start
  end

  def reset
    @domain.reset if is_running?
  end

  def power_off
    @domain.destroy if is_running?
    @display.stop
  end

  def take_screenshot(description)
    @display.take_screenshot(description)
  end

  def get_remote_shell_port
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/serial') do |e|
      if e.attribute('type').to_s == "tcp"
        return e.elements['source'].attribute('service').to_s.to_i
      end
    end
  end

end
