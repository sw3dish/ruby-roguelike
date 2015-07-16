class Object
    attr_accessor :x, :y, :char, :name, :color, :blocks

    def initialize(x, y, char, name, color, blocks = false)
        @x = x
        @y = y
        @char = char
        @name = name
        @color = color
        @blocks = blocks
    end

    def move(dx, dy)
        if not is_blocked(@x + dx, @y + dy)

            @x += dx
            @y += dy
        end
    end

    def draw
        #only show if it's visible to the $player
        if TCOD.map_is_in_fov($fov_map, @x, @y)
            #set color, then draw the character that represents this object at its position
            TCOD.console_set_default_foreground($con, @color)
            TCOD.console_put_char($con, @x, @y, @char.ord, TCOD::BKGND_NONE)
        end
    end

    def clear
        #erase the character that represents this object
        TCOD.console_put_char($con, @x, @y, ' '.ord, TCOD::BKGND_NONE)
    end

    def is_blocked(x, y)
        # first test the map tile
        if $map[x][y].blocked
            return true
        end
        # now check for any blocking objects
        $objects.each do |object|
            if object.blocks && object.x == x && object.y == y
                return true
            end
        end

        false
    end
end
