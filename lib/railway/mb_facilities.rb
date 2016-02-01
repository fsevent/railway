# facilities.rb --- railway facility management library
#
# Copyright (C) 2014  National Institute of Advanced Industrial Science and Technology (AIST)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'matrix'

class Railway::MbFacilities
  def initialize
    @node_position = {}
    @node = {} # node -> [rail, ...]
    @railtype = {} # rail -> :track | :point
    @track = {} # track -> [node, node, len]
    @point = {} # point -> [trunk_node, branch1_node, branch2_node]
    @circuit = {} # segment -> circuit
                  # segment = [n1,n2,track] | [n1,n2,point]
    @route_segments = {} # signal -> route_segments
    @area = {} # segment -> [area, ...]

    @tube_radius = 3
    @tubes = {} # [n1, n2] -> tube # n1 <= n2
    @partstates = {} # part -> state -> partstate
  end
  attr_reader :node, :railtype, :track, :point, :circuit, :route_segments, :area

  def add_node(n, x, y, z=0.0)
    if @node_position[n]
      raise "node already defined: #{n}"
    end
    @node_position[n] = Vector[x.to_f, y.to_f, z.to_f]
  end

  def add_track(track, n1, n2)
    len = (@node_position[n1] - @node_position[n2]).r
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

  def add_point(point, trunk_node, branch1_node, branch2_node)
    branch1_len = (@node_position[trunk_node] - @node_position[branch1_node]).r
    branch2_len = (@node_position[trunk_node] - @node_position[branch2_node]).r
    branch1_node_len = [branch1_node, branch1_len]
    branch2_node_len = [branch2_node, branch2_len]
    if @railtype.has_key? point
      raise "rail already defined: #{point}"
    end
    @railtype[point] = :point
    @point[point] = [trunk_node, branch1_node_len, branch2_node_len]
    [trunk_node, branch1_node, branch2_node].each {|n|
      @node[n] ||= []
      @node[n] << point
    }
  end

  def roerder_point_nodes_trunk_branch(point, n1, n2)
    if n1 == n2
      raise "same node specified: #{n1}"
    end
    if !@point[point]
      raise "point expected: #{point}"
    end
    trunk_node, branch1_node, branch2_node = @point[point]
    if n1 == trunk_node
      return [n1, n2] if branch1_node == n2
      return [n1, n2] if branch2_node == n2
      raise "unexpected node specified: #{n2}"
    elsif n2 == trunk_node
      return [n2, n1] if branch1_node == n1
      return [n2, n1] if branch2_node == n1
      raise "unexpected node specified: #{n2}"
    end
    raise "trunk node not specified: #{trunk_node}"
  end

  def get_point_trunk_node(point, n1, n2)
    roerder_point_nodes_trunk_branch(point, n1, n2)[0]
  end

  def get_point_branch_node(point, n1, n2)
    roerder_point_nodes_trunk_branch(point, n1, n2)[1]
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

  def add_route(signal, route_segments)
    if @route_segments.has_key? signal
      raise "route already defined: #{signal}"
    end
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

  def get_tube(n1, n2)
    n1, n2 = n2, n1 if n1 > n2
    key = [n1, n2]
    if !@tubes[key]
      @tubes[key] = Railway::Tube.new(@node_position.fetch(n1), @node_position.fetch(n2), @tube_radius, "#{n1}-#{n2}")
    end
    return @tubes[key]
  end

  def get_partstate(part, state)
    @partstates[part] ||= {}
    @partstates[part][state] ||= Railway::PartState.new(part, state)
    return @partstates[part][state]
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

  def each_route_name(&b)
    @route_segments.each_key(&b)
  end

  def route_to_signal(route)
    route.sub(/\Ar/, 's')
  end

  def each_route_and_fixedsignal_name
    each_route_name {|rn|
      yield rn, route_to_signal(rn)
      #yield rn, rn
    }
  end

  def each_fixedsignal_name
    each_route_and_fixedsignal_name {|rn, sn|
      yield sn
    }
  end

end
