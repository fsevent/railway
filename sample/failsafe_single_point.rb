require 'railway'

facilities = Railway::Facilities.new

facilities.add_point "p1", "n1", ["n2", 5], ["n3", 5]

facilities.add_route "r1", nil, [["n1", "n3", "p1"]]

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
fse.register_device(Railway::Interlocking.new("interlocking1", facilities))
fse.register_device(Railway::Interlocking.new("interlocking2", facilities))
fse.register_device(Railway::SaferSignal.new("sr1", "r1", "interlocking1", "interlocking2"))
fse.register_device(Railway::SaferPoint.new("sp1", "p1", "interlocking1", "interlocking2"))
fse.register_device(FSEvent::ValueIdDevice2.new("vp1", "sp1", "p1"))
fse.register_device(Railway::Point.new("p1", 1, "vp1", "p1"))
fse.register_device(FSEvent::ValueIdDevice2.new("vr1", "sr1", "r1"))
fse.register_device(Railway::FixedSignal.new("r1", "vr1", "r1"))
fse.register_device(Railway::Panel.new("panel", facilities, panel_plan))

fse.register_device(train = Railway::Train.new("train1", 15, ["r1"], facilities))

#pp facilities

fse.start
