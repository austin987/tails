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
require 'vagrant/util/downloader'

def check(path)
  checksum = Digest::SHA256.new.file(path).hexdigest
  if checksum != BOX_CHECKSUM
    raise Errors::BoxVerificationFailed.new
  end
end

module Vagrant
  if vagrant_old
    class Action::Box::Download
      alias :unverified_download :download
      def download
        unverified_download
        check(@temp_path)
      end
    end
  else
    class Util::Downloader
      alias :unverified_download! :download!
      def download!
        unverified_download!
        check(@destination)
      end
    end
  end
end
