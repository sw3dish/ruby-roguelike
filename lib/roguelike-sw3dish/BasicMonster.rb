class BasicMonster
    attr_accessor :owner

    def initialize

    end

    def take_turn
        puts 'The ' + @owner.name + ' growls!'
    end

end
