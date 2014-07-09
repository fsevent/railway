class Railway::Interlocking < FSEvent::AbstractDevice
  def initialize(device_name, facilities)
    super device_name
    @facilities = facilities

    @area_lock = {} # area -> nil | owner_route
    @point_lock = {} # point -> nil | [owner_route, ...]

    @closed_loop_watch = {} # status_name -> [watchee_device_name, watchee_status_name]
    @closed_loop_output = {} # status_name -> [value, id, stable]

    @route_state = {} # route -> state
                      # state = nil | :wait_allocation | :signaled | :entered | :wait_deallocation
    @route_schedule = {}

    @unlocked_rear_numsegments = {} # route -> integer
  end

  def registered
    @facilities.point.each_key {|point|
      define_closed_loop_status(point, nil, point, point)
    }
    @facilities.each_route_and_fixedsignal_name {|route, signal|
      add_watch("panel", route)
      define_closed_loop_status(signal, 0, signal, signal)
    }
    @facilities.circuit.values.uniq.each {|circuit|
      add_watch("circuit", circuit)
    }
  end

  def run(watched_status, changed_status)
    propagate_closed_loop_status(watched_status)
    @facilities.each_route_and_fixedsignal_name {|route, signal|
      run_route(route, signal, watched_status, changed_status)
    }
  end

  def run_route(route, signal, watched_status, changed_status)
    lever = watched_status.has_key?("panel") && watched_status["panel"][route]
    begin
      case @route_state[route]
      when nil
        more = run_route_default(route, signal, lever, watched_status)
      when :wait_allocation
        more = run_route_wait_allocation(route, signal, lever, watched_status)
      when :signaled
        more = run_route_signaled(route, signal, lever, watched_status)
      when :entered
        more = run_route_entered(route, signal, lever, watched_status)
      when :wait_deallocation
        more = run_route_wait_deallocation(route, signal, lever, watched_status)
      when :wait_approaching_train_stop
        more = run_route_wait_approaching_train_stop(route, signal, lever, watched_status)
      else
        raise "unexpected route state: #{@route_state[route].inspect}"
      end
    end while more
  end

  def run_route_default(route, signal, lever, watched_status)
    if lever
      lock_procs = route_lockable?(route, watched_status)
      if lock_procs
        lock_procs.each {|pr| pr.call }
        @route_state[route] = :wait_allocation
        return true
      end
    end
    false
  end

  def run_route_wait_allocation(route, signal, lever, watched_status)
    if lever
      if route_allocated?(route, watched_status)
        modify_closed_loop_status(signal, 1)
        @route_state[route] = :signaled
        return true
      end
    else
      route_unlock(route)
      modify_closed_loop_status(signal, 0)
      @route_state[route] = nil
      return true
    end
    false
  end

  def run_route_signaled(route, signal, lever, watched_status)
    if lever
      if train_in_route?(route, watched_status)
        @route_state[route] = :entered
        @unlocked_rear_numsegments[route] = 0
        modify_closed_loop_status(signal, 0)
        return true
      end
    else
      if train_may_enter_route?(route, watched_status)
        modify_closed_loop_status(signal, 0)
        @route_state[route] = :wait_approaching_train_stop
        @route_schedule[route] = @framework.current_time + @facilities.approach_timer[route]
        @schedule.merge_schedule [@route_schedule[route]]
      else
        route_unlock(route)
        modify_closed_loop_status(signal, 0)
        @route_state[route] = nil
      end
      return true
    end
    false
  end

  def run_route_entered(route, signal, lever, watched_status)
    if unlock_rear(route, watched_status)
      @route_state[route] = :wait_deallocation
      return true
    end
    false
  end

  def run_route_wait_deallocation(route, signal, lever, watched_status)
    if signal_stop_confirmed?(signal, watched_status)
      @route_state[route] = nil
      return true
    end
    false
  end

  def run_route_wait_approaching_train_stop(route, signal, lever, watched_status)
    if train_in_route?(route, watched_status)
      @route_state[route] = :entered
      @route_schedule[route] = nil
      @unlocked_rear_numsegments[route] = 0
      modify_closed_loop_status(signal, 0)
      return true
    end
    if @route_schedule[route] <= @framework.current_time
      route_unlock(route)
      @route_state[route] = nil
      @route_schedule.delete route
      return true
    end
    false
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
      when :point
        unless watched_status.has_key?(rail) && watched_status[rail][rail]
          return nil
        end
        output_position = refer_closed_loop_status(rail)
        desired_position = @facilities.point_position(rail, n1, n2)
        if @point_lock[rail] == nil || @point_lock[rail].empty?
          lock_procs << lambda {
            @point_lock[rail] = [route]
          }
          if output_position != desired_position
            lock_procs << lambda {
              modify_closed_loop_status(rail, desired_position)
            }
          end
        elsif output_position == desired_position
          lock_procs << lambda {
            @point_lock[rail] << route
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

  def route_unlock(route)
    lock_procs = []
    @facilities.route_segments[route].each {|segment|
      @facilities.area[segment].each {|area|
        if @area_lock[area] != route
          raise "try to unlock area, #{area.inspect}, not locked by #{route}"
        end
        @area_lock[area] = nil
      }
      n1, n2, rail = segment
      railtype = @facilities.railtype[rail]
      case railtype
      when :track
      when :point
        if @point_lock[rail] == nil || !@point_lock[rail].include?(route)
          raise "try to unlock point, #{rail.inspect}, not locked by #{route}"
        end
        @point_lock[rail].delete route
      else
        raise "unexpected rail type: #{railtype} for #{rail.inspect}"
      end
    }
  end

  def route_allocated?(route, watched_status)
    @facilities.route_segments[route].all? {|segment|
      n1, n2, rail = segment
      railtype = @facilities.railtype[rail]
      case railtype
      when :track
        true
      when :point
        closed_loop_stable?(rail)
      else
        raise "unexpected rail type: #{railtype} for #{rail.inspect}"
      end
    }
  end

  def train_may_enter_route?(route, watched_status)
    unless @facilities.approach_segments[route]
      return true # Assume a train approaching if no track circuit to detect the train.
    end
    @facilities.approach_segments[route].any? {|segment|
      circuit = @facilities.circuit[segment]
      watched_status["circuit"][circuit]
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
      when :point
        @point_lock[rail].delete route
      else
        raise "unexpected rail type: #{railtype} for #{rail.inspect}"
      end
    end
    segments.empty?
  end

  def signal_stop_confirmed?(signal, watched_status)
    refer_closed_loop_status(signal) == 0 && closed_loop_stable?(signal)
  end

  def define_closed_loop_status(status_name, value, watchee_device_name, watchee_status_name)
    @closed_loop_watch[status_name] = [watchee_device_name, watchee_status_name]
    @closed_loop_output[status_name] = [value, nil, nil]
    add_watch(watchee_device_name, watchee_status_name)
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

  def closed_loop_stable?(status_name)
    @closed_loop_output[status_name][2]
  end

  def propagate_closed_loop_status(watched_status)
    @closed_loop_watch.each {|status_name, (watchee_device_name, watchee_status_name)|
      if watched_status.has_key?(watchee_device_name) && watched_status[watchee_device_name][watchee_status_name]
        input_tuple = watched_status[watchee_device_name][watchee_status_name]
        output_tuple = @closed_loop_output[status_name]
        if input_tuple != output_tuple
          input_value, = input_tuple
          output_value, = output_tuple
          if input_value == output_value
            @closed_loop_output[status_name] = input_tuple
            modify_status(status_name, @closed_loop_output[status_name])
          end
        end
      end
    }
  end

end


