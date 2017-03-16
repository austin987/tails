# -*- coding: utf-8 -*-
# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Tails: The Amnesic Incognito Live System
# Copyright © 2012 Tails developers <tails@boum.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'libvirt'
require 'open3'
require 'rbconfig'
require 'uri'

require_relative 'vagrant/lib/tails_build_settings'

# Path to the directory which holds our Vagrantfile
VAGRANT_PATH = File.expand_path('../vagrant', __FILE__)

# Branches that are considered 'stable' (used to select SquashFS compression)
STABLE_BRANCH_NAMES = ['stable', 'testing']

EXPORTED_VARIABLES = [
  'MKSQUASHFS_OPTIONS',
  'TAILS_MERGE_BASE_BRANCH',
  'TAILS_OFFLINE_MODE',
  'TAILS_PROXY',
  'TAILS_PROXY_TYPE',
  'TAILS_RAM_BUILD',
  'GIT_COMMIT',
  'GIT_REF',
  'BASE_BRANCH_GIT_COMMIT',
]
ENV['EXPORTED_VARIABLES'] = EXPORTED_VARIABLES.join(' ')

EXTERNAL_HTTP_PROXY = ENV['http_proxy']

# In-VM proxy URL
INTERNAL_HTTP_PROXY = "http://#{VIRTUAL_MACHINE_HOSTNAME}:3142"

ENV['ARTIFACTS'] ||= '.'

class VagrantCommandError < StandardError
end

def git_helper(*args)
  question = args.first.end_with?('?')
  args.first.sub!(/\?$/, '')
  stdout = `sh auto/scripts/utils.sh git_#{args.join(' ')}`.chomp
  if question
    return $?.success?
  else
    return stdout
  end
end

# Runs the vagrant command, letting stdout/stderr through. Throws an
# exception unless the vagrant command succeeds.
def run_vagrant(*args)
  Process.wait Kernel.spawn('vagrant', *args, :chdir => './vagrant')
  if $?.exitstatus != 0
    raise(VagrantCommandError, "'vagrant #{args}' command failed: " +
                               "#{$?.exitstatus}")
  end
end

# Runs the vagrant command, not letting stdout/stderr through, and
# returns [stdout, stderr, Preocess:Status].
def capture_vagrant(*args)
  stdout, stderr, proc_status =
    Open3.capture3('vagrant', *args, :chdir => './vagrant')
  if proc_status.exitstatus != 0
    raise(VagrantCommandError, "'vagrant #{args}' command failed: " +
                               "#{proc_status.exitstatus}")
  end
  return stdout, stderr
end

def vagrant_ssh_config(key)
  # Cache results
  if $vagrant_ssh_config.nil?
    $vagrant_ssh_config = capture_vagrant('ssh-config').first.split("\n") \
                           .map { |line| line.strip.split(/\s+/, 2) } .to_h
    # The path in the ssh-config output is quoted, which is not what
    # is expected outside of a shell, so let's get rid of the quotes.
    $vagrant_ssh_config['IdentityFile'].gsub!(/^"|"$/, '')
  end
  $vagrant_ssh_config[key]
end

def current_vm_cpus
  capture_vagrant('ssh', '-c', 'grep -c "^processor\s*:" /proc/cpuinfo').first.chomp.to_i
end

def vm_state
  out, _ = capture_vagrant('status')
  status_line = out.split("\n")[2]
  if    status_line['not created']
    return :not_created
  elsif status_line['shutoff']
    return :poweroff
  elsif status_line['running']
    return :running
  else
    raise "could not determine VM state"
  end
end

def enough_free_host_memory_for_ram_build?
  return false unless RbConfig::CONFIG['host_os'] =~ /linux/i

  begin
    usable_free_mem = `free`.split[16].to_i
    usable_free_mem > VM_MEMORY_FOR_RAM_BUILDS * 1024
  rescue
    false
  end
end

def free_vm_memory
  capture_vagrant('ssh', '-c', 'free').first.chomp.split[16].to_i
end

def enough_free_vm_memory_for_ram_build?
  free_vm_memory > BUILD_SPACE_REQUIREMENT * 1024
end

def enough_free_memory_for_ram_build?
  if vm_state == :running
    enough_free_vm_memory_for_ram_build?
  else
    enough_free_host_memory_for_ram_build?
  end
end

def is_release?
  git_helper('in_detached_head?') && git_helper('on_a_tag?')
end

def system_cpus
  return nil unless RbConfig::CONFIG['host_os'] =~ /linux/i

  begin
    File.read('/proc/cpuinfo').scan(/^processor\s+:/).count
  rescue
    nil
  end
