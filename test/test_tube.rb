# test_tube.rb --- unit test for tube.
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

require 'test/unit'
require 'pp'

module Railway
end

require 'railway/tube'

class TestRailwayTube < Test::Unit::TestCase
  def assert_interfere(tube1, tube2, message=nil)
    tube1x = Railway::Tube.new(tube1.pos2, tube1.pos1, tube1.radius)
    tube2x = Railway::Tube.new(tube2.pos2, tube2.pos1, tube2.radius)
    assert_true(tube1.interfere?(tube2), message)
    assert_true(tube2.interfere?(tube1), message)
    assert_true(tube1.interfere?(tube2x), message)
    assert_true(tube2.interfere?(tube1x), message)
    assert_true(tube1x.interfere?(tube2), message)
    assert_true(tube2x.interfere?(tube1), message)
    assert_true(tube1x.interfere?(tube2x), message)
    assert_true(tube2x.interfere?(tube1x), message)
  end

  def assert_not_interfere(tube1, tube2, message=nil)
    tube1x = Railway::Tube.new(tube1.pos2, tube1.pos1, tube1.radius)
    tube2x = Railway::Tube.new(tube2.pos2, tube2.pos1, tube2.radius)
    assert_false(tube1.interfere?(tube2), message)
    assert_false(tube2.interfere?(tube1), message)
    assert_false(tube1.interfere?(tube2x), message)
    assert_false(tube2.interfere?(tube1x), message)
    assert_false(tube1x.interfere?(tube2), message)
    assert_false(tube2x.interfere?(tube1), message)
    assert_false(tube1x.interfere?(tube2x), message)
    assert_false(tube2x.interfere?(tube1x), message)
  end

  def test_interfere_bounding_box
    tube1 = Railway::Tube.new(Vector[0,0,0], Vector[10,0,0], 1)
    tube2 = Railway::Tube.new(Vector[20,0,0], Vector[30,0,0], 1)
    assert_not_interfere(tube1, tube2)
  end

  def test_interfere_connected
    tube1 = Railway::Tube.new(Vector[0,0,0], Vector[10,0,0], 1)
    tube2 = Railway::Tube.new(Vector[10,0,0], Vector[30,0,0], 1)
    assert_interfere(tube1, tube2)
  end

  def test_interfere_parallel_far
    tube1 = Railway::Tube.new(Vector[0,0,0], Vector[10,10,0], 1)
    tube2 = Railway::Tube.new(Vector[5,8,0], Vector[15,18,0], 1)
    assert_not_interfere(tube1, tube2)
  end

  def test_interfere_parallel_near_parallelogram
    tube1 = Railway::Tube.new(Vector[0,0,0], Vector[10,10,0], 2)
    tube2 = Railway::Tube.new(Vector[5,8,0], Vector[15,18,0], 2)
    assert_interfere(tube1, tube2)
  end

  def test_interfere_parallel_near_trapezoid
    tube1 = Railway::Tube.new(Vector[0,0,0], Vector[10,10,0], 2)
    tube2 = Railway::Tube.new(Vector[-15,-12,0], Vector[15,18,0], 2)
    assert_interfere(tube1, tube2)
  end

  def test_interfere_collinear
    tube1 = Railway::Tube.new(Vector[0,0,0], Vector[10,10,0], 5)
    tube2 = Railway::Tube.new(Vector[18,18,0], Vector[30,30,0], 5)
    assert_not_interfere(tube1, tube2)
  end

  def test_nearest_point_far
    tube1 = Railway::Tube.new(Vector[0,0,0], Vector[10,10,0], 1)
    tube2 = Railway::Tube.new(Vector[2,8,-10], Vector[2,8,10], 1)
    assert_not_interfere(tube1, tube2)
  end

  def test_nearest_point_near
    tube1 = Railway::Tube.new(Vector[0,0,0], Vector[10,10,0], 1)
    tube2 = Railway::Tube.new(Vector[5,5,-10], Vector[5,5,10], 1)
    assert_interfere(tube1, tube2)
  end

  def test_nearest_point_near_but_out_of_bound_half
    tube1 = Railway::Tube.new(Vector[0,0,0], Vector[10,10,0], 1)
    tube2 = Railway::Tube.new(Vector[5,5,1], Vector[5,5,10], 1)
    assert_interfere(tube1, tube2)
  end

  def test_nearest_point_far_out_of_bound_both
    tube1 = Railway::Tube.new(Vector[0,0,0], Vector[10,10,0], 2)
    tube2 = Railway::Tube.new(Vector[13,13,2], Vector[13,13,10], 2)
    assert_not_interfere(tube1, tube2)
  end


end

