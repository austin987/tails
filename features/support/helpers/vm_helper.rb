require 'libvirt'
require 'rexml/document'

class VMNet

  attr_reader :net_name, :net, :ip, :mac, :bridge_name

  def initialize(virt, xml_path)
    @virt = virt
    net_xml = File.read("#{xml_path}/default_net.xml")
    update(net_xml)
  rescue Exception => e
    clean_up
    raise e
  end

  def clean_up
    begin
      net = @virt.lookup_network_by_name(@net_name)
      net.destroy if net.active?
      net.undefine
    rescue
    end
  end

  def update(xml)
    net_xml = REXML::Document.new(xml)
    @net_name = net_xml.elements['network/name'].text
    clean_up
    @net = @virt.define_network_xml(xml)
    @net.create
    @ip  = net_xml.elements['network/ip/dhcp/host/'].attributes['ip']
    @mac = net_xml.elements['network/ip/dhcp/host/'].attributes['mac']
    @bridge_name = @net.bridge_name
  end

  def destroy
    @net.destroy if net.active?
    @net.undefine
  end

  def bridge_mac
    File.open("/sys/class/net/#{@bridge_name}/address", "rb").read.chomp
  end

end


class VM

  attr_reader :domain, :display, :ip, :mac, :vmnet, :storage

  def initialize(virt, xml_path, vmnet, storage, x_display)
    @virt = virt
    @xml_path = xml_path
    @vmnet = vmnet
    @storage = storage
    default_domain_xml = File.read("#{@xml_path}/default.xml")
    update(default_domain_xml)
    @display = Display.new(@domain_name, x_display)
    set_cdrom_boot(TAILS_ISO)
    plug_network
  rescue Exception => e
    clean_up
    raise e
  end

  def update(xml)
    domain_xml = REXML::Document.new(xml)
    @domain_name = domain_xml.elements['domain/name'].text
    clean_up
    @domain = @virt.define_domain_xml(xml)
  end

  def clean_up
    begin
      domain = @virt.lookup_domain_by_name(@domain_name)
      domain.destroy if domain.active?
      domain.undefine
    rescue
    end
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

  def set_cdrom_tray_state(state)
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.attribute('device').to_s == "cdrom"
        e.elements['target'].attributes['tray'] = state
        if is_running?
          @domain.update_device(e.to_s)
        else
          update(domain_xml.to_s)
        end
      end
    end
  end

  def eject_cdrom
    set_cdrom_tray_state('open')
  end

  def close_cdrom
    set_cdrom_tray_state('closed')
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
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.attribute('device').to_s == "cdrom"
        if ! e.elements['source']
          e.add_element('source')
        end
        e.elements['source'].attributes['file'] = image
        if is_running?
          @domain.update_device(e.to_s, Libvirt::Domain::DEVICE_MODIFY_FORCE)
        else
          update(domain_xml.to_s)
        end
      end
    end
  end

  def remove_cdrom
    set_cdrom_image('')
  end

  def set_cdrom_boot(image)
    if is_running?
      raise "boot settings can only be set for inactice vms"
    end
    set_boot_device('cdrom')
    set_cdrom_image(image)
    close_cdrom
  end

  def plug_drive(name, type)
    # Get the next free /dev/sdX on guest
    used_devs = []
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk/target') do |e|
      used_devs <<= e.attribute('dev').to_s
    end
    letter = 'a'
    dev = "sd" + letter
    while used_devs.include? dev
      letter = (letter[0].ord + 1).chr
      dev = "sd" + letter
    end
    assert letter <= 'z'

    xml = REXML::Document.new(File.read("#{@xml_path}/disk.xml"))
    xml.elements['disk/source'].attributes['file'] = @storage.disk_path(name)
    xml.elements['disk/driver'].attributes['type'] = @storage.disk_format(name)
    xml.elements['disk/target'].attributes['dev'] = dev
    xml.elements['disk/target'].attributes['bus'] = type
    if type == "usb"
      xml.elements['disk/target'].attributes['removable'] = 'on'
    end

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

  def unplug_drive(name)
    xml = disk_xml_desc(name)
    @domain.detach_device(xml)
  end

  def disk_dev(name)
    xml = REXML::Document.new(disk_xml_desc(name))
    return "/dev/" + xml.elements['disk/target'].attribute('dev').to_s
  end

  def disk_detected?(name)
    return execute("test -b #{disk_dev(name)}").success?
  end

  def set_disk_boot(name, type)
    if is_running?
      raise "boot settings can only be set for inactive vms"
    end
    plug_drive(name, type)
    set_boot_device('hd')
    # For some reason setting the boot device doesn't prevent cdrom
    # boot unless it's empty
    remove_cdrom
  end

  # XXX-9p: Shares don't work together with snapshot save+restore. See
  # XXX-9p in common_steps.rb for more information.
  def add_share(source, tag)
    if is_running?
      raise "shares can only be added to inactice vms"
    end
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
    raise "System memory can only be added to inactice vms" if is_running?
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
    raise "System architecture can only be set to inactice vms" if is_running?
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/os/type'].attributes['arch'] = arch
    update(domain_xml.to_s)
  end

  def add_hypervisor_feature(feature)
    raise "Hypervisor features can only be added to inactice vms" if is_running?
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/features'].add_element(feature)
    update(domain_xml.to_s)
  end

  def drop_hypervisor_feature(feature)
    raise "Hypervisor features can only be fropped from inactice vms" if is_running?
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
    <qemu:arg value='pentium,-pae'/>
  </qemu:commandline>
EOF
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain'].add_element(REXML::Document.new(xml))
    update(domain_xml.to_s)
  end

  def set_os_loader(type)
    if is_running?
      raise "boot settings can only be set for inactice vms"
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

  def execute(cmd, user = "root")
    return VMCommand.new(self, cmd, { :user => user, :spawn => false })
  end

  def execute_successfully(cmd, user = "root")
    p = execute(cmd, user)
    assert_vmcommand_success(p)
    return p
  end

  def spawn(cmd, user = "root")
    return VMCommand.new(self, cmd, { :user => user, :spawn => true })
  end

  def wait_until_remote_shell_is_up(timeout = 30)
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

  def file_exist?(file)
    execute("test -e #{file}").success?
  end

  def file_content(file, user = 'root')
    # We don't quote #{file} on purpose: we sometimes pass environment variables
    # or globs that we want to be interpreted by the shell.
    cmd = execute("cat #{file}", user)
    assert(cmd.success?,
           "Could not cat '#{file}':\n#{cmd.stdout}\n#{cmd.stderr}")
    return cmd.stdout
  end

  def save_snapshot(path)
    @domain.save(path)
    @display.stop
  end

  def restore_snapshot(path)
    # Clean up current domain so its snapshot can be restored
    clean_up
    Libvirt::Domain::restore(@virt, path)
    @domain = @virt.lookup_domain_by_name(@domain_name)
    @display.start
  end

  def start
    return if is_running?
    @domain.create
    @display.start
  end

  def reset
    # ruby-libvirt 0.4 does not support the reset method.
    # XXX: Once we use Jessie, use @domain.reset instead.
    system("virsh -c qemu:///system reset " + @domain_name) if is_running?
  end

  def power_off
    @domain.destroy if is_running?
    @display.stop
  end

  def destroy
    clean_up
    power_off
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
