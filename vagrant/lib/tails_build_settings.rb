# -*- coding: utf-8 -*-
# -*- mode: ruby -*-
# vi: set ft=ruby :

# Hostname of the virtual machine (must be in /etc/hosts)
VIRTUAL_MACHINE_HOSTNAME = 'tails-builder-20150609.vagrantup.com'

# Approximate amount of extra space needed for builds
BUILD_SPACE_REQUIREMENT = 7*1024 + 128

# Virtual machine memory size for on-disk builds
VM_MEMORY_FOR_DISK_BUILDS = 512

# Virtual machine memory size for in-memory builds
VM_MEMORY_FOR_RAM_BUILDS = VM_MEMORY_FOR_DISK_BUILDS + BUILD_SPACE_REQUIREMENT

# Checksum for BOX
BOX_CHECKSUM = '704dbb844464c1998c0873220e0c221b910a28a7402ced2395c781c936af9a2f'
