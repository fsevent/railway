class Railway::Panel < FSEvent::AbstractDevice
  def initialize(device_name, facilities, plan)
    super device_name
    @facilities = facilities
    @plan = plan.sort
    @next_action = nil
  end

  def registered
    @facilities.each_route_name {|route_name|
      define_status(route_name, false)
    }
    set_elapsed_time(0)
    set_next_schedule
  end

  def run(watched_status, changed_status)
    while !@plan.empty? && @plan.first[0] <= @framework.current_time
      _t, status_name, value = @plan.shift
      modify_status(status_name, value)
    end
    set_next_schedule
  end

  def set_next_schedule
    unless @plan.empty?
      t, _status_name, _value = @plan.first
      @schedule.merge_schedule [t]
    end
  end
end


