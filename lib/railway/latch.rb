class Railway::Latch < FSEvent::AbstractDevice
  def initialize(device_name, *inputs)
    super device_name
    @inputs = inputs # [[device_name, status_name], ...]
    status_names = @inputs.map {|device_name, status_name| status_name }
    if status_names.uniq.length != status_names.length
      raise "status_name conflicts"
    end
    @delay = 1 # second
    @count = 0
  end

  def registered
    define_status('count', @count)
    @current_output = {}
    @inputs.each {|device_name, status_name|
      add_watch(device_name, status_name)
      @current_output[status_name] = [:init, nil, nil]
      define_status(status_name, @current_output[status_name])
    }
    @delay_limit = nil
  end

  def run(watched_status, changed_status)
    if !@delay_limit ||  @framework.current_time < @delay_limit
      @inputs.each {|device_name, status_name|
        if watched_status.has_key?(device_name) && watched_status[device_name].has_key?(status_name) &&
           watched_status[device_name][status_name] != @current_output[status_name]
          if @delay_limit == nil
            @delay_limit = @framework.current_time + @delay
            @schedule.merge_schedule [@delay_limit]
          end
        end
      }
    else
      @delay_limit = nil
      @inputs.each {|device_name, status_name|
        if watched_status.has_key?(device_name) && watched_status[device_name].has_key?(status_name)
          v = watched_status[device_name][status_name]
        else
          v = nil
        end
        if @current_output[status_name] != v
          @current_output[status_name] = v
          modify_status(status_name, v)
        end
      }
      @count += 1
      modify_status('count', @count)
    end
  end
end

