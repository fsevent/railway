class Railway::SignalCmp < FSEvent::AbstractDevice
  def initialize(device_name, status_name, input_device_names, count_status_name=nil)
    super device_name
    @status_name = status_name
    @input_device_names = input_device_names
    if input_device_names.empty?
      raise "no input devices for #{device_name}"
    end
    @count_status_name = count_status_name
    @count_mismatch_max = 2 # second
    @soundness = nil
  end

  def registered
    @output = [0, nil, nil]
    define_status(@status_name, @output)
    @input_device_names.each {|input_device_name|
      add_watch(input_device_name, @status_name)
      if @count_status_name
        add_watch(input_device_name, @count_status_name)
      end
    }
    @count_mismatch_limit = @framework.current_time + @count_mismatch_max
    define_status("soundness", @soundness)
  end

  def run(watched_status, changed_status)
    if @count_status_name
      if @input_device_names.any? {|input_device_name| !watched_status.has_key?(input_device_name) ||
                                                       !watched_status[input_device_name].has_key?(@count_status_name) ||
                                                       watched_status[input_device_name][@count_status_name] == nil }
        return
      end
      if @input_device_names.map {|input_device_name| watched_status[input_device_name][@count_status_name] }.uniq.length == 1
        @count_mismatch_limit = nil
      else
        if !@count_mismatch_limit
          @count_mismatch_limit = @framework.current_time + @count_mismatch_max
        elsif @count_mismatch_limit < @framework.current_time
          soundness = false
          if @soundness != soundness
            modify_status("soundness", soundness)
            @soundness = soundness
          end
        end
        return # count mismatch.
      end
    end
    if @input_device_names.all? {|input_device_name| watched_status.has_key?(input_device_name) && watched_status[input_device_name][@status_name] }
      # 0(stop) is safer than 1(proceed).
      safest_input_device = @input_device_names.min_by {|input_device_name| watched_status[input_device_name][@status_name][0] }
      output = watched_status[safest_input_device][@status_name]
      if output != @output
        @output = output
        modify_status(@status_name, @output)
      end
      unanimous = @input_device_names.map {|input_device_name| watched_status[input_device_name][@status_name][0] }.uniq.length == 1
      if unanimous
        soundness = true
      else
        soundness = false
      end
      if @soundness != soundness
        modify_status("soundness", soundness)
        @soundness = soundness
      end
    end
  end
end

