class Item
    attr_accessor :owner

    def initialize
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
end
