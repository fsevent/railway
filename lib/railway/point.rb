# point.rb --- point device
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

class Railway::Point < FSEvent::AbstractDevice
  def initialize(device_name, initial_position, interlocking_name, status_name)
    super(device_name)
    @interlocking_name = interlocking_name
    @status_name = status_name

    # normal position: 1
    # reverse position: 2
    # moving to normal position: -1
    # moving to reverse position: -2

    # initial_position should be 1 or 2

    @current_position = [initial_position, nil, nil]
    @time_to_finish_moving = nil
  end

  def registered
    define_status(@name, @current_position)
    add_watch(@interlocking_name, @status_name)
  end

  def run(watched_status, changed_status)
    if @time_to_finish_moving
      if @framework.current_time < @time_to_finish_moving
        return
      else
        modify_status(@name, @current_position)
        @time_to_finish_moving = nil
      end
    end
    if watched_status[@interlocking_name].has_key?(@status_name) &&
       watched_status[@interlocking_name][@status_name] != nil &&
       watched_status[@interlocking_name][@status_name][0] != :init &&
       watched_status[@interlocking_name][@status_name][0] != :broken
      requested_position = watched_status[@interlocking_name][@status_name]
      if requested_position[0] != nil && requested_position != @current_position
        if requested_position[0] != @current_position[0]
          @current_position = requested_position.dup
          modify_status(@name, [-@current_position[0], nil, nil])
          @time_to_finish_moving = @framework.current_time + 5
          @schedule.merge_schedule [@time_to_finish_moving]
        else
          @current_position = requested_position.dup
          modify_status(@name, @current_position)
        end
      end
    end
    set_elapsed_time(0)
  end
end
