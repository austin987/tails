# -*- coding: utf-8 -*-
# -*- mode: ruby -*-
# vi: set ft=ruby :

# Hostname of the virtual machine (must be in /etc/hosts)
VIRTUAL_MACHINE_HOSTNAME = 'squeeze.vagrantup.com'

# Approximate amount of extra space needed for builds
BUILD_SPACE_REQUIREMENT = 6656

# Virtual machine memory size for on-disk builds
VM_MEMORY_FOR_DISK_BUILDS = 1024 # 1 GB

# Virtual machine memory size for in-memory builds
VM_MEMORY_FOR_RAM_BUILDS = VM_MEMORY_FOR_DISK_BUILDS + BUILD_SPACE_REQUIREMENT

# Checksum for BOX
BOX_CHECKSUM = '8951d257fc4751437812477df81d55670ebcc0b57c525c248cf2284a89540ca3'
