class ConfusedMonster
    attr_accessor :owner, :old_ai, :num_turns
    # AI for a temporarily confused monster (reverts to previous AI after a while)
    def initialize(old_ai, num_turns = CONFUSE_NUM_TURNS)
        @old_ai = old_ai
        @num_turns = num_turns
    end

    def take_turn
        if @num_turns > 0
            # move in a random direction
            @owner.move(
                TCOD.random_get_int(nil, -1, 1),
                TCOD.random_get_int(nil, -1, 1)
            )
            @num_turns -= 1
        else
            @owner.ai = old_ai
            message("The #{@owner.name} is no longer confused!", TCOD::Color::RED)
        end
    end
end
