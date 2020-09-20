require 'ipaddr'
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
    update(xml: rexml.to_s)
  rescue StandardError => e
    destroy_and_undefine
    raise e
  end

  # We lookup by name so we also catch networks from previous test
  # suite runs that weren't properly cleaned up (e.g. aborted).
  def destroy_and_undefine
    old_net = @virt.lookup_network_by_name(@net_name)
    old_net.destroy if old_net.active?
    old_net.undefine
  rescue StandardError
    # Nothing to clean up
  end

  def net_xml
    REXML::Document.new(@net.xml_desc)
  end

  def update(xml: nil)
    xml = if block_given?
            xml = net_xml
            # The block modifies the mutable xml (REXML::Document) object
            # as a side-effect.
            yield xml
            xml.to_s
          elsif !xml.nil?
            xml.to_s
          else
            raise 'update needs either XML or a block'
          end
    destroy_and_undefine
    @net = @virt.define_network_xml(xml)
    @net.create
  end

  def bridge_name
    @net.bridge_name
  end

  def bridge_ip_addr
    IPAddr.new(net_xml.elements['network/ip'].attributes['address']).to_s
  end

  def bridge_mac
    File.open("/sys/class/net/#{bridge_name}/address", 'rb').read.chomp
  end
end

# XXX: giving up on a few worst offenders for now
# rubocop:disable Metrics/ClassLength
class VM
  attr_reader :domain, :domain_name, :display, :vmnet, :storage

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
    update(xml: rexml.to_s)
    set_vcpu($config['VCPUS']) if $config['VCPUS']
    @display = Display.new(@domain_name, x_display)
    set_cdrom_boot(TAILS_ISO)
    plug_network
    add_remote_shell_channel
  rescue StandardError => e
    destroy_and_undefine
    raise e
  end

  def domain_xml
    REXML::Document.new(@domain.xml_desc)
  end

  def update(xml: nil)
    xml = if block_given?
            xml = domain_xml
            # The block modifies the mutable xml (REXML::Document) object
            # as a side-effect.
            yield xml
            xml.to_s
          elsif !xml.nil?
            xml.to_s
          else
            raise 'update needs either XML or a block'
          end
    destroy_and_undefine
    @domain = @virt.define_domain_xml(xml)
  end

  # We lookup by name so we also catch domains from previous test
  # suite runs that weren't properly cleaned up (e.g. aborted).
  def destroy_and_undefine
    @display.stop if @display&.active?
    begin
      old_domain = @virt.lookup_domain_by_name(@domain_name)
      old_domain.destroy if old_domain.active?
      old_domain.undefine
    rescue StandardError
      # Nothing to clean up
    end
  end

  def real_mac(alias_name)
    domain_xml.elements["domain/devices/interface[@type='network']/" \
                        "alias[@name='#{alias_name}']"]
              .parent.elements['mac'].attributes['address'].to_s
  end

  def all_real_macs
    macs = []
    domain_xml
      .elements.each("domain/devices/interface[@type='network']") do |nic|
      macs << nic.elements['mac'].attributes['address'].to_s
    end
    macs
  end

  def set_hardware_clock(time)
    assert(!running?, 'The hardware clock cannot be set when the ' \
                             'VM is running')
    assert(time.instance_of?(Time), "Argument must be of type 'Time'")
    adjustment = (time - Time.now).to_i
    update do |xml|
      xml.elements['domain']
         .add_element('clock')
         .add_attributes('offset'     => 'variable',
                         'basis'      => 'utc',
                         'adjustment' => adjustment.to_s)
    end
  end

  def network_link_state
    domain_xml.elements['domain/devices/interface/link']
              .attributes['state']
  end

  def set_network_link_state(state)
    new_xml = domain_xml
    new_xml.elements['domain/devices/interface/link']
           .attributes['state'] = state
    if running?
      @domain.update_device(
        new_xml.elements['domain/devices/interface'].to_s
      )
    else
      update(xml: new_xml)
    end
  end

  def plug_network
    set_network_link_state('up')
  end

  def unplug_network
    set_network_link_state('down')
  end

  def set_boot_device(dev)
    raise 'boot settings can only be set for inactive vms' if running?

    update do |xml|
      xml.elements['domain/os/boot'].attributes['dev'] = dev
    end
  end

  def add_cdrom_device
    raise "Can't attach a CDROM device to a running domain" if running?

    update do |xml|
      if xml.elements["domain/devices/disk[@device='cdrom']"]
        raise 'A CDROM device already exists'
      end

      cdrom_rexml = REXML::Document.new(
        File.read("#{@xml_path}/cdrom.xml")
      ).root
      xml.elements['domain/devices'].add_element(cdrom_rexml)
    end
  end

  def remove_cdrom_device
    raise "Can't detach a CDROM device to a running domain" if running?

    update do |xml|
      cdrom_el = xml.elements["domain/devices/disk[@device='cdrom']"]
      raise 'No CDROM device is present' if cdrom_el.nil?

      xml.elements['domain/devices'].delete_element(cdrom_el)
    end
  end

  def eject_cdrom
    execute_successfully('/usr/bin/eject -m')
  end

  def remove_cdrom_image
    update do |xml|
      cdrom_el = xml.elements["domain/devices/disk[@device='cdrom']"]
      raise 'No CDROM device is present' if cdrom_el.nil?

      cdrom_el.delete_element('source')
    end
  rescue Libvirt::Error => e
    # While the CD-ROM is removed successfully we still get this
    # error, so let's ignore it.
    acceptable_error =
      'Call to virDomainUpdateDeviceFlags failed: internal error: unable to ' \
      "execute QEMU command 'eject': (Tray of device '.*' is not open|" \
      "Device '.*' is locked)"
    raise e unless Regexp.new(acceptable_error).match(e.to_s)
  end

  def set_cdrom_image(image)
    if image.nil? || (image == '')
      raise "Can't set cdrom image to an empty string"
    end

    remove_cdrom_image
    update do |xml|
      cdrom_el = xml.elements["domain/devices/disk[@device='cdrom']"]
      cdrom_el.add_element('source', { 'file' => image })
    end
  end

  def set_cdrom_boot(image)
    raise 'boot settings can only be set for inactive vms' if running?

    unless domain_xml.elements["domain/devices/disk[@device='cdrom']"]
      add_cdrom_device
    end
    set_cdrom_image(image)
    set_boot_device('cdrom')
  end

  def list_disk_devs
    ret = []
    domain_xml.elements.each('domain/devices/disk') do |e|
      ret << e.elements['target'].attribute('dev').to_s
    end
    ret
  end

  def plug_device(device_xml)
    if running?
      @domain.attach_device(device_xml.to_s)
    else
      update do |xml|
        xml.elements['domain/devices'].add_element(device_xml)
      end
    end
  end

  # XXX: giving up on a few worst offenders for now
  # rubocop:disable Metrics/AbcSize
  def plug_drive(name, type)
    raise "disk '#{name}' already plugged" if disk_plugged?(name)

    removable_usb = nil
    case type
    when 'removable usb', 'usb'
      type = 'usb'
      removable_usb = 'on'
    when 'non-removable usb'
      type = 'usb'
      removable_usb = 'off'
    end
    # Get the next free /dev/sdX on guest
    letter = 'a'
    dev = 'sd' + letter
    while list_disk_devs.include?(dev)
      letter = (letter[0].ord + 1).chr
      dev = 'sd' + letter
    end
    assert letter <= 'z'

    xml = REXML::Document.new(File.read("#{@xml_path}/disk.xml"))
    xml.elements['disk/source'].attributes['file'] = @storage.disk_path(name)
    xml.elements['disk/driver'].attributes['type'] = @storage.disk_format(name)
    xml.elements['disk/target'].attributes['dev'] = dev
    xml.elements['disk/target'].attributes['bus'] = type
    if removable_usb
      xml.elements['disk/target'].attributes['removable'] = removable_usb
    end

    plug_device(xml)
  end
  # rubocop:enable Metrics/AbcSize

  def disk_xml_desc(name)
    domain_xml.elements.each('domain/devices/disk') do |e|
      begin
        if e.elements['source'].attribute('file').to_s \
           == @storage.disk_path(name)
          return e.to_s
        end
      rescue StandardError
        next
      end
    end
    nil
  end

  def disk_rexml_desc(name)
    xml = disk_xml_desc(name)
    REXML::Document.new(xml) if xml
  end

  def unplug_drive(name)
    xml = disk_xml_desc(name)
    @domain.detach_device(xml)
  end

  def disk_type(dev)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.elements['target'].attribute('dev').to_s == dev
        return e.elements['driver'].attribute('type').to_s
      end
    end
    raise "No such disk device '#{dev}'"
  end

  def disk_dev(name)
    (rexml = disk_rexml_desc(name)) || return
    '/dev/' + rexml.elements['disk/target'].attribute('dev').to_s
  end

  def disk_name(dev)
    dev = File.basename(dev)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if /^#{e.elements['target'].attribute('dev')}/.match(dev)
        return File.basename(e.elements['source'].attribute('file').to_s)
      end
    end
    raise "No such disk device '#{dev}'"
  end

  def udisks_disk_dev(name)
    disk_dev(name).gsub('/dev/', '/org/freedesktop/UDisks/devices/')
  end

  def disk_detected?(name)
    (dev = disk_dev(name)) || (return false)
    execute("test -b #{dev}").success?
  end

  def disk_plugged?(name)
    !disk_xml_desc(name).nil?
  end

  def set_disk_boot(name, type)
    raise 'boot settings can only be set for inactive vms' if running?

    plug_drive(name, type) unless disk_plugged?(name)
    set_boot_device('hd')

    # We must remove the CDROM device to allow disk boot.
    if domain_xml.elements["domain/devices/disk[@device='cdrom']"]
      remove_cdrom_device
    end
  end

  def set_os_loader(type)
    raise 'boot settings can only be set for inactive vms' if running?
    raise 'unsupported OS loader type' unless type == 'UEFI'

    update do |xml|
      xml.elements['domain/os'].add_element(
        REXML::Document.new('<loader>/usr/share/ovmf/OVMF.fd</loader>')
      )
    end
  end

  def running?
    @domain.active?
  rescue StandardError
    false
  end

  def execute(cmd, **options)
    options[:user] ||= 'root'
    options[:spawn] = false unless options.key?(:spawn)
    if options[:libs]
      libs = options[:libs]
      options.delete(:libs)
      libs = [libs] unless libs.methods.include? :map
      cmds = libs.map do |lib_name|
        ". /usr/local/lib/tails-shell-library/#{lib_name}.sh"
      end
      cmds << cmd
      cmd = cmds.join(' && ')
    end
    RemoteShell::ShellCommand.new(self, cmd, **options)
  end

  def execute_successfully(*args, **options)
    p = execute(*args, **options)
    begin
      assert_vmcommand_success(p)
    rescue Test::Unit::AssertionFailedError => e
      raise ExecutionFailedInVM, e
    end
    p
  end

  def spawn(cmd, **options)
    options[:spawn] = true
    execute(cmd, **options)
  end

  def remote_shell_socket_path
    domain_rexml = REXML::Document.new(@domain.xml_desc)
    domain_rexml.elements.each('domain/devices/channel') do |e|
      target = e.elements['target']
      if target.attribute('name').to_s == 'org.tails.remote_shell.0'
        return e.elements['source'].attribute('path').to_s
      end
    end
    return nil
  end

  def add_remote_shell_channel
    if running?
      raise 'The remote shell channel can only be added for inactive vms'
    end

    if @remote_shell_socket_path.nil?
      @remote_shell_socket_path =
        '/tmp/remote-shell_' + random_alnum_string(8) + '.socket'
    end
    update do |xml|
      channel_xml = <<-XML
        <channel type='unix'>
          <source mode="bind" path='#{@remote_shell_socket_path}'/>
          <target type='virtio' name='org.tails.remote_shell.0'/>
        </channel>
      XML
      xml.elements['domain/devices'].add_element(
        REXML::Document.new(channel_xml)
      )
    end
  end

  def remote_shell_is_up?
    msg = 'hello?'
    Timeout.timeout(3) do
      execute_successfully("echo '#{msg}'").stdout.chomp == msg
    end
  rescue StandardError
    debug_log("The remote shell failed to respond within 3 seconds")
    false
  end

  def wait_until_remote_shell_is_up(timeout = 90)
    try_for(timeout, msg: 'Remote shell seems to be down') do
      remote_shell_is_up?
    end
  end

  def host_to_guest_time_sync
    host_time = DateTime.now.strftime('%s').to_s
    execute("date -s '@#{host_time}'").success?
  end

  def connected_to_network?
    nmcli_info = execute('nmcli device show eth0').stdout
    has_ipv4_addr = %r{^IP4.ADDRESS(\[\d+\])?:\s*([0-9./]+)$}.match(nmcli_info)
    network_link_state == 'up' && has_ipv4_addr
  end

  def process_running?(process)
    execute("pidof -x -o '%PPID' " + process).success?
  end

  def pidof(process)
    execute("pidof -x -o '%PPID' " + process).stdout.chomp.split
  end

  def select_virtual_desktop(desktop_number, user = LIVE_USER)
    assert(desktop_number >= 0 && desktop_number <= 3,
           'Only values between 0 and 1 are valid virtual desktop numbers')
    execute_successfully(
      "xdotool set_desktop '#{desktop_number}'",
      user: user
    )
  end

  def focus_window(window_title, user = LIVE_USER)
    do_focus = lambda do
      execute_successfully(
        "xdotool search --name '#{window_title}' windowactivate --sync",
        user: user
      )
    end

    begin
      do_focus.call
    rescue ExecutionFailedInVM
      # Often when xdotool fails to focus a window it'll work when retried
      # after redrawing the screen.  Switching to a new virtual desktop then
      # back seems to be a reliable way to handle this.
      # Sadly we have to rely on a lot of sleep() here since there's
      # little on the screen etc that we truly can rely on.
      sleep 5
      select_virtual_desktop(1)
      sleep 5
      select_virtual_desktop(0)
      sleep 5
      do_focus.call
    end
  rescue StandardError
    # noop
  end

  def file_exist?(file)
    execute("test -e '#{file}'").success?
  end

  def file_empty?(file)
    execute("test -s '#{file}'").failure?
  end

  def directory_exist?(directory)
    execute("test -d '#{directory}'").success?
  end

  def file_glob(expr)
    execute(
      <<-COMMAND
        bash -c '
          shopt -s globstar dotglob nullglob
          set -- #{expr}
          while [ -n "${1}" ]; do
            echo -n "${1}"
            echo -ne "\\0"
            shift
          done'
      COMMAND
    ).stdout.chomp.split("\0")
  end

  def file_open(path)
    f = RemoteShell::File.new(self, path)
    yield f if block_given?
    f
  end

  def file_content(paths)
    paths = [paths] unless paths.class == Array
    paths.reduce('') do |acc, path|
      acc + file_open(path).read
    end
  end

  def file_overwrite(path, lines)
    lines = lines.join("\n") if lines.class == Array
    file_open(path) { |f| return f.write(lines) }
  end

  def file_append(path, lines)
    lines = lines.join("\n") if lines.class == Array
    file_open(path) { |f| return f.append(lines) }
  end

  def set_clipboard(text)
    execute_successfully("echo -n '#{text}' | xsel --input --clipboard",
                         user: LIVE_USER)
  end

  def get_clipboard
    execute_successfully('xsel --output --clipboard', user: LIVE_USER).stdout
  end

  def internal_snapshot_xml(name)
    disk_devs = list_disk_devs
    disks_xml = "    <disks>\n"
    disk_devs.each do |dev|
      snapshot_type = disk_type(dev) == 'qcow2' ? 'internal' : 'no'
      disks_xml +=
        "      <disk name='#{dev}' snapshot='#{snapshot_type}'></disk>\n"
    end
    disks_xml += '    </disks>'
    <<~XML
      <domainsnapshot>
        <name>#{name}</name>
        <description>Snapshot for #{name}</description>
      #{disks_xml}
        </domainsnapshot>
    XML
  end

  def self.ram_only_snapshot_path(name)
    "#{$config['TMPDIR']}/#{name}-snapshot.memstate"
  end

  def save_internal_snapshot(name)
    xml = internal_snapshot_xml(name)
    @domain.snapshot_create_xml(xml)
  end

  def save_ram_only_snapshot(name)
    snapshot_path = VM.ram_only_snapshot_path(name)
    begin
      @domain.save(snapshot_path)
    rescue Guestfs::Error => e
      no_space_left_error =
        'Call to virDomainSaveFlags failed: operation failed: ' \
        '/usr/lib/libvirt/libvirt_iohelper: failure with .*: ' \
        'Unable to write .*: No space left on device'
      if Regexp.new(no_space_left_error).match(e.to_s)
        cmd = "du -ah \"#{$config['TMPDIR']}\" | sort -hr | head -n20"
        info_log("Output of \"#{cmd}\":\n" + `#{cmd}`)
        raise NoSpaceLeftError.New(e)
      else
        info_log('saving snapshot failed but was not a no-space-left error')
        raise e
      end
    end
  end

  def save_snapshot(name)
    debug_log("Saving snapshot '#{name}'...")
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
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.elements['driver'].attribute('type').to_s == 'qcow2'
        internal_snapshot = true
        break
      end
    end

    # Note: In this case the "opposite" of `internal_snapshot` is not
    # anything relating to external snapshots, but actually "memory
    # state"(-only) snapshots.
    if internal_snapshot
      save_internal_snapshot(name)
    else
      save_ram_only_snapshot(name)
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
    debug_log("Restoring snapshot '#{name}'...")
    @domain.destroy if running?
    @display.stop if @display&.active?
    # See comment in save_snapshot() for details on why we use two
    # different type of snapshots.
    potential_ram_only_snapshot_path = VM.ram_only_snapshot_path(name)
    if File.exist?(potential_ram_only_snapshot_path)
      Libvirt::Domain.restore(@virt, potential_ram_only_snapshot_path)
      @domain = @virt.lookup_domain_by_name(@domain_name)
    else
      begin
        potential_internal_snapshot = @domain.lookup_snapshot_by_name(name)
        @domain.revert_to_snapshot(potential_internal_snapshot)
      rescue Guestfs::Error, Libvirt::RetrieveError
        raise "The (internal nor external) snapshot #{name} may be known " \
              'by libvirt but it cannot be restored. ' \
              "To investigate, use 'virsh snapshot-list TailsToaster'. " \
              "To clean up old dangling snapshots, use 'virsh snapshot-delete'."
      end
    end
    @display.start
  end

  def self.remove_snapshot(name)
    old_domain = $virt.lookup_domain_by_name(LIBVIRT_DOMAIN_NAME)
    potential_ram_only_snapshot_path = VM.ram_only_snapshot_path(name)
    if File.exist?(potential_ram_only_snapshot_path)
      File.delete(potential_ram_only_snapshot_path)
    else
      snapshot = old_domain.lookup_snapshot_by_name(name)
      snapshot.delete
    end
  end

  def self.snapshot_exists?(name)
    return true if File.exist?(VM.ram_only_snapshot_path(name))

    old_domain = $virt.lookup_domain_by_name(LIBVIRT_DOMAIN_NAME)
    snapshot = old_domain.lookup_snapshot_by_name(name)
    !snapshot.nil?
  rescue Libvirt::RetrieveError
    false
  end

  def self.remove_all_snapshots
    Dir.glob("#{$config['TMPDIR']}/*-snapshot.memstate").each do |file|
      File.delete(file)
    end
    old_domain = $virt.lookup_domain_by_name(LIBVIRT_DOMAIN_NAME)
    old_domain.list_all_snapshots.each(&:delete)
  rescue Libvirt::RetrieveError
    # No such domain, so no snapshots either.
  end

  def start
    return if running?

    @domain.create
    @display.start
  end

  def reset
    @domain.reset if running?
  end

  def power_off
    @domain.destroy if running?
    @display.stop
  end

  def set_vcpu(nr_cpus)
    raise 'Cannot set the number of CPUs for a running domain' if running?

    update { |xml| xml.elements['domain/vcpu'].text = nr_cpus }
  end
end
# rubocop:enable Metrics/ClassLength
