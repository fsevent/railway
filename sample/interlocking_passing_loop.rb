require 'railway'

facilities = Railway::Facilities.new

# n1 --- n2 - s1 - n3 --- n4
#              \           \
#               n8 --- n7 - s2 - n6 --- n5
#
# r1: n1 - n2
# r2: n2 -s1- n3 - n4
# r4: n4 -s2- n7 - n8
# r5: n5 - n6
# r6: n6 -s2- n7 - n8
# r8: n8 -s1- n2 - n1

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
fse.register_device(Railway::Interlocking.new("interlocking1", facilities))
fse.register_device(Railway::Circuit.new("circuit", facilities))
fse.register_device(FSEvent::ValueIdDevice2.new("vp1", "interlocking1", "p1"))
fse.register_device(FSEvent::ValueIdDevice2.new("vp2", "interlocking1", "p2"))
fse.register_device(FSEvent::ValueIdDevice2.new("vr1", "interlocking1", "r1"))
fse.register_device(FSEvent::ValueIdDevice2.new("vr2", "interlocking1", "r2"))
fse.register_device(FSEvent::ValueIdDevice2.new("vr4", "interlocking1", "r4"))
fse.register_device(FSEvent::ValueIdDevice2.new("vr5", "interlocking1", "r5"))
fse.register_device(FSEvent::ValueIdDevice2.new("vr6", "interlocking1", "r6"))
fse.register_device(FSEvent::ValueIdDevice2.new("vr8", "interlocking1", "r8"))
fse.register_device(Railway::Point.new("p1", 1, "vp1", "p1"))
fse.register_device(Railway::Point.new("p2", 1, "vp2", "p2"))
fse.register_device(Railway::FixedSignal.new("r1", "vr1", "r1"))
fse.register_device(Railway::FixedSignal.new("r2", "vr2", "r2"))
fse.register_device(Railway::FixedSignal.new("r4", "vr4", "r4"))
fse.register_device(Railway::FixedSignal.new("r5", "vr5", "r5"))
fse.register_device(Railway::FixedSignal.new("r6", "vr6", "r6"))
fse.register_device(Railway::FixedSignal.new("r8", "vr8", "r8"))
fse.register_device(Railway::Train.new("train1", 15, ["r1", "r2", "r4"], facilities))
fse.register_device(Railway::Train.new("train2", 15, ["r5", "r6", "r8"], facilities))

#pp facilities

fse.start

