require 'railway'

facilities = Railway::Facilities.new

facilities.add_track "t1", "n1", "n2", 10

facilities.add_route "r1", nil, [["n1", "n2", "t1"]]

facilities.track.each {|track_name, (n1, n2, _len)|
  [ [n1, n2, track_name],
    [n2, n1, track_name] ].each {|segment|
    facilities.add_circuit "c#{track_name}", segment
    facilities.add_area segment, track_name
  }
}
facilities.switch.each {|switch_name, (tn, (bn1, _len1), (bn2, _len2))|
  [ [tn, bn1, switch_name],
    [tn, bn2, switch_name],
    [bn1, tn, switch_name],
    [bn2, tn, switch_name] ].each {|segment|
    facilities.add_circuit "c#{switch_name}", segment
    facilities.add_area segment, switch_name
  }
}

t0 = Time.utc(2000)

panel_plan = [
  [t0+10, "r1", true],
]

fse = FSEvent.new(t0)
#fse.register_device(FSEvent::DebugDumper.new)
fse.register_device(Railway::Circuit.new("circuit", facilities))
fse.register_device(Railway::Interlocking.new("interlocking1", facilities))
fse.register_device(FSEvent::ValueIdDevice2.new("vr1", "interlocking1", "r1"))
fse.register_device(Railway::Signal.new("r1", "vr1", "r1"))
fse.register_device(Railway::Panel.new("panel", facilities, panel_plan))

fse.register_device(train = Railway::Train.new("train1", 15, ["r1"], facilities))

#pp facilities

fse.start

