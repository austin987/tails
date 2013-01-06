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

# Hostname of the virtual machine (must be in /etc/hosts)
VIRTUAL_MACHINE_HOSTNAME = 'squeeze.vagrantup.com'

# Virtual machine memory size for in-memory builds
VM_MEMORY_FOR_RAM_BUILDS = 6 * 1024 + 512 # 6.5 GB

# Virtual machine memory size for on-disk builds
VM_MEMORY_FOR_DISK_BUILDS = 1024 # 1 GB
