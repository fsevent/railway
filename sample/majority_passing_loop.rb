# majority_passing_loop.rb --- passing sample using majority device
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

# n1 --- n2 - p1 - n3 --- n4
#              \           \
#               n8 --- n7 - p2 - n6 --- n5
#
# r1: n1 - n2
# r2: n2 -p1- n3 - n4
# r4: n4 -p2- n7 - n8
# r5: n5 - n6
# r6: n6 -p2- n7 - n8
# r8: n8 -p1- n2 - n1

facilities.add_track "t1", "n1", "n2", 200
facilities.add_point "p1", "n2", ["n3", 5], ["n8", 5]
facilities.add_track "t3", "n3", "n4", 200
facilities.add_track "t5", "n5", "n6", 200
facilities.add_point "p2", "n6", ["n7", 5], ["n4", 5]
facilities.add_track "t7", "n7", "n8", 200

facilities.add_route "r1", nil, [["n1", "n2", "t1"]]
facilities.add_route "r2", nil, [["n2", "n3", "p1"], ["n3", "n4", "t3"]]
facilities.add_route "r4", nil, [["n4", "n6", "p2"], ["n6", "n5", "t5"]]

facilities.add_route "r5", nil, [["n5", "n6", "t5"]]
facilities.add_route "r6", nil, [["n6", "n7", "p2"], ["n7", "n8", "t7"]]
facilities.add_route "r8", nil, [["n8", "n2", "p1"], ["n2", "n1", "t1"]]

facilities.each_segment {|rail, segment|
  facilities.add_circuit "c#{rail}", segment
  facilities.add_area segment, rail
}

t0 = Time.utc(2000)

panel_plan = [
  [t0+10, "r1", true],
  [t0+10, "r5", true],
  [t0+20, "r2", true],
  [t0+20, "r6", true],
  [t0+15, "r1", false],
  [t0+15, "r5", false],
  [t0+30, "r2", false],
  [t0+30, "r6", false],
  [t0+35, "r4", true],
  [t0+35, "r8", true],
  [t0+45, "r4", false],
  [t0+45, "r8", false],
]

fse = FSEvent.new(t0)
#fse.register_device(FSEvent::DebugDumper.new)
fse.register_device(Railway::Dumper.new)
fse.register_device(Railway::Panel.new("panel", facilities, panel_plan))
fse.register_device(Railway::Circuit.new("circuit", facilities))

latch_inputs = []

facilities.each_route_and_fixedsignal_name {|route, signal|
  latch_inputs << ["panel", route]
  latch_inputs << [signal, signal]
}
facilities.circuit.values.uniq.each {|circuit|
  latch_inputs << ["circuit", circuit]
}
facilities.point.each_key {|point|
  latch_inputs << [point, point]
}

interlocking_list = []
%w[a b c].each {|i|
  interlocking = "interlocking_#{i}"
  fse.register_device(Railway::Interlocking.new(interlocking, "latch", "latch", facilities, "latch"))
  interlocking_list << interlocking
}

facilities.point.each_key {|point|
  fse.register_device(Railway::Majority.new("majority_#{point}", point, interlocking_list, "count"))
  fse.register_device(FSEvent::ValueIdDevice2.new("v_#{point}", "majority_#{point}", point))
  fse.register_device(Railway::Point.new(point, 1, "v_#{point}", point))
}

facilities.each_fixedsignal_name {|signal|
  fse.register_device(Railway::Majority.new("majority_#{signal}", signal, interlocking_list, "count"))
  fse.register_device(FSEvent::ValueIdDevice2.new("v_#{signal}", "majority_#{signal}", signal))
  fse.register_device(Railway::FixedSignal.new(signal, "v_#{signal}", signal))
}

fse.register_device(Railway::Latch.new("latch", *latch_inputs))


fse.register_device(Railway::Train.new("train1", 15, ["r1", "r2", "r4"], facilities))
fse.register_device(Railway::Train.new("train2", 15, ["r5", "r6", "r8"], facilities))

#pp facilities

fse.start

