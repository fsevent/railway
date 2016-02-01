# partstate.rb -- state of a part

class Railway::PartState

  def initialize(part_name, state)
    @part_name = part_name
    @state = state
  end
  attr_reader :part_name, :state

  def inspect
  "\#<#{self.class}: #{@part_name} #{@state}>"
  end

  def interlocking_status
    [[@part_name, @state]]
  end

  def part_states
    [[@part_name, @part_name, @state]]
  end

  def lockable?(watched_status)
    watched_status[@part_name][@part_name] == @state
  end

  def interfere?(res)
    @part_name == res.part_name && @state != res.state
  end

  def requestable?
    true
  end
end

