require 'libvirt'

class VM

  def initialize(domain)
    @iso = ENV['ISO'] || get_last_iso
    @virt = Libvirt::open("qemu:///system")
    @dom = @virt.lookup_domain_by_name(domain)
    add_iso_to_domain
  end

  def get_last_iso
    build_root_path = Pathname.new(ENV['PWD']).parent.parent
    Dir.chdir(build_root_path)
    iso_name = Dir.glob("*.iso").sort_by {|f| File.mtime(f)}.last
    build_root_path.to_s + "/" + iso_name
  end

  def add_iso_to_domain
    xml = <<EOF
    <disk>
      <source file="#{ENV['PWD']}/#{@iso}"/>
      <target dev='hdc' bus='ide'/>
    </disk>
EOF
    @dom.update_device(xml)
  end

  def is_running?
    @dom.active?
  end

  def execute
    # TODO: could allow to run commands on the tails VM
    # Might deserve a whole helper though.
  end

  def start
    @dom.destroy if @dom.active?
    @dom.create
  end

  def stop
    @dom.destroy if @dom.active?
  end
end
