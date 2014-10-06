class FSEvent::ValueIdDevice2 < FSEvent::AbstractDevice
  def initialize(device_name, src_device_name, status_name)
    super device_name
    @src_device_name = src_device_name
    @status_name = status_name
    @defined = false
    @old_value = nil
    @id = 0
  end

  def registered
    define_status(@status_name, [:init, nil, nil])
    add_watch @src_device_name, @status_name, :immediate
  end

  def run(watched_status, changed_status)
    if watched_status.has_key?(@src_device_name) && watched_status[@src_device_name].has_key?(@status_name)
      value, id, stable = watched_status[@src_device_name][@status_name]
      if !@defined
        @id += 1
        modify_status(@status_name, [value, @id, false])
        @defined = true
        @old_value = value
      else
        if @old_value != value
          @id += 1
          modify_status(@status_name, [value, @id, false])
          @old_value = value
        elsif id == @id
          modify_status(@status_name, [value, @id, true])
        end
      end
    else
      if @defined
        @id += 1
        @defined = false
        @old_value = nil
        modify_status(@status_name, [:broken, @id, true])
      end
    end
  end

  module ClosedLoopStatus
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
end

