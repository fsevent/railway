class Railway::Switch < FSEvent::AbstractDevice
  def initizlize(device_name, initial_position, interlocking_name, status_name)
    super(device_name)
    @interlocking_name = interlocking_name
    @status_name = status_name

    # normal position: 1
    # reverse position: 2
    # moving to normal position: -1
    # moving to reverse position: -2
    @current_position = initial_position # should be 1 or 2
    @time_to_finish_moving = nil
  end

  def registered
    define_status("position", @current_position)
    add_watch(@interlocking_name, @status_name)
  end

  def run(watched_status, changed_status)
    if @time_to_finish_moving
      if @framework.current_time < @time_to_finish_moving
        return
      else
        @current_position = -@current_position
        modify_status("position", @current_position)
        @time_to_finish_moving = nil
      end
    end
    if watched_status[@interlocking_name].has_key?(@status_name)
      requested_position = watched_status[@interlocking_name][@status_name]
      @current_position = -requested_position
      modify_status("position", @current_position)
      @time_to_finish_moving = @framework.current_time + 5
      @schedule.merge_schedule [@time_to_finish_moving]
    end
    set_elapsed_time(0)
  end
end
