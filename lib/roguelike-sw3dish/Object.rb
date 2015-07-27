class Object
    attr_accessor :x, :y, :char, :name, :color, :blocks, :fighter, :ai, :item

    def initialize(
        x,
        y,
        char,
        name,
        color,
        blocks: false,
        fighter: nil,
        ai: nil,
        item: nil
    )
        @x = x
        @y = y
        @char = char
        @name = name
        @color = color
        @blocks = blocks
        @fighter = fighter
        if not @fighter.nil?
            @fighter.owner = self
        end
        @ai = ai
        if not @ai.nil?
            @ai.owner = self
        end
        @item = item
        if not @item.nil?
            @item.owner = self
        end
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

    def send_to_back
        $objects.delete(self)
        $objects.insert(0, self)
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

    def move_towards(target_x, target_y)
        # vector from this object to the target, and distance
        dx = target_x - @x
        dy = target_y - @y
        distance = Math.sqrt(dx ** 2 + dy ** 2)

        # normalize it to length 1 (preserving direction), then round it and
        # convert to integer so the movement is restricted to the map grid
        dx = (dx / distance).round
        dy = (dy / distance).round
        move(dx, dy)
    end

    def distance_to(other)
        # return the distance to another object
        dx = other.x - @x
        dy = other.y - @y
        Math.sqrt(dx ** 2 + dy ** 2)
    end

    def distance(x, y)
        # return the distance to some coordinates
        return Math.sqrt((x - @x) ** 2 + (y - @y) ** 2)
    end
end
