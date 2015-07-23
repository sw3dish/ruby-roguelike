class Item
    attr_accessor :owner, :death_function

    def initialize(
            use_function: nil
    )
        @use_function = use_function
    end

    # an item that can be picked up and used.
    def pick_up
        # add to the player's inventory and remove from the map
        if $inventory.length >= 26
            message(
                'Your inventory is full, cannot pick up ' + \
                @owner.name + '.',
                TCOD::Color::RED
            )
        else
            $inventory.push(@owner)
            $objects.delete(@owner)
            message('You picked up a ' + @owner.name + '!', TCOD::Color::GREEN)
        end
    end

    def use
        # just call the "use_function" if it is defined
        if @use_function.nil?
            message('The ' @owner.name + ' cannot be used.')
        else
            if @use_function != 'cancelled'
                $inventory.delete(@owner)
            end
        end
    end
end
