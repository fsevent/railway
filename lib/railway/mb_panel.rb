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

class Railway::MbPanel < FSEvent::AbstractDevice
  def initialize(device_name, panel_plan)
    super device_name
    @panel_plan = panel_plan.sort_by {|t,| t }
    @train_resources = {}
  end

  def registered
    set_elapsed_time(0)
    set_next_schedule
  end

  def run(watched_status, changed_status)
    until @panel_plan.empty?
      t, train, res, lock_or_unlock = @panel_plan.first
      break if @framework.current_time < t
      #p [t, train, res, lock_or_unlock]
      @panel_plan.shift
      if !@train_resources[train]
        @train_resources[train] = []
        define_status(train, [])
      end
      if lock_or_unlock
        puts "#{@framework.current_time} #{@name}: #{train} lock #{res.inspect}"
        @train_resources[train] |= [res]
      else
        puts "#{@framework.current_time} #{@name}: #{train} unlock #{res.inspect}"
        @train_resources[train] -= [res]
      end
      modify_status(train, @train_resources[train])
    end
    set_next_schedule
  end

  def set_next_schedule
    unless @panel_plan.empty?
      t, _train, _res, _lock_or_unlock = @panel_plan.first
      @schedule.merge_schedule [t]
    end
  end
end


