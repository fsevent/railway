# fixedsignal.rb --- fixed signal device
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

class Railway::FixedSignal < FSEvent::AbstractDevice
  def initialize(device_name, interlocking_name, status_name)
    super(device_name)
    @interlocking_name = interlocking_name
    @status_name = status_name

    # stop (red): 0
    # proceed (green): 1
    @current_signal = [0, nil, nil]
  end

  def registered
    define_status(@name, @current_signal)
    add_watch(@interlocking_name, @status_name)
  end

  def run(watched_status, changed_status)
    if watched_status[@interlocking_name].has_key?(@status_name)
      if @current_signal != watched_status[@interlocking_name][@status_name]
        if watched_status[@interlocking_name][@status_name] == nil ||
           watched_status[@interlocking_name][@status_name][0] == :init
           watched_status[@interlocking_name][@status_name][0] == :broken
          @current_signal = [0, nil, nil]
        else
          @current_signal = watched_status[@interlocking_name][@status_name]
        end
        modify_status(@name, @current_signal)
      end
    end
    set_elapsed_time(0.1)
  end
end
