class Railway::FixedSignal < FSEvent::AbstractDevice
  def initialize(device_name, interlocking_name, status_name)
    super(device_name)
    @interlocking_name = interlocking_name
    @status_name = status_name

    # stop (red): 0
    # proceed (green): 1
    @current_signal = [0, nil, nil]
  end

  def registered
    define_status(@name, @current_signal)
    add_watch(@interlocking_name, @status_name)
  end

  def run(watched_status, changed_status)
    if watched_status[@interlocking_name].has_key?(@status_name)
      if @current_signal != watched_status[@interlocking_name][@status_name]
        if watched_status[@interlocking_name][@status_name] == nil ||
           watched_status[@interlocking_name][@status_name][0] == :init
           watched_status[@interlocking_name][@status_name][0] == :broken
          @current_signal = [0, nil, nil]
        else
          @current_signal = watched_status[@interlocking_name][@status_name]
        end
        modify_status(@name, @current_signal)
      end
    end
    set_elapsed_time(0.1)
  end
end
