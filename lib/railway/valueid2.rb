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
    add_watch @src_device_name, @status_name, :immediate
  end

  def run(watched_status, changed_status)
    if watched_status.has_key?(@src_device_name) && watched_status[@src_device_name].has_key?(@status_name)
      value, id, stable = watched_status[@src_device_name][@status_name]
      if !@defined
        @id += 1
        define_status(@status_name, [value, @id, false])
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
        undefine_status(@status_name)
        @defined = false
        @old_value = nil
      end
    end
  end
end

