# dumper.rb --- status dumper device
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

class Railway::Dumper < FSEvent::AbstractDevice
  def initialize(device_name="railwaydumper", show_failsafe:false)
    super device_name
    @show_failsafe = show_failsafe
  end

  def registered
    add_watch("*", "*")
  end

  def run(watched_status, changed_status)
    #pp watched_status
    route = {}
    point = []
    train = []
    interlocking = {}
    watched_status.each {|device_name, h|
      next if @name == device_name
      case device_name
      when "panel"
        h.each {|status_name, value|
          if /\Ar/ =~ status_name
            route[status_name] ||= []
            route[status_name][1] = value ? 1 : 0
          end
        }
      when /\As[0-9]/
        next if !h[device_name]
        route[signal_to_route(device_name)] ||= []
        route[signal_to_route(device_name)][0] = h[device_name][0]
      when /\Ap/
        point << [device_name, h[device_name][0]]
      when /\Atrain/
        position = h["position"]
        if !position.empty?
          train << [device_name, position[0][0], position[-1][1]]
        end
      when /\Ainterlocking/
        h.each {|status_name, value|
          if /\A[sp]/ =~ status_name
            interlocking[status_name] ||= {}
            interlocking[status_name][device_name] = value
          end
        }
      end
    }
    #p route
    point.sort!
    train.sort!
    str = @framework.current_time.to_s
    route.keys.sort.each {|route_name|
      signal, lever = route[route_name]
      str << " #{route_name}:#{signal}"
      if @show_failsafe
        str << "[" << interlocking[route_name].keys.sort.map {|device_name| interlocking[route_name][device_name][0] }.join(",") << "]"
      end
      if signal != lever
        str << "(#{lever})"
      end
    }
    point.each {|point_name, position|
      str << " #{point_name}:#{position}"
      if @show_failsafe
        str << "[" << interlocking[point_name].keys.sort.map {|device_name| interlocking[point_name][device_name][0] }.join(",") << "]"
      end
    }
    train.each {|device_name, pos1, pos2|
      str << " #{device_name}:#{pos1}-#{pos2}"
    }
    puts str
    set_elapsed_time(0)
  end

  def signal_to_route(route)
    route.sub(/\As/, 'r')
  end

end