end

task :parse_build_options do
  options = []

  # Default to in-memory builds if there is enough RAM available
  options << 'ram' if enough_free_memory_for_ram_build?

  # Default to build using the in-VM proxy
  options << 'vmproxy'

  # Default to fast compression on development branches
  options << 'gzipcomp' unless is_release?

  # Default to the number of system CPUs when we can figure it out
  cpus = system_cpus
  options << "cpus=#{cpus}" if cpus

  options += ENV['TAILS_BUILD_OPTIONS'].split if ENV['TAILS_BUILD_OPTIONS']

  # Make sure release builds are clean
  options << 'cleanall' if is_release?

  options.uniq.each do |opt|
    case opt
    # Memory build settings
    when 'ram'
      ENV['TAILS_RAM_BUILD'] = '1'
    when 'noram'
      ENV['TAILS_RAM_BUILD'] = nil
    # Bootstrap cache settings
    # HTTP proxy settings
    when 'extproxy'
      abort "No HTTP proxy set, but one is required by TAILS_BUILD_OPTIONS. Aborting." unless EXTERNAL_HTTP_PROXY
      ENV['TAILS_PROXY'] = EXTERNAL_HTTP_PROXY
      ENV['TAILS_PROXY_TYPE'] = 'extproxy'
    when 'vmproxy'
      ENV['TAILS_PROXY'] = INTERNAL_HTTP_PROXY
      ENV['TAILS_PROXY_TYPE'] = 'vmproxy'
    when 'noproxy'
      ENV['TAILS_PROXY'] = nil
      ENV['TAILS_PROXY_TYPE'] = 'noproxy'
    when 'offline'
      ENV['TAILS_OFFLINE_MODE'] = '1'
    # SquashFS compression settings
    when 'gzipcomp'
      ENV['MKSQUASHFS_OPTIONS'] = '-comp gzip'
    when 'defaultcomp'
      ENV['MKSQUASHFS_OPTIONS'] = nil
    # Virtual CPUs settings
    when /cpus=(\d+)/
      ENV['TAILS_BUILD_CPUS'] = $1
    # Git settings
    when 'ignorechanges'
      ENV['TAILS_BUILD_IGNORE_CHANGES'] = '1'
    # Developer convenience features
    when 'keeprunning'
      $keep_running = true
      $force_cleanup = false
    when 'forcecleanup'
      $force_cleanup = true
      $keep_running = false
    when 'rescue'
      $keep_running = true
      ENV['TAILS_BUILD_FAILURE_RESCUE'] = '1'
    # Jenkins
    when 'mergebasebranch'
      ENV['MERGE_BASE_BRANCH'] = '1'
    else
      raise "Unknown Tails build option '#{opt}'"
    end
  end

  if ENV['TAILS_OFFLINE_MODE'] == '1'
    if ENV['TAILS_PROXY'].nil?
      abort "You must use a caching proxy when building offline"
    end
  end
end

task :ensure_clean_repository do
  git_status = `git status --porcelain`
  unless git_status.empty?
    if ENV['TAILS_BUILD_IGNORE_CHANGES']
      $stderr.puts <<-END_OF_MESSAGE.gsub(/^        /, '')

        You have uncommitted changes in the Git repository. They will
        be ignored for the upcoming build:
        #{git_status}

      END_OF_MESSAGE
    else
      $stderr.puts <<-END_OF_MESSAGE.gsub(/^        /, '')

        You have uncommitted changes in the Git repository. Due to limitations
        of the build system, you need to commit them before building Tails:
        #{git_status}

        If you don't care about those changes and want to build Tails nonetheless,
        please add `ignorechanges` to the TAILS_BUILD_OPTIONS environment
        variable.

      END_OF_MESSAGE
      abort 'Uncommitted changes. Aborting.'
    end
  end
end

def list_artifacts
  user = vagrant_ssh_config('User')
  stdout = capture_vagrant('ssh', '-c', "find '/home/#{user}/amnesia/' -maxdepth 1 " +
                                        "-name 'tails-*.iso*'").first
  stdout.split("\n")
rescue VagrantCommandError
  return Array.new
end

def remove_artifacts
  list_artifacts.each do |artifact|
    run_vagrant('ssh', '-c', "sudo rm -f '#{artifact}'")
  end
end

desc "Make sure the vagrant user's home directory has no undesired artifacts"
task :ensure_clean_home_directory => ['vm:up'] do
  remove_artifacts
