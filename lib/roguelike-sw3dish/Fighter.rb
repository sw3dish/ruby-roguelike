class Fighter < Object
    attr_accessor :max_hp, :hp, :defense, :power
    
    def initialize(x, y, char, name, color, blocks, hp, defense, power)
        super(x, y, char, name, color, blocks)
        @max_hp = hp
        @hp = hp
        @defense = defense
        @power = power
    end
end
