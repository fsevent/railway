# train.rb --- train device
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

class Railway::MbTrain < FSEvent::AbstractDevice
  def initialize(device_name, train_len, plan, interlocking_status)
    super(device_name)

    @train = device_name

    @train_len = train_len
    @plan = plan.sort_by {|t,| t } # [route1, route2, ...]
    @interlocking_status = interlocking_status # device/status

    @train_resources = []
  end

  def registered
    super
    define_status(@train, @train_resources.dup)
    add_watch(*@interlocking_status)
  end

  def run(watched_status, changed_status)
    #pp watched_status
    #p [@framework.current_time, @name, @plan.first]
    until @plan.empty?
      t, res, lock_or_unlock = @plan.first
      if @framework.current_time < t
        @schedule.merge_schedule [t]
        return
      end
      #p [@name, t, res, lock_or_unlock]
      len1 = @plan.length
      if lock_or_unlock
        if watched_status[@interlocking_status[0]] &&
           watched_status[@interlocking_status[0]][@interlocking_status[1]]
          interlocking_resources = watched_status[@interlocking_status[0]][@interlocking_status[1]]
          interlocking_locked = interlocking_resources.include? res
          if interlocking_locked
            puts "#{@framework.current_time} #{@name}: lock #{res.inspect}"
            @train_resources |= [res]
            modify_status @train, @train_resources.dup
            @plan.shift
          end
        end
      else
        unless @train_resources.include? res
          raise "should not happen"
        end
        puts "#{@framework.current_time} #{@name}: unlock #{res.inspect}"
        @train_resources -= [res]
        modify_status @train, @train_resources.dup
        @plan.shift
      end
      #p [@name, @train_resources]
      len2 = @plan.length
      if len1 == len2
        set_elapsed_time(1)
        return
      end
    end
  end

  ############
end
