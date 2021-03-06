# timedcontrol.rb --- time-based control sample
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

require 'railway'

facilities = Railway::Facilities.new
facilities.add_track "t1", "n1", "n2", 10
facilities.add_track "t2", "n2", "n3", 10
facilities.add_track "t3", "n3", "n4", 10

facilities.add_point "p1", "n4", ["n5", 5], ["n8", 5]

facilities.add_track "t5", "n5", "n6", 10
facilities.add_track "t6", "n6", "n7", 10
facilities.add_track "t7", "n7", "n8", 10

facilities.add_track "t8", "n8", "n9", 10
facilities.add_track "t9", "n9", "n10", 10
facilities.add_track "t10", "n10", "n11", 10

facilities.add_route "r1", nil, [["n1", "n2", "t1"], ["n2", "n3", "t2"], ["n3", "n4", "t3"], ["n4", "n5", "p1"], ["n5", "n6", "t5"], ["n6", "n7", "t6"], ["n7", "n8", "t7"]]
facilities.add_route "r2", nil, [["n1", "n2", "t1"], ["n2", "n3", "t2"], ["n3", "n4", "t3"], ["n4", "n8", "p1"], ["n8", "n9", "t8"], ["n9", "n10", "t9"], ["n10", "n11", "t10"]]

facilities.each_segment {|rail, segment|
  facilities.add_circuit "c#{rail}", segment
  facilities.add_area segment, rail
}

class GreenSignal < FSEvent::AbstractDevice
  def registered
    define_status(@name, 1) # "1" means green.
  end

  def run(watched_status, changed_status)
  end
end

class FixedPoint < FSEvent::AbstractDevice
  def initialize(device_name, position)
    super device_name
    @position = position
  end

  def registered
    define_status(@name, [@position, nil, nil])
  end

  def run(watched_status, changed_status)
  end
end

class ScheduledSignal < FSEvent::AbstractDevice
  def initialize(device_name, plan)
    super device_name
    @plan = plan.dup
    @schedule.merge_schedule @plan.map {|t, s| t }
    @first = true
  end

  def registered
    set_elapsed_time(0)
  end

  def run(watched_status, changed_status)
    while !@plan.empty? && @plan[0][0] <= @framework.current_time
      if @first
        define_status(@name, [@plan[0][1], nil, nil])
        @first = false
      else
        modify_status(@name, [@plan[0][1], nil, nil])
      end
      @plan.shift
    end
    set_elapsed_time(0)
  end
end

class RawScheduledPoint < FSEvent::AbstractDevice
  def initialize(device_name, plan)
    super device_name
    @plan = plan.dup
    @schedule.merge_schedule @plan.map {|t, pos| t }
    @first = true
  end

  def registered
    set_elapsed_time(0)
  end

  def run(watched_status, changed_status)
    while !@plan.empty? && @plan[0][0] <= @framework.current_time
      if @first
        define_status(@name, [@plan[0][1], nil, nil])
        @first = false
      else
        modify_status(@name, [@plan[0][1], nil, nil])
      end
      @plan.shift
    end
    set_elapsed_time(0)
  end
end

class ScheduledPoint < RawScheduledPoint
  def initialize(device_name, plan)
    raw_plan = []
    first = true
    plan.each {|t, pos|
      if first
        first = false
      else
        raw_plan << [t-5, -pos] # point position movement needs 5 seconds
      end
      raw_plan << [t, pos]
    }
    if raw_plan.map {|t,pos| t } != raw_plan.map {|t, pos| t }.sort
      raise "not enough interval to change point position"
    end
    super device_name, raw_plan
  end
end

t0 = Time.utc(2000)

fse = FSEvent.new(t0)
#fse.register_device(FSEvent::DebugDumper.new)
fse.register_device(Railway::Dumper.new)
fse.register_device(train = Railway::Train.new("train1", 15, ["r2"], facilities))
fse.register_device(Railway::Circuit.new("circuit", facilities))
fse.register_device(ScheduledSignal.new("s2", [[t0, 0], [t0+7, 1], [t0+13,0]]))
fse.register_device(ScheduledPoint.new("p1", [[t0, 1], [t0+6, 2], [t0+30,1]]))

#pp facilities

fse.start

