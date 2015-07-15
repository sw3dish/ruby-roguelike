class Object
    attr_accessor :x, :y, :char, :color

    def initialize(x, y, char, color)
        @x = x
        @y = y
        @char = char
        @color = color
    end

    def move(dx, dy)
        if not $map[@x + dx][@y + dy].blocked
            @x += dx
            @y += dy
        end
    end

    def draw
        #set color, then draw the character that represents this object at its position
        TCOD.console_set_default_foreground($con, @color)
        TCOD.console_put_char($con, @x, @y, @char.ord, TCOD::BKGND_NONE)
    end

    def clear
        #erase the character that represents this object
        TCOD.console_put_char($con, @x, @y, ' '.ord, TCOD::BKGND_NONE)
    end
end
