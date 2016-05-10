# partstate.rb -- state of a part
#
# Copyright (C) 2016  National Institute of Advanced Industrial Science and Technology (AIST)
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

class Railway::PartState

  def initialize(part_name, state)
    @part_name = part_name
    @state = state
  end
  attr_reader :part_name, :state

  def inspect
  "\#<#{self.class}: #{@part_name} #{@state}>"
  end

  def interlocking_status
    [[@part_name, @state]]
  end

  def part_states
    [[@part_name, @part_name, @state]]
  end

  def lockable?(watched_status)
    watched_status[@part_name][@part_name] == @state
  end

  def interfere?(res)
    @part_name == res.part_name && @state != res.state
  end

  def requestable?
    true
  end
end

