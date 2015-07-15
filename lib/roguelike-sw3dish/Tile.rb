class Tile
    attr_accessor :blocked, :block_sight
    def initialize(blocked, block_sight = nil)
        @blocked = blocked

        if block_sight.nil?
            @block_sight = blocked
        else
            @block_sight = block_sight
        end
    end
end
