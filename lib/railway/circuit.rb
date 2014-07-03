class Railway::Circuit < FSEvent::AbstractDevice # Track circuit
  def initialize(device_name, facilities)
    super(device_name)
    @facilities = facilities
    @train_positions = {} # train_name -> [segment, ...]
    @circuit_status = {} # circuit_name -> [train_name, ...]
  end

  def registered
    @facilities.circuit.each {|rail, circuit_name|
      @circuit_status[circuit_name] = []
    }
    @circuit_status.each_key {|circuit_name|
      define_status(circuit_name, false)
    }
    add_watch("train*", "position")
  end

  def run(watched_status, changed_status)
    old_status = {}
    changed_status.each {|train_name, _|
      if @train_positions.has_key? train_name
        old_segments = @train_positions[train_name]
      else
        old_segments = []
      end
      if watched_status.has_key? train_name
        new_segments = watched_status[train_name]["position"]
      else
        new_segments = []
      end
      (old_segments - new_segments).each {|segment|
        if circuit = @facilities.circuit[segment]
          unless @circuit_status[circuit].include? train_name
            raise "@circuit_status[#{circuit.inspect}] doesn't include #{train_name.inspect}"
          end
          unless old_status.has_key? circuit
            old_status[circuit] = @circuit_status[circuit].dup
          end
          @circuit_status[circuit].delete train_name
        end
      }
      (new_segments - old_segments).each {|segment|
        if circuit = @facilities.circuit[segment]
          unless old_status.has_key? circuit
            old_status[circuit] = @circuit_status[circuit].dup
          end
          @circuit_status[circuit] << train_name
        end
      }
      @train_positions[train_name] = new_segments.dup
    }
    old_status.each {|circuit, old|
      if @circuit_status[circuit] != old
        modify_status(circuit, !@circuit_status[circuit].empty?)
      end
      if 1 < @circuit_status[circuit].length
        # xxx: notify collision without exit application
        raise "train collision: #{@circuit_status[circuit].inspect}"
      end
    }
    set_elapsed_time(0)
  end
end
