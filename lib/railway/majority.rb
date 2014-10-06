class Railway::Majority < FSEvent::AbstractDevice
  def initialize(device_name, status_name, input_device_names, count_status_name=nil)
    super device_name
    @status_name = status_name
    if input_device_names.length < 2
      raise "Not enough input devices for #{device_name}"
    end
    @input_device_names_original = input_device_names
    @input_device_names = input_device_names.dup
    @minimum_num_devices = 2
    @count_status_name = count_status_name
    @count_mismatch_max = 2 # second
    @soundness = nil
  end

  def registered
    @output = [:init, nil, nil]
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

  def check_count(watched_status, changed_status)
    if @input_device_names.any? {|input_device_name| !watched_status.has_key?(input_device_name) ||
                                                          !watched_status[input_device_name].has_key?(@count_status_name) ||
                                                          watched_status[input_device_name][@count_status_name] == nil }
      return
    end
    if @input_device_names.map {|input_device_name| watched_status[input_device_name][@count_status_name] }.uniq.length == 1
      @count_mismatch_limit = nil
      return @input_device_names
    end
    if !@count_mismatch_limit
      @count_mismatch_limit = @framework.current_time + @count_mismatch_max
      @schedule.merge_schedule [@count_mismatch_limit]
      return
    elsif @framework.current_time < @count_mismatch_limit
      return
    end
    count_hash = {}
    @input_device_names.each {|input_device_name|
      count = watched_status[input_device_name][@count_status_name]
      count_hash[count] ||= []
      count_hash[count] << input_device_name
    }
    count_list = count_hash.to_a.sort_by {|count, devices| devices.length }
    if 2 < count_list.length
      broken_devices = count_list[0...-2].map {|count, devices| devices }.flatten
      @input_device_names -= broken_devices
      count_list[0...-2] = []
    end
    if @input_devce_names.length < 2
      soundness = false
      if @soundness != soundness
        modify_status("soundness", soundness)
        @soundness = soundness
      end
      return
    end
    if count_list.length == 2
      (count1, count1_devices), (count2, count2_devices) = count_list
      if count1_devices.length == count2_devices.length
        if count1 > count2
          # prefer larger count.
          count1, count1_devices, count2, count2_devices = count2, count2_devices, count1, count1_devices
        end
      end
    end
    (max_count, max_count_devices) = count_list.last
    unless 2 <= max_count_devices.length
      return
    end
    return max_count_devices
  end

  def check_value(input_device_names, watched_status, changed_status)
    if @input_device_names.any? {|input_device_name| !watched_status.has_key?(input_device_name) ||
                                                     !watched_status[input_device_name].has_key?(@status_name) ||
                                                     watched_status[input_device_name][@status_name] == nil }
      return
    end
    value_hash = {}
    input_device_names.each {|input_device_name|
      value = watched_status[input_device_name][@status_name][0]
      value_hash[value] ||= []
      value_hash[value] << input_device_name
    }
    value_list = value_hash.to_a.sort_by {|value, devices| devices.length }
    if 2 < value_list.length
      broken_devices = value_list[0...-2].map {|value, devices| devices }.flatten
      @input_device_names -= broken_devices
      value_list[0...-2] = []
    end
    if @input_device_names.length < 2
      soundness = false
      if @soundness != soundness
        modify_status("soundness", soundness)
        @soundness = soundness
      end
      return
    end
    if value_list.length == 2
      (value1, value1_devices), (value2, value2_devices) = value_list
      unless value1_devices.length < value2_devices.length
        return
      end
      value_list.shift
    end
    (value1, value1_devices), = value_list
    unless 2 <= value1_devices.length
      return
    end
    return value1_devices
  end

  def run(watched_status, changed_status)
    if @count_status_name
      input_device_names = check_count(watched_status, changed_status)
      if !input_device_names
        return
      end
    else
      input_device_names = @input_device_names
    end
    input_device_names = check_value(input_device_names, watched_status, changed_status)
    if !input_device_names
      return
    end
    output = watched_status[input_device_names.first][@status_name]
    if output != @output
      @output = output
      modify_status(@status_name, @output)
    end
  end
end

