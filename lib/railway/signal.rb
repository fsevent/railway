class Railway::Signal < FSEvent::AbstractDevice
  def initizlize(device_name, interlocking_name, status_name)
    super(device_name)
    @interlocking_name = interlocking_name
    @status_name = status_name

    # red: 0
    # green: 1
    @current_signal = 0
  end

  def registered
    define_status("signal", @current_signal)
    add_watch(@interlocking_name, @status_name)
  end

  def run(watched_status, changed_status)
    if watched_status[@interlocking_name].has_key?(@status_name)
      @current_signal = watched_status[@interlocking_name][@status_name]
      status_changed("signal", @current_signal)
    end
    set_elapsed_time(0.1)
  end
end
