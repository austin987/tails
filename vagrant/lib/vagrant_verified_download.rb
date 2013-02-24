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

require 'digest'

# The following will monkeypatch Vagrant (successfuly tested against Vagrant
# 1.0.2) in order to verify the checksum of a downloaded box.
module Vagrant
  class Config::VMConfig
    attr_accessor :box_checksum
  end

  class Action::Box::Download
    alias :unverified_download :download
    def download
      unverified_download

      checksum = Digest::SHA256.new.file(@temp_path).hexdigest
      if checksum != @env['global_config'].vm.box_checksum
        raise Errors::BoxVerificationFailed.new
      end
    end
  end
end
