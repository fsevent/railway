# interlocking.rb --- interlocking device
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

class Railway::MbInterlocking < FSEvent::AbstractDevice

  # panel_status_list : array of device/status pair for resouces for a train.
  #   [[panel, train],
  #    [panel, train],
  #    ...]
  #   The status value is an array of resources: tubelist, partstate
  #   Note that "panel" will be panel device or latch device.
  #
  def initialize(device_name, panel_status_list)
    super device_name

    @panel_status_list = panel_status_list
    @points_watched = {}
    @interlocking_resources = {} # hash[train] = [resource, ...]
    @interlocking_status = {}
  end

  def registered
    @panel_status_list.each {|panel, train|
      add_watch(panel, train)
      add_watch(train, train)
      @interlocking_status[train] = true
      define_status(train, [])
    }
  end

  def run(watched_status, changed_status)
    #pp [watched_status, @interlocking_resources]
    @panel_status_list.each {|panel, train|
      if watched_status[panel] && watched_status[panel][train] &&
         watched_status[train] && watched_status[train][train]
        panel_resources = watched_status[panel][train]
        interlocking_resources = (@interlocking_resources[train] ||= [])
        train_resources = watched_status[train][train]
        (panel_resources | interlocking_resources | train_resources).each {|res|
          panel_locked = panel_resources.include? res
          interlocking_locked = interlocking_resources.include? res
          train_locked = train_resources.include? res
          case [panel_locked, interlocking_locked, train_locked]
          when [true, false, false]
            if lockable?(train, res, watched_status)
              puts "#{@framework.current_time} #{@name}: #{train} lock #{res.inspect}"
              @interlocking_resources[train] << res
              modify_status train, @interlocking_resources[train].dup
            else
              if res.requestable?
                request_resource res, train # start to change the point position.
              end
            end
          when [true, true, false] # wait: panel unlock or train lock
          when [true, true, true] # wait: panel unlock or train unlock
          when [false, true, true] # wait: train unlock
          when [false, true, false]
            puts "#{@framework.current_time} #{@name}: #{train} unlock #{res.inspect}"
            @interlocking_resources[train].delete res
            modify_status train, @interlocking_resources[train].dup
          #when [false, false, true] # forced unlock request from panel.  not supported.
          #when [true, false, true] # panel locked after forced unlock request from panel.  not supported.
          #when [false, false, false] # impossible
          else
            raise "should not happen: #{[panel_locked, interlocking_locked, train_locked].inspect} for #{res.inspect}"
          end
        }
      end
    }
  end

  def lockable?(target_train, res, watched_status)
    @panel_status_list.each {|_, train|
      next if target_train == train
      resources = []
      if watched_status[train] && watched_status[train][train]
        resources |= watched_status[train][train]
      end
      if @interlocking_resources[train]
        resources |= @interlocking_resources[train]
      end
      return false if resources.any? {|r|
        res.class == r.class && res.interfere?(r)
      }
      res.interlocking_status.each {|status, value|
        if !@interlocking_status.has_key?(status)
          @interlocking_status[status] = value
          define_status(status, value)
        end
      }
      res.part_states.each {|device, status, value|
        device_status = [device, status]
        unless @points_watched[device_status]
          @points_watched[device_status] = true
          add_watch(device, status)
        end
      }
      res.part_states.each {|d, s, value|
        return false unless watched_status[d] && watched_status[d][s]
      }
      return false if !res.lockable?(watched_status)
    }
    true
  end

  def request_resource(res, train)
    res.interlocking_status.each {|status, value|
      puts "#{@framework.current_time} #{@name}: #{train} request #{res.inspect}"
      if !@interlocking_status.has_key?(status)
        @interlocking_status[status] = value
        define_status(status, value)
      elsif @interlocking_status[status] != value
        @interlocking_status[status] = value
        modify_status(status, value)
      end
    }
  end

end


