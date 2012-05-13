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

require 'rubygems'
require 'vagrant'
require 'uri'

# Path to the directory which holds our Vagrantfile
VAGRANT_PATH = File.expand_path('../vagrant', __FILE__)

task :validate_http_proxy do
  if ENV['http_proxy']
    proxy_host = URI.parse(ENV['http_proxy']).host

    if ['localhost', '[::1]'].include?(proxy_host) || proxy_host.start_with?('127.0.0.')
      abort 'Using an HTTP proxy listening on the loopback is doomed to fail. Aborting.'
    end

    $stderr.puts "Using HTTP proxy: #{ENV['http_proxy']}"
  else
    $stderr.puts "No HTTP proxy set."
  end
end

namespace :vm do
  desc 'Start the build virtual machine'
  task :up do
    env = Vagrant::Environment.new(:cwd => VAGRANT_PATH, :ui_class => Vagrant::UI::Basic)
    case env.primary_vm.state
    when :not_created
      $stderr.puts <<-END_OF_MESSAGE.gsub(/^      /, '')

        This is the first time that the Tails builder virtual machine is
        started. The virtual machine template is about 300 MB to download,
        so the process might take some time.

        Please remember to shut the virtual machine down once your work on
        Tails in done:

            $ rake vm:halt

      END_OF_MESSAGE
    when :poweroff
      $stderr.puts <<-END_OF_MESSAGE.gsub(/^      /, '')

        Starting Tails builder virtual machine. This might take a short while.
        Please remember to shut it down once your work on Tails in done:

            $ rake vm:halt

      END_OF_MESSAGE
    end
    result = env.cli('up')
    abort "'vagrant up' failed" unless result
  end

  desc 'Stop the build virtual machine'
  task :halt do
    env = Vagrant::Environment.new(:cwd => VAGRANT_PATH, :ui_class => Vagrant::UI::Basic)
    result = env.cli('halt')
    abort "'vagrant halt' failed" unless result
  end

  desc 'Re-run virtual machine setup'
  task :provision do
    env = Vagrant::Environment.new(:cwd => VAGRANT_PATH, :ui_class => Vagrant::UI::Basic)
    result = env.cli('provision')
    abort "'vagrant provision' failed" unless result
  end

  desc 'Destroy build virtual machine (clean up all files)'
  task :destroy do
    env = Vagrant::Environment.new(:cwd => VAGRANT_PATH, :ui_class => Vagrant::UI::Basic)
    result = env.cli('destroy', '--force')
    abort "'vagrant destroy' failed" unless result
  end
end

namespace :basebox do
  task :create_preseed_cfg => 'validate_http_proxy' do
    require 'erb'

    preseed_cfg_path = File.expand_path('../vagrant/definitions/squeeze/preseed.cfg', __FILE__)
    template = ERB.new(File.read("#{preseed_cfg_path}.erb"))
    File.open(preseed_cfg_path, 'w') do |f|
      f.write template.result
    end
  end

  desc 'Create virtual machine template (a.k.a. basebox)'
  task :create_basebox => [:create_preseed_cfg] do
    # veewee is pretty stupid regarding path handling
    Dir.chdir(VAGRANT_PATH) do
      require 'veewee'

      # Veewee assumes a separate process for each task. So we mimic that.

      env = Vagrant::Environment.new(:ui_class => Vagrant::UI::Basic)

      Process.fork do
        env.cli('basebox', 'build', 'squeeze')
      end
      Process.wait
      abort "Building the basebox failed (exit code: #{$?.exitstatus})." if $?.exitstatus != 0

      Process.fork do
        env.cli('basebox', 'validate', 'squeeze')
      end
      Process.wait
      abort "Validating the basebox failed (exit code: #{$?.exitstatus})." if $?.exitstatus != 0

      Process.fork do
        env.cli('basebox', 'export', 'squeeze')
      end
      Process.wait
      abort "Exporting the basebox failed (exit code: #{$?.exitstatus})." if $?.exitstatus != 0
    end
  end
end
