class Railway::Interlocking < FSEvent::AbstractDevice
  def initialize(device_name, facilities)
    super device_name
    @facilities = facilities

    @area_lock = {} # area -> nil | owner_route
    @switch_lock = {} # switch -> nil | [owner_route, ...]

    @closed_loop_output = {} # status_name -> [value, id, stable]

    @route_state = {} # route -> state
                      # state = nil | :wait_allocation | :signaled | :entered | :wait_deallocation

    @unlocked_rear_numsegments = {} # route -> integer
  end

  def registered
    @facilities.switch.each_key {|switch|
      add_watch(switch, "position")
    }
    @facilities.switch.each_key {|switch|
      add_watch(switch, switch)
      define_closed_loop_status(switch, nil)
    }
    @facilities.route_segments.each_key {|signal|
      add_watch("panel", signal)
      add_watch(signal, signal)
      define_closed_loop_status(signal, 0)
    }
    @facilities.circuit.values.uniq.each {|circuit|
      add_watch("circuit", circuit)
    }
  end

  def run(watched_status, changed_status)
    propagate_closed_loop_status(watched_status)
    @facilities.route_segments.each_key {|signal|
      run_route(signal, watched_status, changed_status)
    }
  end

  def run_route(route, watched_status, changed_status)
    lever = watched_status.has_key?("panel") && watched_status["panel"][route]
    if @route_state[route] == nil
      if lever
        lock_procs = route_lockable?(route, watched_status)
        if lock_procs
          lock_procs.each {|pr| pr.call }
          @route_state[route] = :wait_allocation
        end
      end
    end
    if @route_state[route] == :wait_allocation
      if route_allocated?(route, watched_status)
        modify_closed_loop_status(route, 1)
        @route_state[route] = :signaled
      end
    end
    if @route_state[route] == :signaled
      if train_in_route?(route, watched_status)
        @route_state[route] = :entered
        @unlocked_rear_numsegments[route] = 0
        modify_closed_loop_status(route, 0)
      end
    end
    if @route_state[route] == :entered
      if unlock_rear(route, watched_status)
        @route_state[route] = :wait_deallocation
      end
    end
    if @route_state[route] == :wait_deallocation
      if signal_stable_stop?(route, watched_status)
        @route_state[route] = nil
      end
    end
  end

  def signal_stable_stop?(route, watched_status)
    watched_status[route][route][0] == 0 && watched_status[route][route][2] == true
  end

  def route_lockable?(route, watched_status)
    lock_procs = []
    @facilities.route_segments[route].each {|segment|
      @facilities.area[segment].each {|area|
        if @area_lock[area]
          return nil
        end
        lock_procs << lambda { @area_lock[area] = route }
      }
      n1, n2, rail = segment
      railtype = @facilities.railtype[rail]
      case railtype
      when :track
      when :switch
        unless watched_status.has_key?(rail) && watched_status[rail][rail]
          return nil
        end
        output_position = refer_closed_loop_status(rail)
        desired_position = @facilities.switch_position(rail, n1, n2)
        if @switch_lock[rail] == nil || @switch_lock[rail].empty?
          lock_procs << lambda {
            @switch_lock[rail] = [route]
          }
          if output_position != desired_position
            lock_procs << lambda {
              modify_closed_loop_status(rail, desired_position)
            }
          end
        elsif output_position == desired_position
          lock_procs << lambda {
            @switch_lock[rail] << route
          }
        else
          return nil
        end
      else
        raise "unexpected rail type: #{railtype} for #{rail.inspect}"
      end
    }
    return lock_procs
  end

  def route_allocated?(route, watched_status)
    @facilities.route_segments[route].all? {|segment|
      n1, n2, rail = segment
      railtype = @facilities.railtype[rail]
      case railtype
      when :track
        true
      when :switch
        closed_loop_stable?(rail)
      else
        raise "unexpected rail type: #{railtype} for #{rail.inspect}"
      end
    }
  end

  def train_in_route?(route, watched_status)
    @facilities.route_segments[route].any? {|segment|
      circuit = @facilities.circuit[segment]
      watched_status["circuit"][circuit]
    }
  end

  def unlock_rear(route, watched_status)
    segments = @facilities.route_segments[route]
    segments = segments[@unlocked_rear_numsegments[route]..-1]
    while !segments.empty? && !watched_status["circuit"][@facilities.circuit[segments.first]]
      segment = segments.shift
      @unlocked_rear_numsegments[route] += 1
      @facilities.area[segment].each {|area|
        @area_lock[area] = nil
      }
      n1, n2, rail = segment
      railtype = @facilities.railtype[rail]
      case railtype
      when :track
      when :switch
        @switch_lock[rail].delete route
      else
        raise "unexpected rail type: #{railtype} for #{rail.inspect}"
      end
    end
    segments.empty?
  end

  def define_closed_loop_status(status_name, value)
    @closed_loop_output[status_name] = [value, nil, nil]
    define_status(status_name, @closed_loop_output[status_name])
  end

  def modify_closed_loop_status(status_name, value)
    if @closed_loop_output[status_name][0] != value
      @closed_loop_output[status_name] = [value, nil, nil]
      modify_status(status_name, @closed_loop_output[status_name])
    end
  end

  def refer_closed_loop_status(status_name)
    @closed_loop_output[status_name][0]
  end

  def closed_loop_stable?(key)
    @closed_loop_output[key][2]
  end

  def propagate_closed_loop_status(watched_status)
    @closed_loop_output.each_key {|key|
      if watched_status.has_key?(key) && watched_status[key][key]
        input_tuple = watched_status[key][key]
        output_tuple = @closed_loop_output[key]
        if input_tuple != output_tuple
          input_value, = input_tuple
          output_value, = output_tuple
          if input_value == output_value
            @closed_loop_output[key] = input_tuple
            modify_status(key, @closed_loop_output[key])
          end
        end
      end
    }
  end

end


