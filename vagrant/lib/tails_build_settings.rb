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
BOX_CHECKSUM = 'efb339f06192d5db16585abc946e50cc73cb13aad5afd39357c6a8e33aebb814'
