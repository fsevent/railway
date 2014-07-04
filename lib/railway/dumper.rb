class Railway::Dumper < FSEvent::AbstractDevice
  def initialize(device_name="railwaydumper")
    super
  end

  def registered
    add_watch("*", "*")
  end

  def run(watched_status, changed_status)
    #pp watched_status
    route = {}
    switch = []
    train = []
    watched_status.each {|device_name, h|
      next if @name == device_name
      case device_name
      when "panel"
        h.each {|status_name, value|
          if /\Ar/ =~ status_name
            route[status_name] ||= []
            route[status_name][1] = value ? 1 : 0
          end
        }
      when /\Ar/
        route[device_name] ||= []
        route[device_name][0] = h["signal"]
      when /\As/
        switch << [device_name, h["position"]]
      when /\Atrain/
        position = h["position"]
        if !position.empty?
          train << [device_name, position[0][0], position[-1][1]]
        end
      end
    }
    #p route
    switch.sort!
    train.sort!
    str = @framework.current_time.to_s
    route.keys.sort.each {|route_name|
      signal, lever = route[route_name]
      if signal == lever
        str << " #{route_name}:#{signal}"
      else
        str << " #{route_name}:#{signal}(#{lever})"
      end
    }
    switch.each {|device_name, position| str << " #{device_name}:#{position}" }
    train.each {|device_name, pos1, pos2| str << " #{device_name}:#{pos1}-#{pos2}" }
    puts str
    set_elapsed_time(0)
  end
end
