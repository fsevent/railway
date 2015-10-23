# railway.rb --- library file to be required by users
#
# Copyright (C) 2014  National Institute of Advanced Industrial Science and Technology (AIST)
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

require 'fsevent'

require 'railway/valueid2'

module Railway
end

require 'railway/facilities'
require 'railway/dumper'
require 'railway/fixedsignal'
require 'railway/point'
require 'railway/cmp'
require 'railway/majority'
require 'railway/circuit'
require 'railway/interlocking'
require 'railway/latch'
require 'railway/selector'
require 'railway/panel'
require 'railway/train'

