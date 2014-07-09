class Railway::Train < FSEvent::AbstractDevice
  def initialize(device_name, train_len, plan, facilities)
    super(device_name)

    @plan = plan.dup # [route1, route2, ...]
    @train_len = train_len
    @facilities = facilities
    @current_position = []
    @rails_until_next_route = [] # [segment, ...]
  end

  def registered
    super
    define_status("position", @current_position)
    if !@plan.empty?
      next_route = @plan.first
      add_watch_route(next_route)
      @schedule.merge_schedule FSEvent::PeriodicSchedule.new(@framework.current_time+2, 2)
    end
  end

  def run(watched_status, changed_status)
    #p [@framework.current_time, @current_position, watched_status, changed_status]
    #p [@framework.current_time, @name, @current_position, watched_status]
    if @rails_until_next_route.empty?
      if @plan.empty?
        if !@current_position.empty?
          clear_rear @facilities.route_len(@current_position[1..-1])
          modify_status "position", @current_position.dup
        else
          @schedule = []
        end
        return
      end
      next_route = @plan.first
      signal_device = @facilities.route_to_signal(next_route)
      if !watched_status.has_key?(signal_device) ||
         !watched_status[signal_device].has_key?(signal_device)
        return
      end
      signal = watched_status[signal_device][signal_device][0] # the value element of value-id-stable tuple.
      if signal == 0
        clear_rear
        modify_status "position", @current_position.dup
        return
      end
      @rails_until_next_route = @facilities.route_segments[next_route].dup
      del_watch_signal(@facilities.route_to_signal(next_route))
      @plan.shift
      if !@plan.empty?
        next_route = @plan.first
        add_watch_route(next_route)
      end
    end
    if front_reach_to_next_position?
      advance_front @rails_until_next_route.shift
      check_derailments(watched_status)
    else
      check_derailments(watched_status)
      clear_rear
    end
    modify_status "position", @current_position.dup
    set_elapsed_time(1)
  end

  def front_reach_to_next_position?
    return true if @current_position.empty?
    len = 0 # length without the last segment.
    @current_position[1..-1].each {|segment|
      len += @facilities.segment_len(segment)
    }
    return len <= @train_len
  end

  def check_derailments(watched_status)
    @current_position.each {|segment|
      n1, n2, rail = segment
      case @facilities.railtype[rail]
      when :track
        # no moving parts for a track.
      when :point
        unless watched_status.has_key? rail
          raise "no point device defined: point #{rail}"
        end
        unless watched_status[rail].has_key? rail
          raise "no point position status defined: point #{rail}"
        end
        expected_point_position = @facilities.point_position(rail, n1, n2)
        current_point_position = watched_status[rail][rail][0] # the value element of value-id-stable tuple.
        if current_point_position != expected_point_position
          raise "derailment occur: #{rail} should be position #{expected_point_position} but #{current_point_position}"
        end
      else
        raise "unexpected rail type #{@facilities.railtype[rail].inspect} for #{rail.inspect}"
      end
    }
  end

  def advance_front(segment)
    n1, n2, rail = segment
    @current_position << segment
  end

  def clear_rear(train_len=@train_len)
    len = 0
    current_position = []
    @current_position.reverse_each {|segment|
      if len < train_len
        current_position.unshift segment
      else
        _n1, _n2, rail = segment
        del_watch_segment(segment)
      end
      len += @facilities.segment_len(segment)
    }
    @current_position = current_position
  end

  def add_watch_route(route)
    signal = @facilities.route_to_signal(route)
    add_watch(signal, signal, :schedule)
    @facilities.route_segments[route].each {|segment|
      n1, n2, rail = segment
      case @facilities.railtype[rail]
      when :track
        # no moving parts for a track.
      when :point
        add_watch(rail, rail, :immediate) # :immediate to detect derailments immediately.
      else
        raise "unexpected rail type #{@facilities.railtype[rail].inspect} for #{rail.inspect}"
      end
    }
  end

  def del_watch_signal(signal)
    del_watch(signal, signal)
  end

  def del_watch_segment(segment)
    n1, n2, rail = segment
    case @facilities.railtype[rail]
    when :track
      # no moving parts for a track.
    when :point
      del_watch(rail, rail)
    else
      raise "unexpected rail type #{@facilities.railtype[rail].inspect} for #{rail.inspect}"
    end
  end

end
