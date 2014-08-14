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

selector_inputs = []

%w[1 2].each {|j|

  interlocking_list = []
  %w[a b].each {|i|
    interlocking = "interlocking_#{j}_#{i}"
    fse.register_device(Railway::Interlocking.new(interlocking, "panel", "circuit", facilities))
    interlocking_list << interlocking
  }

  selector_input_soundness_list = []
  selector_input_status_list = []

  facilities.point.each_key {|point|
    fse.register_device(Railway::PointCmp.new("cmp_#{j}_#{point}", point, interlocking_list))
    fse.register_device(FSEvent::ValueIdDevice2.new("v_#{j}_#{point}", "cmp_#{j}_#{point}", point))
    selector_input_status_list << ["v_#{j}_#{point}", point]
    selector_input_soundness_list << ["cmp_#{j}_#{point}", "soundness"]
  }

  facilities.each_fixedsignal_name {|signal|
    fse.register_device(Railway::SignalCmp.new("cmp_#{j}_#{signal}", signal, interlocking_list))
    fse.register_device(FSEvent::ValueIdDevice2.new("v_#{j}_#{signal}", "cmp_#{j}_#{signal}", signal))
    selector_input_status_list << ["v_#{j}_#{signal}", signal]
    selector_input_soundness_list << ["cmp_#{j}_#{signal}", "soundness"]
  }

  selector_inputs << [selector_input_soundness_list, selector_input_status_list]
}

selector_output_status_names = []
facilities.point.each_key {|point|
  selector_output_status_names << point
}
facilities.each_fixedsignal_name {|signal|
  selector_output_status_names << signal
}

fse.register_device(Railway::Selector.new("selector", selector_output_status_names, *selector_inputs))

facilities.point.each_key {|point|
  fse.register_device(Railway::Point.new(point, 1, "selector", point))
}

facilities.each_fixedsignal_name {|signal|
  fse.register_device(Railway::FixedSignal.new(signal, "selector", signal))
}

fse.register_device(Railway::Train.new("train1", 15, ["r1", "r2", "r4"], facilities))
fse.register_device(Railway::Train.new("train2", 15, ["r5", "r6", "r8"], facilities))

#pp facilities

fse.start

