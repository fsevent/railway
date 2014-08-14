class Railway::Selector < FSEvent::AbstractDevice
  def initialize(device_name, output_status_names, *inputs)
    super device_name
    @output_status_names = output_status_names
    @inputs = inputs # [[soundness_list, status_list], ...]
                     # soundness_list = [[device_name, status_name], ...]
                     # status_list = [[device_name, status_name], ...]
                     # where output_status_names.length == status_list.length
    @inputs.each {|soundness_list, status_list|
      if output_status_names.length != status_list.length
        raise "number of status unmatch"
      end
    }
    @current = 0
  end

  def registered
    @output_status_names.each {|status_name|
      define_status(status_name, nil)
    }
    @inputs.each {|soundness_list, status_list|
      soundness_list.each {|device_name, status_name|
        add_watch(device_name, status_name)
      }
      status_list.each {|device_name, status_name|
        add_watch(device_name, status_name)
      }
    }
  end

  def run(watched_status, changed_status)
    soundness = []
    @inputs.each_with_index {|(soundness_list, status_list), i|
      s = true
      soundness_list.each {|device_name, status_name|
        return if !watched_status.has_key?(device_name)
        return if !watched_status[device_name].has_key?(status_name)
        return if watched_status[device_name][status_name] == nil
        s &&= watched_status[device_name][status_name]
        break if !s
      }
      soundness[i] = s
    }
    if soundness.any?
      while !soundness[@current]
        @current = (@current + 1) % soundness.length
      end
      soundness_list, status_list = @inputs[@current]
      @output_status_names.each_with_index {|output_status_name, i|
        input_device_name, input_status_name = status_list[i]
        modify_status(output_status_name, watched_status[input_device_name][input_status_name])
      }
    end
  end
end

