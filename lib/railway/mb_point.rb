# mb_point.rb --- moving block point device
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

class Railway::MBPoint < FSEvent::AbstractDevice
  def initialize(device_name, initial_position, interlocking_status)
    super(device_name)
    @interlocking_status = interlocking_status # device/status

    # normal position: "normal"
    # reverse position: "reverse"
    # moving to normal position: "-normal"
    # moving to reverse position: "-reverse"

    # initial_position should be 1 or 2

    @current_position = initial_position
    @time_to_finish_moving = nil
  end

  def registered
    define_status(@name, @current_position)
    add_watch(@interlocking_status[0], @interlocking_status[1])
  end

  StateTransitionTime = 5

  def run(watched_status, changed_status)
    if @time_to_finish_moving
      if @framework.current_time < @time_to_finish_moving
        return
      else
        modify_status(@name, @current_position)
        @time_to_finish_moving = nil
      end
    end
    interlocking_name, status_name = @interlocking_status
    if watched_status[interlocking_name].has_key?(status_name) &&
       watched_status[interlocking_name][status_name]
      requested_position = watched_status[interlocking_name][status_name]
      if requested_position != @current_position
        @current_position = requested_position
        modify_status(@name, "-#{requested_position}")
        @time_to_finish_moving = @framework.current_time + StateTransitionTime
        @schedule.merge_schedule [@time_to_finish_moving]
      end
    end
    set_elapsed_time(0)
  end
end
