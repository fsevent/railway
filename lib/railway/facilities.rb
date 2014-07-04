class Railway::Facilities
  def initialize
    @node = {} # node -> [rail, ...]
    @railtype = {} # rail -> :track | :point
    @track = {} # track -> [node, node, len]
    @point = {} # point -> [trunk_node, [branch1_node, branch1_len], [branch2_node, branch2_len]]
    @circuit = {} # segment -> circuit
                  # segment = [n1,n2,track] | [n1,n2,point]
    @route_segments = {} # signal -> route_segments
    @approach_segments = {} # signal -> approach_segments
    @area = {} # segment -> [area, ...]
  end
  attr_reader :node, :railtype, :track, :point, :circuit, :route_segments, :approach_segments, :area

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

  def add_point(point, trunk_node, branch1_node_len, branch2_node_len)
    if @railtype.has_key? point
      raise "rail already defined: #{point}"
    end
    branch1_node, branch1_len = branch1_node_len
    branch2_node, branch2_len = branch2_node_len
    @railtype[point] = :point
    @point[point] = [trunk_node, branch1_node_len, branch2_node_len]
    [trunk_node, branch1_node, branch2_node].each {|n|
      @node[n] ||= []
      @node[n] << point
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

  def add_area(segment, *areas)
    if @area.has_key? segment
      raise "area already defined for segment #{segment}"
    end
    @area[segment] = areas
  end

  def add_route(signal, approach_segments, route_segments)
    if @route_segments.has_key? signal
      raise "route already defined: #{signal}"
    end
    @approach_segments[signal] = approach_segments
    @route_segments[signal] = route_segments
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
    when :point
      trunk_node, branch1_node_len, branch2_node_len = @point[rail]
      branch1_node, branch1_len = branch1_node_len
      branch2_node, branch2_len = branch2_node_len
      unless [[trunk_node, branch1_node],
              [trunk_node, branch2_node],
              [branch1_node, trunk_node],
              [branch2_node, trunk_node]].include? [n1, n2]
        raise "invalid point segment: #{rail} : #{n1} #{n2}"
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

  def point_position(point, n1, n2)
    trunk_node, branch1_node_len, branch2_node_len = @point[point]
    branch1_node, branch1_len = branch1_node_len
    branch2_node, branch2_len = branch2_node_len
    if [[trunk_node, branch1_node],
        [branch1_node, trunk_node]].include? [n1,n2]
      return 1
    elsif [[trunk_node, branch2_node],
           [branch2_node, trunk_node]].include? [n1, n2]
      return 2
    else
      raise "invalid point segment: #{rail} : #{n1} #{n2}"
    end
  end

  def each_track_segment
    @track.each {|track_name, (n1, n2, _len)|
      [ [n1, n2, track_name],
        [n2, n1, track_name] ].each {|segment|
        yield track_name, segment
      }
    }
  end

  def each_point_segment
    @point.each {|point_name, (tn, (bn1, _len1), (bn2, _len2))|
      [ [tn, bn1, point_name],
        [tn, bn2, point_name],
        [bn1, tn, point_name],
        [bn2, tn, point_name] ].each {|segment|
        yield point_name, segment
      }
    }
  end

  def each_segment(&block)
    each_track_segment(&block)
    each_point_segment(&block)
  end

end
