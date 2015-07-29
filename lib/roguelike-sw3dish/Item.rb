class Item
    attr_accessor :owner, :use_function

    def initialize(use_function: nil)
        @use_function = use_function
    end

    # an item that can be picked up and used.
    def pick_up
        # add to the player's inventory and remove from the map
        if $inventory.length >= 26
            message(
                "Your inventory is full, cannot pick up #{@owner.name}.",
                TCOD::Color::RED
            )
        else
            $inventory.push(@owner)
            $objects.delete(@owner)
            message("You picked up a #{@owner.name}!", TCOD::Color::GREEN)
        end
    end

    def use
        # just call the "use_function" if it is defined
        if @use_function.nil?
            message("The #{@owner.name} cannot be used.")
        else
            if @use_function.call != 'cancelled'
                $inventory.delete(@owner)
            end
        end
    end

    def drop
        # add to the map and remove from the inventory
        # also, place it at the player's coordinates
        $objects.push(@owner)
        $inventory.delete(@owner)
        @owner.x = $player.x
        @owner.y = $player.y
        message("You dropped a #{@owner.name}.", TCOD::Color::YELLOW)
    end
end
