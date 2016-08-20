# -*- coding: utf-8 -*-
# -*- mode: ruby -*-
# vi: set ft=ruby :

# Hostname of the virtual machine (must be in /etc/hosts)
VIRTUAL_MACHINE_HOSTNAME = 'vagrant-jessie'

# Approximate amount of extra space needed for builds
BUILD_SPACE_REQUIREMENT = 8*1024

# Virtual machine memory size for on-disk builds
VM_MEMORY_FOR_DISK_BUILDS = 512

# Virtual machine memory size for in-memory builds
VM_MEMORY_FOR_RAM_BUILDS = VM_MEMORY_FOR_DISK_BUILDS + BUILD_SPACE_REQUIREMENT
