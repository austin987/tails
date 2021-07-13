# -*- mode: ruby -*-
# vi: set ft=ruby :

# Approximate amount of RAM needed to run the builder's base system
# and perform a build
VM_MEMORY_BASE = 1.5 * 1024

# Approximate amount of extra space needed for builds
BUILD_SPACE_REQUIREMENT = 12 * 1024

# Virtual machine memory size for on-disk builds
VM_MEMORY_FOR_DISK_BUILDS = VM_MEMORY_BASE

# Virtual machine memory size for in-memory builds
VM_MEMORY_FOR_RAM_BUILDS = VM_MEMORY_BASE + BUILD_SPACE_REQUIREMENT

# The builder VM's platform
ARCHITECTURE = 'amd64'.freeze
DISTRIBUTION = 'buster'.freeze

# The name of the Vagrant box
def box_name
  git_root = `git rev-parse --show-toplevel`.chomp
  shortid, date = `git log -1 --date="format:%Y%m%d" --no-show-signature --pretty="%h %ad" -- \
                   #{git_root}/vagrant/`.chomp.split
  "tails-builder-#{ARCHITECTURE}-#{DISTRIBUTION}-#{date}-#{shortid}"
end
