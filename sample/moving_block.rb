# interlocking_passing_loop.rb --- passing sample without redundancy
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

facilities = Railway::MbFacilities.new

# n1 --- n2 - p1 - n3 --- n4
#              \           \
#               n8 --- n7 - p2 - n6 --- n5

facilities.add_node "n1", 0, 10
facilities.add_node "n2", 200, 10
facilities.add_node "n3", 210, 10
facilities.add_node "n4", 400, 10

facilities.add_node "n5", 610, 0
facilities.add_node "n6", 410, 0
facilities.add_node "n7", 400, 0
facilities.add_node "n8", 210, 0

facilities.add_point "p1", "n2", "n3", "n8"
facilities.add_point "p2", "n6", "n4", "n7"

t0 = Time.utc(2000)

total_plan = [
  [t0   , t0+15, "train1", facilities.get_tube("n1", "n2")],
  [t0+10, t0+16, "train1", facilities.get_partstate("p1", "normal")],
  [t0+10, t0+16, "train1", facilities.get_tube("n2", "n3")], # point
  [t0+10, t0+25, "train1", facilities.get_tube("n3", "n4")],
  [t0+20, t0+26, "train1", facilities.get_partstate("p2", "reverse")],
  [t0+20, t0+26, "train1", facilities.get_tube("n4", "n6")], # point
  [t0+20, nil,   "train1", facilities.get_tube("n6", "n5")],

  [t0   , t0+15, "train2", facilities.get_tube("n5", "n6")],
  [t0+10, t0+16, "train2", facilities.get_partstate("p2", "normal")],
  [t0+10, t0+16, "train2", facilities.get_tube("n6", "n7")], # point
  [t0+10, t0+25, "train2", facilities.get_tube("n7", "n8")],
  [t0+20, t0+26, "train2", facilities.get_partstate("p1", "reverse")],
  [t0+20, t0+26, "train2", facilities.get_tube("n8", "n2")], # point
  [t0+20, nil,   "train2", facilities.get_tube("n2", "n1")],
]

panel_plan = []
train_plan = {}

total_plan.each {|t1, t2, train, res, lock_or_unlock|
  train_plan[train] ||= []
  train_plan[train] << [t1, res, true] if t1
  train_plan[train] << [t2, res, false] if t2
  panel_plan << [t1, train, res, true] if t1
  panel_plan << [t2, train, res, false] if t2
}

panel_status_list = []
train_plan.each {|train,|
  panel_status_list << ["panel", train]
}

fse = FSEvent.new(t0)
#fse.register_device(FSEvent::DebugDumper.new)
fse.register_device(Railway::Dumper.new)
fse.register_device(Railway::MbPanel.new("panel", panel_plan))
fse.register_device(Railway::MbInterlocking.new("interlocking", panel_status_list))

facilities.point.each_key {|point|
  fse.register_device(Railway::MBPoint.new(point, "normal", ["interlocking", point]))
}

train_len = 15
train_plan.each {|train, train_plan|
  fse.register_device(Railway::MbTrain.new(train, train_len, train_plan, ["interlocking", train]))
}

#pp facilities

fse.start

