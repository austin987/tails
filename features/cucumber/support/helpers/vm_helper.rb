require 'libvirt'
require 'rexml/document'

class VM

  attr_reader :domain, :display, :ip, :ip6, :net

  def initialize
    @virt = Libvirt::open("qemu:///system")
    domain_xml = ENV['DOM_XML'] || "#{Dir.pwd}/features/cucumber/domains/default.xml"
    net_xml = ENV['NET_XML'] || "#{Dir.pwd}/features/cucumber/domains/default_net.xml"
    read_domain_xml = File.read(domain_xml)
    update_domain(read_domain_xml)
    read_net_xml = File.read(net_xml)
    update_net(read_net_xml)
    iso = ENV['ISO'] || get_last_iso
    plug_network
  end

  def update_domain(xml)
    domain_xml = REXML::Document.new(xml)
    @domain_name = domain_xml.elements['domain/name'].text
    clean_up_domain
    @domain = @virt.define_domain_xml(xml)
  end

  def update_net(xml)
    net_xml = REXML::Document.new(xml)
    @net_name = net_xml.elements['network/name'].text
    @ip = net_xml.elements['network/ip/dhcp/host/'].attributes['ip']
    net_xml.elements.each('network/ip') do |e|
      if e.attribute('family').to_s == "ipv6"
        @ip6 = e.attribute('address').to_s
      end
    end
    clean_up_net
    @net = @virt.define_network_xml(xml)
    @net.create
  end

  def clean_up_domain
    begin
      domain = @virt.lookup_domain_by_name(@domain_name)
      domain.destroy if domain.active?
      domain.undefine
    rescue
    end
  end

  def clean_up_net
    begin
      net = @virt.lookup_network_by_name(@net_name)
      net.destroy if net.active?
      net.undefine
    rescue
    end
  end

  def set_network_link_state(state)
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements['domain/devices/interface/link'].attributes['state'] = state
    if is_running?
      @domain.update_device(domain_xml.elements['domain/devices/interface'].to_s)
    else
      update_domain(domain_xml.to_s)
    end
  end

  def plug_network
    set_network_link_state('up')
  end

  def unplug_network
    set_network_link_state('down')
  end

  def get_last_iso
    iso_name = Dir.glob("*.iso").sort_by {|f| File.mtime(f)}.last
    build_root_path.to_s + "/" + iso_name
  end

  def set_cdrom_tray_state(state)
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.attribute('device').to_s == "cdrom"
        e.elements['target'].attributes['tray'] = state
        if is_running?
          @domain.update_device(e.to_s)
        else
          update_domain(domain_xml.to_s)
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

  def set_cdrom_image(image)
    if is_running?
      raise "boot settings can only be set for inactice vms"
    end
    domain_xml = REXML::Document.new(@domain.xml_desc)
    domain_xml.elements.each('domain/devices/disk') do |e|
      if e.attribute('device').to_s == "cdrom"
        if ! e.elements['source']
          e.add_element('source')
        end
        e.elements['source'].attributes['file'] = image
        if is_running?
          @domain.update_device(e.to_s)
        else
          update_domain(domain_xml.to_s)
        end
      end
    end
  end

  def remove_cdrom
    set_cdrom_image('')
  end

  def is_running?
    begin
      return @domain.active?
    rescue
      return false
    end
  end

  def execute(cmd, user = "root")
    return VMCommand.new(self, cmd, user)
  end

  def host_to_guest_time_sync
    host_time= DateTime.now.strftime("%s").to_s
    execute("date -s '@#{host_time}'").success?
  end

  def save_snapshot(path)
    @domain.save(path)
    @display.stop
  end

  def restore_snapshot(path)
    # Clean up current domain so its snapshot can be restored
    clean_up_domain
    Libvirt::Domain::restore(@virt, path)
    @domain = @virt.lookup_domain_by_name(@domain_name)
    @display = Display.new(@domain_name)
    @display.start
  end

  def start
    return if is_running?
    @domain.create
    @display = Display.new(@domain_name)
    @display.start
  end

  def stop
    clean_up_domain
    clean_up_net
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
