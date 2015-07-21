class BasicMonster
    attr_accessor :owner

    def initialize
    end

    def take_turn
        monster = @owner
        if TCOD.map_is_in_fov($fov_map, monster.x, monster.y)

            # move towards player if far away
            if monster.distance_to($player) >= 2
                monster.move_towards($player.x, $player.y)
            elsif $player.fighter.hp > 0
                monster.fighter.attack($player)
            end
        end
    end
end
