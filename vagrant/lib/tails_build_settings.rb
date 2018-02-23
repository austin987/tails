# -*- coding: utf-8 -*-
# -*- mode: ruby -*-
# vi: set ft=ruby :

# Hostname of the virtual machine (must be in /etc/hosts)
VIRTUAL_MACHINE_HOSTNAME = 'vagrant-stretch'

# Approximate amount of RAM needed to run the builder's base system
# and perform a build
VM_MEMORY_BASE = 1024

# Approximate amount of extra space needed for builds
BUILD_SPACE_REQUIREMENT = 12*1024

# Virtual machine memory size for on-disk builds
VM_MEMORY_FOR_DISK_BUILDS = VM_MEMORY_BASE

# Virtual machine memory size for in-memory builds
VM_MEMORY_FOR_RAM_BUILDS = VM_MEMORY_BASE + BUILD_SPACE_REQUIREMENT

# The builder VM's platform
ARCHITECTURE = "amd64"
DISTRIBUTION = "stretch"

# The name of the Vagrant box
def box_name
  git_root = `git rev-parse --show-toplevel`.chomp
  shortid, date = `git log -1 --date="format:%Y%m%d" --pretty="%h %ad" -- \
                   #{git_root}/vagrant/definitions/tails-builder/`.chomp.split
  return "tails-builder-#{ARCHITECTURE}-#{DISTRIBUTION}-#{date}-#{shortid}"
end