end

task :validate_http_proxy do
  if ENV['TAILS_PROXY']
    proxy_host = URI.parse(ENV['TAILS_PROXY']).host

    if proxy_host.nil?
      ENV['TAILS_PROXY'] = nil
      $stderr.puts "Ignoring invalid HTTP proxy."
      return
    end

    if ['localhost', '[::1]'].include?(proxy_host) || proxy_host.start_with?('127.0.0.')
      abort 'Using an HTTP proxy listening on the loopback is doomed to fail. Aborting.'
    end

    $stderr.puts "Using HTTP proxy: #{ENV['TAILS_PROXY']}"
  else
    $stderr.puts "No HTTP proxy set."
  end
end

task :validate_git_state do
  if git_helper('in_detached_head?') && not(git_helper('on_a_tag?'))
    raise 'We are in detached head but the current commit is not tagged'
  end
end

task :setup_environment => ['validate_git_state'] do
  ENV['GIT_COMMIT'] = git_helper('current_commit')
  ENV['BASE_BRANCH_GIT_COMMIT'] = git_helper('base_branch_head')
  ENV['GIT_REF'] = git_helper('current_head_name')
  ['GIT_COMMIT', 'GIT_REF', 'BASE_BRANCH_GIT_COMMIT'].each do |var|
    if ENV[var].empty?
      raise "Variable '#{var}' is empty, which should not be possible" +
            "(validate_git_state must be buggy)"
    end
  end
end

task :maybe_clean_up_builder_vms do
  clean_up_builder_vms if $force_cleanup
end

desc 'Build Tails'
task :build => ['parse_build_options', 'ensure_clean_repository', 'maybe_clean_up_builder_vms', 'validate_git_state', 'setup_environment', 'validate_http_proxy', 'vm:up', 'ensure_clean_home_directory'] do

  begin
    if ENV['TAILS_RAM_BUILD'] && not(enough_free_memory_for_ram_build?)
      $stderr.puts <<-END_OF_MESSAGE.gsub(/^        /, '')

        The virtual machine is not currently set with enough memory to
        perform an in-memory build. Either remove the `ram` option from
        the TAILS_BUILD_OPTIONS environment variable, or shut the
        virtual machine down using `rake vm:halt` before trying again.

      END_OF_MESSAGE
      abort 'Not enough memory for the virtual machine to run an in-memory build. Aborting.'
    end

    if ENV['TAILS_BUILD_CPUS'] && current_vm_cpus != ENV['TAILS_BUILD_CPUS'].to_i
      $stderr.puts <<-END_OF_MESSAGE.gsub(/^        /, '')

        The virtual machine is currently running with #{current_vm_cpus}
        virtual CPU(s). In order to change that number, you need to
        stop the VM first, using `rake vm:halt`. Otherwise, please
        adjust the `cpus` options accordingly.

      END_OF_MESSAGE
      abort 'The virtual machine needs to be reloaded to change the number of CPUs. Aborting.'
    end

    exported_env = EXPORTED_VARIABLES.select { |k| ENV[k] }.
                   collect { |k| "#{k}='#{ENV[k]}'" }.join(' ')
    run_vagrant('ssh', '-c', "#{exported_env} build-tails")

    artifacts = list_artifacts
    raise 'No build artifacts was found!' if artifacts.empty?
    user     = vagrant_ssh_config('User')
    hostname = vagrant_ssh_config('HostName')
    key_file = vagrant_ssh_config('IdentityFile')
    $stderr.puts "Retrieving artifacts from Vagrant build box."
    artifacts.each do |artifact|
      run_vagrant('ssh', '-c', "sudo chown #{user} '#{artifact}'")
      Process.wait(
        Kernel.spawn(
          'scp',
          '-i', key_file,
          # We need this since the user will not necessarily have a
          # known_hosts entry. It is safe since an attacker must
          # compromise libvirt's network config or the user running the
          # command to modify the #{hostname} below.
          '-o', 'StrictHostKeyChecking=no',
          '-o', 'UserKnownHostsFile=/dev/null',
          "#{user}@#{hostname}:#{artifact}", "#{ENV['ARTIFACTS']}"
        )
      )
      raise "Failed to fetch artifact '#{artifact}'" unless $?.success?
    end
    clean_up_builder_vms unless $keep_running
  ensure
    clean_up_builder_vms if $force_cleanup
  end
end

def box_name(vagrantfile_contents = open('vagrant/Vagrantfile') { |f| f.read })
  /^\s*config.vm.box = '([^']+)'/.match(vagrantfile_contents)[1]
