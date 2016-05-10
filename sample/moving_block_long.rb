# moving_block_long.rb --- cascaded moving block control
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

require 'railway'

facilities = Railway::MbFacilities.new


#                n2 ------ n3                     n8 --------- n9
#               /            \                   /               \
# n0 --- n1 - p0              p1 - n6 --- n7 - p2                 p3 - n12 ...
#               \            /                   \               /
#                n4 ------ n5                     n10 ------- n11

N = ENV.has_key?("MOVING_BLOCK_N") ? ENV["MOVING_BLOCK_N"].to_i : 3

facilities.add_node "n0", 0, 10
N.times {|i|
  x = i * 400
  facilities.add_node "n#{i*6+1}", x+200, 10
  facilities.add_node "n#{i*6+2}", x+220, 20
  facilities.add_node "n#{i*6+3}", x+380, 20
  facilities.add_node "n#{i*6+4}", x+220, 0
  facilities.add_node "n#{i*6+5}", x+380, 0
  facilities.add_node "n#{i*6+6}", x+400, 10
  facilities.add_point "p#{i*2+0}", "n#{i*6+1}", "n#{i*6+2}", "n#{i*6+4}"
  facilities.add_point "p#{i*2+1}", "n#{i*6+6}", "n#{i*6+5}", "n#{i*6+3}"
}
facilities.add_node "n#{N*6+1}", N*400+200, 10

t0 = Time.utc(2000)

total_plan = []

N.times {|i|
  t1 = t0 + i*60
  total_plan.concat [
    [t1   , t1+30, "train1", facilities.get_tube("n#{i*6+0}", "n#{i*6+1}")],
    [t1+20, t1+40, "train1", facilities.get_tube("n#{i*6+1}", "n#{i*6+2}")], # point
    #[t1+20, t1+40, "train1", facilities.get_partstate("p#{i*2+0}", "normal")],
    [t1+20, t1+60, "train1", facilities.get_tube("n#{i*6+2}", "n#{i*6+3}")],
    [t1+50, t1+70, "train1", facilities.get_tube("n#{i*6+3}", "n#{i*6+6}")], # point
    #[t1+50, t1+70, "train1", facilities.get_partstate("p#{i*2+1}", "reverse")],
  ]
}
total_plan << [t0+N*60, nil, "train1", facilities.get_tube("n#{N*6+0}", "n#{N*6+1}")]

N.times {|j|
  t1 = t0 + j*60
  i = N - j - 1
  total_plan.concat [
    [t1   , t1+30, "train2", facilities.get_tube("n#{i*6+7}", "n#{i*6+6}")],
    [t1+20, t1+40, "train2", facilities.get_tube("n#{i*6+6}", "n#{i*6+5}")], # point
    #[t1+20, t1+40, "train2", facilities.get_partstate("p#{i*2+1}", "normal")],
    [t1+20, t1+60, "train2", facilities.get_tube("n#{i*6+5}", "n#{i*6+4}")],
    [t1+50, t1+70, "train2", facilities.get_tube("n#{i*6+4}", "n#{i*6+1}")], # point
    #[t1+50, t1+70, "train2", facilities.get_partstate("p#{i*2+0}", "reverse")],
  ]
}
total_plan << [t0+N*60, nil, "train2", facilities.get_tube("n1", "n0")]

panel_plan = []
train_plan = {}

total_plan.each {|t1, t2, train, res|
  train_plan[train] ||= []
  train_plan[train] << [t1, res, true] if t1
  train_plan[train] << [t2, res, false] if t2
  panel_plan << [t1, train, res, true] if t1
  panel_plan << [t2, train, res, false] if t2
}

panel_plan = panel_plan.sort_by {|t, train, res, lock_or_unlock| t }
train_plan.keys.each {|train|
  train_plan[train] = train_plan[train].sort_by {|t, res, lock_or_unlock| t }
}

panel_status_list = []
train_plan.each {|train,|
  panel_status_list << ["panel", train]
}

fse = FSEvent.new(t0)
#fse.register_device(FSEvent::DebugDumper.new)
#fse.register_device(Railway::Dumper.new)
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

