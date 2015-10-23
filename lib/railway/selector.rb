# selector.rb --- selector device
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

class Railway::Selector < FSEvent::AbstractDevice
  def initialize(device_name, output_status_names, *inputs)
    super device_name
    @output_status_names = output_status_names
    @inputs = inputs # [status_list, ...]
                     # status_list = [[device_name, status_name], ...]
                     # where output_status_names.length == status_list.length
    @inputs.each {|status_list|
      if output_status_names.length != status_list.length
        raise "number of status unmatch"
      end
    }
    @current = 0
  end

  def registered
    @output_status_names.each {|status_name|
      define_status(status_name, [:init, nil, nil])
    }
    @inputs.each {|status_list|
      status_list.each {|device_name, status_name|
        add_watch(device_name, status_name)
      }
    }
  end

  def run(watched_status, changed_status)
    soundness = []
    @inputs.each_with_index {|status_list, i|
      s = true
      status_list.each {|device_name, status_name|
        return if !watched_status.has_key?(device_name)
        return if !watched_status[device_name].has_key?(status_name)
        s &&= watched_status[device_name][status_name][0] != :broken
        break if !s
      }
      soundness[i] = s
    }
    if soundness.any?
      while !soundness[@current]
        @current = (@current + 1) % soundness.length
      end
      status_list = @inputs[@current]
      @output_status_names.each_with_index {|output_status_name, i|
        input_device_name, input_status_name = status_list[i]
        modify_status(output_status_name, watched_status[input_device_name][input_status_name])
      }
    end
  end
end