end

def has_box?(name = box_name)
  !!capture_vagrant('box', 'list').grep(/^#{name}\s+\(libvirt,/)
end

def domain_name(name = box_name)
  # Vagrant drops some characters when creating the domain and volumes
  # based on the box name.
  "#{name.delete('+')}_default"
end

def clean_up_builder_vms
  $virt = Libvirt::open("qemu:///system")

  clean_up_domain = Proc.new do |domain|
    next if domain.nil?
    domain.destroy if domain.active?
    domain.undefine
    begin
      $virt
        .lookup_storage_pool_by_name('default')
        .lookup_volume_by_name("#{domain.name}.img")
        .delete
    rescue Libvirt::RetrieveError
      # Expected if the pool or disk does not exist
    end
  end

  # Let's ensure that the VM we are about to create is cleaned up ...
  previous_domain = $virt.list_all_domains.find { |d| d.name == domain_name }
  clean_up_domain.call(previous_domain)

  # ... and the same for any residual VM based on another box (=>
  # another domain name) that Vagrant still keeps track of.
  old_domain =
    begin
      old_domain_uuid =
        open('vagrant/.vagrant/machines/default/libvirt/id', 'r') { |f| f.read }
        .strip
      $virt.lookup_domain_by_uuid(old_domain_uuid)
    rescue Errno::ENOENT, Libvirt::RetrieveError
      # Expected if we don't have vagrant/.vagrant, or if the VM was
      # undefined for other reasons (e.g. manually).
      nil
    end
  clean_up_domain.call(old_domain)

  # We could use `vagrant destroy` here but due to vagrant-libvirt's
  # upstream issue #746 we then risk losing the apt-cacher-ng data.
  # Since we essentially implement `vagrant destroy` without this bug
  # above, but in a way so it works even if `vagrant/.vagrant` does
  # not exist, let's just do what is sagest, i.e. avoiding `vagrant
  # destroy`. For details, see the upstream issue:
  #   https://github.com/vagrant-libvirt/vagrant-libvirt/issues/746
  FileUtils.rm_rf('vagrant/.vagrant')
ensure
  $virt.close
end

namespace :vm do
  desc 'Start the build virtual machine'
  task :up => ['parse_build_options', 'validate_http_proxy', 'setup_environment'] do
    case vm_state
    when :not_created
      clean_up_builder_vms
      unless has_box?
        $stderr.puts <<-END_OF_MESSAGE.gsub(/^          /, '')

          This is the first time that the Tails builder virtual machine is
          started. The virtual machine template is about 250 MB to download,
          so the process might take some time.

          Please remember to shut the virtual machine down once your work on
          Tails is done:

              $ rake vm:halt

        END_OF_MESSAGE
      end
    end
    begin
      run_vagrant('up')
    rescue VagrantCommandError => e
      clean_up_builder_vms if $force_cleanup
      raise e
    end
  end

  desc 'SSH into the builder VM'
  task :ssh do
    run_vagrant('ssh')
  end

  desc 'Stop the build virtual machine'
  task :halt do
    run_vagrant('halt')
  end

  desc 'Re-run virtual machine setup'
  task :provision => ['parse_build_options', 'validate_http_proxy', 'setup_environment'] do
    run_vagrant('provision')
  end

  desc "Destroy build virtual machine (clean up all files except the vmproxy's apt-cacher-ng data)"
  task :destroy do
    clean_up_builder_vms
  end
end

namespace :basebox do

  desc 'Generate a new base box'
  task :create do
    debian_snapshot_serial =
      `auto/scripts/apt-snapshots-serials cat debian`.chomp.split.last
    raise 'invalid serial' unless /^\d{10}$/.match(debian_snapshot_serial)
    box_dir = VAGRANT_PATH + '/definitions/tails-builder'
    Dir.chdir(box_dir) do
      `./generate-tails-builder-box.sh #{debian_snapshot_serial}`
      raise 'Base box generation failed!' unless $?.success?
    end
    box = Dir.glob("#{box_dir}/*.box").sort_by {|f| File.mtime(f) } .last
    $stderr.puts <<-END_OF_MESSAGE.gsub(/^      /, '')

      You have successfully generated a new Vagrant base box:

          #{box}

      To install the new base box, please run:

          $ vagrant box add #{box}

      To actually make Tails build using this base box, the `config.vm.box` key
      in `vagrant/Vagrantfile` has to be updated. Please check the documentation
      for details.

    END_OF_MESSAGE
  end

end
