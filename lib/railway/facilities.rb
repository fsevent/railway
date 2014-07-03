class Railway::Facilities
  def initialize
    @node = {} # node -> [rail, ...]
    @railtype = {} # rail -> :track | :switch
    @track = {} # track -> [node, node, len]
    @switch = {} # switch -> [trunk_node, [branch1_node, branch1_len], [branch2_node, branch2_len]]
    @circuit = {} # segment -> circuit
                  # segment = [n1,n2,track] | [n1,n2,switch]
    @route = {} # signal -> [approach_circuits, route_segments]
    @area = {} # segment -> [area, ...]
  end
  attr_reader :node, :railtype, :track, :switch, :circuit, :route, :area

  def add_track(track, n1, n2, len)
    if @railtype.has_key? track
      raise "rail already defined: #{track}"
    end
    @railtype[track] = :track
    @track[track] = [n1, n2, len]
    [n1, n2].each {|n|
      @node[n] ||= []
      @node[n] << track
    }
  end

  def add_switch(switch, trunk_node, branch1_node_len, branch2_node_len)
    if @railtype.has_key? switch
      raise "rail already defined: #{switch}"
    end
    branch1_node, branch1_len = branch1_node_len
    branch2_node, branch2_len = branch2_node_len
    @railtype[switch] = :switch
    @switch[switch] = [trunk_node, branch1_node_len, branch2_node_len]
    [trunk_node, branch1_node, branch2_node].each {|n|
      @node[n] ||= []
      @node[n] << switch
    }
  end

  def add_circuit(circuit, *elts)
    if @circuit.has_key? circuit
      raise "circuit already defined: #{circuit}"
    end
    elts.each {|elt|
      @circuit[elt] = circuit
    }
  end

  def add_route(signal, *segments)
    if @route.has_key? signal
      raise "route already defined: #{signal}"
    end
    @route[signal] = segments
  end

  def segment_len(segment)
    n1, n2, rail = segment
    case @railtype[rail]
    when :track
      track_n1, track_n2, track_len = @track[rail]
      unless [[track_n1, track_n2],
              [track_n2, track_n1]].include? [n1, n2]
        raise "invalid track segment: #{rail} : #{n1} #{n2}"
      end
      return track_len
    when :switch
      trunk_node, branch1_node_len, branch2_node_len = @switch[rail]
      branch1_node, branch1_len = branch1_node_len
      branch2_node, branch2_len = branch2_node_len
      unless [[trunk_node, branch1_node],
              [trunk_node, branch2_node],
              [branch1_node, trunk_node],
              [branch2_node, trunk_node]].include? [n1, n2]
        raise "invalid switch segment: #{rail} : #{n1} #{n2}"
      end
      if n1 == trunk_node
        return n2 == branch1_node ? branch1_len : branch2_len
      else
        return n1 == branch1_node ? branch1_len : branch2_len
      end
    else
      raise "unexpected rail type: #{@railtype[rail]} for #{rail}"
    end
  end

  def route_len(segments)
    len = 0
    segments.each {|s|
      len += segment_len(s)
    }
    len
  end

  def switch_position(switch, n1, n2)
    trunk_node, branch1_node_len, branch2_node_len = @switch[switch]
    branch1_node, branch1_len = branch1_node_len
    branch2_node, branch2_len = branch2_node_len
    if [[trunk_node, branch1_node],
        [branch1_node, trunk_node]].include? [n1,n2]
      return 1
    elsif [[trunk_node, branch2_node],
           [branch2_node, trunk_node]].include? [n1, n2]
      return 2
    else
      raise "invalid switch segment: #{rail} : #{n1} #{n2}"
    end
  end
end
