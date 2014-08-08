class Railway::PointCmp < FSEvent::AbstractDevice
  def initialize(device_name, status_name, *input_device_names)
    super device_name
    @status_name = status_name
    @input_device_names = input_device_names
    if input_device_names.empty?
      raise "no input devices for #{device_name}"
    end
    @soundness = false
  end

  def registered
    @output = [nil, nil, nil]
    define_status(@status_name, @output)
    @input_device_names.each {|input_device_name|
      add_watch(input_device_name, @status_name)
    }
    define_status("soundness", @soundness)
  end

  def run(watched_status, changed_status)
    if @input_device_names.all? {|input_device_name| watched_status.has_key?(input_device_name) && watched_status[input_device_name][@status_name] }
      unanimous = @input_device_names.map {|input_device_name| watched_status[input_device_name][@status_name][0] }.uniq.length == 1
      if unanimous
        safest_input_device = @input_device_names[0] # all inputs should be same.
        output = watched_status[safest_input_device][@status_name]
        if output != @output
          @output = output
          modify_status(@status_name, @output)
        end
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

