class Fighter
    attr_accessor :owner, :max_hp, :hp, :defense, :power, :death_function

    def initialize(hp, defense, power, death_function = nil)
        @max_hp = hp
        @hp = hp
        @defense = defense
        @power = power
        @death_function = death_function
    end

    def take_damage(damage)
        if damage > 0
            @hp -= damage
        end

        if @hp <= 0
            if not @death_function.nil?
                @death_function.call(self.owner)
            end
        end
    end

    def attack(target)
        damage = @power - target.fighter.defense

        if damage > 0
            puts self.owner.name.capitalize + ' attacks ' + target.name + \
            ' for ' + damage.to_s + ' hit points.'
            target.fighter.take_damage(damage)
        else
            puts self.owner.name.capitalize + ' attacks ' + target.name + \
                ' but it has no effect!'
        end
    end
end
