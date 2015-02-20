# Helper class for manipulating VM storage *volumes*, i.e. it deals
# only with creation of images and keeps a name => volume path lookup
# table (plugging drives or getting info of plugged devices is done in
# the VM class). We'd like better coupling, but given the ridiculous
# disconnect between Libvirt::StoragePool and Libvirt::Domain (hint:
# they have nothing with each other to do whatsoever) it's what makes
# sense.

require 'libvirt'
require 'guestfs'
require 'rexml/document'
require 'etc'

class VMStorage

  @@virt = nil

  def initialize(virt, xml_path)
    @@virt ||= virt
    @xml_path = xml_path
    pool_xml = REXML::Document.new(File.read("#{@xml_path}/storage_pool.xml"))
    pool_name = pool_xml.elements['pool/name'].text
    begin
      @pool = @@virt.lookup_storage_pool_by_name(pool_name)
    rescue Libvirt::RetrieveError
      # There's no pool with that name, so we don't have to clear it
    else
      VMStorage.clear_storage_pool(@pool)
    end
    @pool_path = "#{$tmp_dir}/#{pool_name}"
    pool_xml.elements['pool/target/path'].text = @pool_path
    @pool = @@virt.define_storage_pool_xml(pool_xml.to_s)
    @pool.build
    @pool.create
    @pool.refresh
  end

  def VMStorage.clear_storage_pool_volumes(pool)
    was_not_active = !pool.active?
    if was_not_active
      pool.create
    end
    pool.list_volumes.each do |vol_name|
      vol = pool.lookup_volume_by_name(vol_name)
      vol.delete
    end
    if was_not_active
      pool.destroy
    end
  rescue
    # Some of the above operations can fail if the pool's path was
    # deleted by external means; let's ignore that.
  end

  def VMStorage.clear_storage_pool(pool)
    VMStorage.clear_storage_pool_volumes(pool)
    pool.destroy if pool.active?
    pool.undefine
  end

  def clear_pool
    VMStorage.clear_storage_pool(@pool)
  end

  def clear_volumes
    VMStorage.clear_storage_pool_volumes(@pool)
  end

  def create_new_disk(name, options = {})
    options[:size] ||= 2
    options[:unit] ||= "GiB"
    options[:type] ||= "qcow2"
    # Require 'slightly' more space to be available to give a bit more leeway
    # with rounding, temp file creation, etc.
    reserved = 500
    needed = convert_to_MiB(options[:size].to_i, options[:unit])
    avail = convert_to_MiB(get_free_space('host', @pool_path), "KiB")
    assert(avail - reserved >= needed,
           "Error creating disk \"#{name}\" in \"#{@pool_path}\". " \
           "Need #{needed} MiB but only #{avail} MiB is available of, " \
           "which #{reserved} MiB is reserved for other temporary files.")
    begin
      old_vol = @pool.lookup_volume_by_name(name)
    rescue Libvirt::RetrieveError
      # noop
    else
      old_vol.delete
    end
    uid = Etc::getpwnam("libvirt-qemu").uid
    gid = Etc::getgrnam("libvirt-qemu").gid
    vol_xml = REXML::Document.new(File.read("#{@xml_path}/volume.xml"))
    vol_xml.elements['volume/name'].text = name
    size_b = convert_to_bytes(options[:size].to_f, options[:unit])
    vol_xml.elements['volume/capacity'].text = size_b.to_s
    vol_xml.elements['volume/target/format'].attributes["type"] = options[:type]
    vol_xml.elements['volume/target/path'].text = "#{@pool_path}/#{name}"
    vol_xml.elements['volume/target/permissions/owner'].text = uid.to_s
    vol_xml.elements['volume/target/permissions/group'].text = gid.to_s
    vol = @pool.create_volume_xml(vol_xml.to_s)
    @pool.refresh
  end

  def clone_to_new_disk(from, to)
    begin
      old_to_vol = @pool.lookup_volume_by_name(to)
    rescue Libvirt::RetrieveError
      # noop
    else
      old_to_vol.delete
    end
    from_vol = @pool.lookup_volume_by_name(from)
    xml = REXML::Document.new(from_vol.xml_desc)
    pool_path = REXML::Document.new(@pool.xml_desc).elements['pool/target/path'].text
    xml.elements['volume/name'].text = to
    xml.elements['volume/target/path'].text = "#{pool_path}/#{to}"
    @pool.create_volume_xml_from(xml.to_s, from_vol)
  end

  def disk_format(name)
    vol = @pool.lookup_volume_by_name(name)
    vol_xml = REXML::Document.new(vol.xml_desc)
    return vol_xml.elements['volume/target/format'].attributes["type"]
  end

  def disk_path(name)
    @pool.lookup_volume_by_name(name).path
  end

  def disk_mklabel(name, parttype)
    disk = {
      :path => disk_path(name),
      :opts => {
        :format => disk_format(name)
      }
    }
    guestfs_disk_helper(disk) do |g, disk_handle|
      g.part_init(disk_handle, parttype)
    end
  end

  def disk_mkpartfs(name, parttype, fstype, opts = {})
    opts[:label] ||= nil
    opts[:luks_password] ||= nil
    disk = {
      :path => disk_path(name),
      :opts => {
        :format => disk_format(name)
      }
    }
    guestfs_disk_helper(disk) do |g, disk_handle|
      g.part_disk(disk_handle, parttype)
      g.part_set_name(disk_handle, 1, opts[:label]) if opts[:label]
      primary_partition = g.list_partitions()[0]
      if opts[:luks_password]
        g.luks_format(primary_partition, opts[:luks_password], 0)
        luks_mapping = File.basename(primary_partition) + "_unlocked"
        g.luks_open(primary_partition, opts[:luks_password], luks_mapping)
        luks_dev = "/dev/mapper/#{luks_mapping}"
        g.mkfs(fstype, luks_dev)
        g.luks_close(luks_dev)
      else
        g.mkfs(fstype, primary_partition)
      end
    end
  end

  def disk_mkswap(name, parttype)
    disk = {
      :path => disk_path(name),
      :opts => {
        :format => disk_format(name)
      }
    }
    guestfs_disk_helper(disk) do |g, disk_handle|
      g.part_disk(disk_handle, parttype)
      primary_partition = g.list_partitions()[0]
      g.mkswap(primary_partition)
    end
  end

  def guestfs_disk_helper(*disks)
    assert(block_given?)
    g = Guestfs::Guestfs.new()
    g.set_trace(1) if $debug
    g.set_autosync(1)
    disks.each do |disk|
      g.add_drive_opts(disk[:path], disk[:opts])
    end
    g.launch()
    yield(g, *g.list_devices())
  ensure
    g.close
  end

end
