# tube.rb --- cylindrical space
#
# Copyright (C) 2015  National Institute of Advanced Industrial Science and Technology (AIST)
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

class Railway::Tube
  # pos1 : Vector of three numbers
  # pos2 : Vector of three numbers
  # radius : positive number
  def initialize(pos1, pos2, radius, comment=nil)
    @pos1 = pos1.map(&:to_f)
    @pos2 = pos2.map(&:to_f)
    @radius = radius.to_f
    @comment = comment
  end
  attr_reader :pos1, :pos2, :radius

  def inspect
    if @comment
      "\#<#{self.class}: #{@comment} [#{@pos1[0]},#{@pos1[1]},#{@pos1[2]}]-[#{@pos2[0]},#{@pos2[1]},#{@pos2[2]}] #{radius}>"
    else
      "\#<#{self.class}: [#{@pos1[0]},#{@pos1[1]},#{@pos1[2]}]-[#{@pos2[0]},#{@pos2[1]},#{@pos2[2]}] #{radius}>"
    end
  end

  def bounding_box
    [@pos1.map2(@pos2) {|*pair| pair.min - @radius },
     @pos1.map2(@pos2) {|*pair| pair.max + @radius }]
  end

  def interfere?(other)
    ap1, ap2, ar = @pos1, @pos2, @radius
    bp1, bp2, br = other.pos1, other.pos2, other.radius

    # doesn't intefere if two bounding box is not interfere.
    amin, amax = self.bounding_box
    bmin, bmax = other.bounding_box
    amax.each2(bmin) {|max, min| return false if max < min }
    bmax.each2(amin) {|max, min| return false if max < min }

    ar_br = ar + br

    # intefere if tip sphere interfere.
    [ap1, ap2].each {|ap|
      [bp1, bp2].each {|bp|
        return true if (ap - bp).r <= ar_br
      }
    }

    av = ap2 - ap1
    bv = bp2 - bp1

    al = av.r
    bl = bv.r

    an = av.normalize
    bn = bv.normalize

    # interfere if the nearest point to a line is near enough.
    # This condition works well for (near) parallel lines.
    da = (an.dot(bp1-ap1))
    return true if 0 < da && da < al && (bp1 - (ap1 + an * da)).r <= ar_br
    da = (an.dot(bp2-ap1))
    return true if 0 < da && da < al && (bp2 - (ap1 + an * da)).r <= ar_br
    db = (bn.dot(ap1-bp1))
    return true if 0 < db && db < bl && (ap1 - (bp1 + bn * db)).r <= ar_br
    db = (bn.dot(ap2-bp1))
    return true if 0 < db && db < bl && (ap2 - (bp1 + bn * db)).r <= ar_br

    # den will be 0 if the two lines are parallel.
    # So, following conditions may not work well for (near) parallel lines.
    anbn = an.dot(bn)
    den = 1 - anbn ** 2

    ap1_bp1 = (ap1 - bp1)
    numa = ap1_bp1.dot(bn) * anbn - ap1_bp1.dot(an)
    numb = -ap1_bp1.dot(an) * anbn + ap1_bp1.dot(bn)

    # the nearest point in ap1 to ap2.  nil if it is outside of ap1 to ap2.
    ap0 = nil
    if 0 < numa && numa < al * den
      da = numa / den
      ap0 = ap1 + an * da
    end

    # the nearest point in bp1 to bp2.  nil if it is outside of bp1 to bp2.
    bp0 = nil
    if 0 < numb && numb < bl * den
      db = numb / den
      bp0 = bp1 + bn * db
    end

    if ap0 && bp0
      # interfere if the nearest points are near enough.
      return true if (ap0 - bp0).r <= ar_br
    end
    if bp0
      # interfere if the nearest point is interfer tip spheres on the other line.
      [ap1, ap2].each {|ap|
        return true if (ap - bp0).r <= ar_br
      }
    end
    if ap0
      # interfere if the nearest point is interfer tip spheres on the other line.
      [bp1, bp2].each {|bp|
        return true if (ap0 - bp).r <= ar_br
      }
    end

    # doesn't interfere otherwise.
    return false
  end

  def interlocking_status
    []
  end

  def part_states
    []
  end

  def lockable?(watched_status)
    true
  end

  def requestable?
    false
  end
end
