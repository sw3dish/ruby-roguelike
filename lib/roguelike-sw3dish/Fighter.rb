class Fighter
    attr_accessor :owner, :max_hp, :hp, :defense, :power

    def initialize(hp, defense, power)
        @max_hp = hp
        @hp = hp
        @defense = defense
        @power = power
    end
end
