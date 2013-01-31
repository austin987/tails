require 'libvirt'
require 'rexml/document'

class VM

  attr_reader :domain, :display, :ip, :ip6, :net

  def initialize
    domain_xml = ENV['DOM_XML'] || "#{Dir.pwd}/features/cucumber/domains/default.xml"
    net_xml = ENV['NET_XML'] || "#{Dir.pwd}/features/cucumber/domains/default_net.xml"
    @read_domain_xml = File.read(domain_xml)
    @read_net_xml = File.read(net_xml)
    @parsed_domain_xml = REXML::Document.new(@read_domain_xml)
    @parsed_net_xml = REXML::Document.new(@read_net_xml)
    @ip = @parsed_net_xml.elements['network/ip/dhcp/host/'].attributes['ip']
    @parsed_net_xml.elements.each('network/ip') do |e|
      if e.attribute('family').to_s == "ipv6"
        @ip6 = e.attribute('address').to_s
      end
    end
    @iso = ENV['ISO'] || get_last_iso
    @virt = Libvirt::open("qemu:///system")
    @domain_name = @parsed_domain_xml.elements['domain/name'].text
    @net_name = @parsed_net_xml.elements['network/name'].text
    setup_temp_domain
  end

  def clean_up_old
    begin
      old_domain = @virt.lookup_domain_by_name(@domain_name)
      old_domain.destroy if old_domain.active?
      old_domain.undefine
    rescue
    end
    begin
      old_net = @virt.lookup_network_by_name(@net_name)
      old_net.destroy if old_net.active?
      old_net.undefine
    rescue
    end
  end

  def setup_temp_domain
    clean_up_old
    setup_network
    @domain = @virt.define_domain_xml(@read_domain_xml)
    add_iso_to_domain
  end

  def setup_network
    @net = @virt.define_network_xml(@read_net_xml)
    @net.create
  end

  def plug_network
    xml = @parsed_domain_xml.elements['domain/devices/interface']
    xml.elements['link'].attributes['state'] = 'up'
    @domain.update_device(xml.to_s)
  end

  def unplug_network
    xml = @parsed_domain_xml.elements['domain/devices/interface']
    xml.elements['link'].attributes['state'] = 'down'
    @domain.update_device(xml.to_s)
  end

  def get_last_iso
    iso_name = Dir.glob("*.iso").sort_by {|f| File.mtime(f)}.last
    build_root_path.to_s + "/" + iso_name
  end

  def add_iso_to_domain
    xml = @parsed_domain_xml.elements['domain/devices/disk']
    xml.elements['source'].attributes['file'] = @iso
    @domain.update_device(xml.to_s)
  end

  def is_running?
    @domain.active?
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
    # Undefine current domain so it can be restored
    @domain.destroy if @domain.active?
    @domain.undefine
    Libvirt::Domain::restore(@virt, path)
    @domain = @virt.lookup_domain_by_name(@domain_name)
    @display = Display.new(@domain_name)
    @display.start
  end

  def start
    @domain.destroy if @domain.active?
    @domain.create
    @display = Display.new(@domain_name)
    @display.start
  end

  def stop
    @domain.destroy if @domain.active?
    begin
      @domain.undefine
    rescue
      # FIXME: why does this happen after snapshot restore?
      puts "Domain couldn't be undefined"
    end
    @net.destroy if @net.active?
    @net.undefine
    @display.stop
  end

  def take_screenshot(description)
    @display.take_screenshot(description)
  end

  def get_remote_shell_port
    @parsed_domain_xml.elements.each('domain/devices/serial') do |e|
      if e.attribute('type').to_s == "tcp"
        return e.elements['source'].attribute('service').to_s.to_i
      end
    end
  end

end
