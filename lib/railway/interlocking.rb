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
      add_watch(point, "position")
    }
    @facilities.point.each_key {|point|
      define_closed_loop_status(point, nil, point, point)
    }
    @facilities.route_segments.each_key {|signal|
      add_watch("panel", signal)
      define_closed_loop_status(signal, 0, signal, signal)
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
      if lever
        if route_allocated?(route, watched_status)
          modify_closed_loop_status(route, 1)
          @route_state[route] = :signaled
        end
      else
        route_unlock(route)
        modify_closed_loop_status(route, 0)
        @route_state[route] = nil
      end
    end
    if @route_state[route] == :signaled
      if lever
        if train_in_route?(route, watched_status)
          @route_state[route] = :entered
          @unlocked_rear_numsegments[route] = 0
          modify_closed_loop_status(route, 0)
        end
      else
        if train_may_enter_route?(route, watched_status)
          modify_closed_loop_status(route, 0)
          @route_state[route] = :wait_approaching_train_stop
          @route_schedule[route] = @framework.current_time + @facilities.approach_timer[route]
          @schedule.merge_schedule [@route_schedule[route]]
        else
          route_unlock(route)
          modify_closed_loop_status(route, 0)
          @route_state[route] = nil
        end
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
    if @route_state[route] == :wait_approaching_train_stop
      if @route_schedule[route] <= @framework.current_time
        route_unlock(route)
        @route_state[route] = nil
        @route_schedule.delete route
      end
    end
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

  def signal_stable_stop?(route, watched_status)
    refer_closed_loop_status(route) == 0 && closed_loop_stable?(route)
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


