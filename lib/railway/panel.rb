# panel.rb --- panel device
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

class Railway::Panel < FSEvent::AbstractDevice
  def initialize(device_name, facilities, plan)
    super device_name
    @facilities = facilities
    @plan = plan.sort
    @next_action = nil
  end

  def registered
    @facilities.each_route_name {|route_name|
      define_status(route_name, false)
    }
    set_elapsed_time(0)
    set_next_schedule
  end

  def run(watched_status, changed_status)
    while !@plan.empty? && @plan.first[0] <= @framework.current_time
      _t, status_name, value = @plan.shift
      modify_status(status_name, value)
    end
    set_next_schedule
  end

  def set_next_schedule
    unless @plan.empty?
      t, _status_name, _value = @plan.first
      @schedule.merge_schedule [t]
    end
  end
end


