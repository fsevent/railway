# interlocking_single_track.rb --- non-failsafe sample with single track
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

facilities.add_route "r1", nil, [["n1", "n2", "t1"]]

facilities.each_segment {|rail, segment|
  facilities.add_circuit "c#{rail}", segment
  facilities.add_area segment, rail
}

t0 = Time.utc(2000)

panel_plan = [
  [t0+10, "r1", true],
]

fse = FSEvent.new(t0)
#fse.register_device(FSEvent::DebugDumper.new)
fse.register_device(Railway::Dumper.new)
fse.register_device(Railway::Circuit.new("circuit", facilities))
fse.register_device(Railway::Interlocking.new("interlocking1", "panel", "circuit", facilities))
fse.register_device(FSEvent::ValueIdDevice2.new("vs1", "interlocking1", "s1"))
fse.register_device(Railway::FixedSignal.new("s1", "vs1", "s1"))
fse.register_device(Railway::Panel.new("panel", facilities, panel_plan))

fse.register_device(train = Railway::Train.new("train1", 15, ["r1"], facilities))

#pp facilities

fse.start

