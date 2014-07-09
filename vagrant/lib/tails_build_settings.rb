# -*- coding: utf-8 -*-
# -*- mode: ruby -*-
# vi: set ft=ruby :

# Hostname of the virtual machine (must be in /etc/hosts)
VIRTUAL_MACHINE_HOSTNAME = 'tails-builder-20140709.vagrantup.com'

# Approximate amount of extra space needed for builds
BUILD_SPACE_REQUIREMENT = 6656

# Virtual machine memory size for on-disk builds
VM_MEMORY_FOR_DISK_BUILDS = 512

# Virtual machine memory size for in-memory builds
VM_MEMORY_FOR_RAM_BUILDS = VM_MEMORY_FOR_DISK_BUILDS + BUILD_SPACE_REQUIREMENT

# Checksum for BOX
BOX_CHECKSUM = '9a51f600f015d107a249f2530c5681d0f475525f52698404d5ce2fe11a0e07e3'
