require 'libvirt'
require 'rexml/document'

class VM

  attr_reader :domain, :ip, :net

  def initialize
    domain_xml = ENV['DOM_XML'] || Dir.pwd + "/cucumber/domains/default.xml"
    net_xml = ENV['NET_XML'] || Dir.pwd + "/cucumber/domains/default_net.xml"
    @iso = ENV['ISO'] || get_last_iso
    @virt = Libvirt::open("qemu:///system")
    setup_temp_domain(domain_xml, net_xml)
  end

  def setup_temp_domain(domain_xml, net_xml)
    setup_network(net_xml)
    @domain = @virt.define_domain_xml(File.read(domain_xml))
    add_iso_to_domain
  end

  def setup_network(net_xml)
    @net = @virt.define_network_xml(File.read(net_xml))
    @net.create
    @ip = REXML::Document.new(@net.xml_desc).elements['network/ip/dhcp/host/'].attributes['ip']
  end

  def get_last_iso
    build_root_path = Pathname.new(Dir.pwd).parent
    Dir.chdir(build_root_path)
    iso_name = Dir.glob("*.iso").sort_by {|f| File.mtime(f)}.last
    build_root_path.to_s + "/" + iso_name
  end

  def add_iso_to_domain
    xml = <<EOF
    <disk>
      <source file="#{@iso}"/>
      <target dev='hdc' bus='ide'/>
    </disk>
EOF
    @domain.update_device(xml)
  end

  def is_running?
    @domain.active?
  end

  def execute
    # TODO: could allow to run commands on the tails VM
    # Might deserve a whole helper though.
  end

  def start
    @domain.destroy if @domain.active?
    @domain.create
  end

  def stop
    @domain.destroy if @domain.active?
    @domain.undefine
    @net.destroy if @net.active?
    @net.undefine
  end
end
