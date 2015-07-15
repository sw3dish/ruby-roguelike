#!/usr/bin/env/ruby

require 'libtcod'
require './roguelike-sw3dish/Object'
require './roguelike-sw3dish/Tile'
require './roguelike-sw3dish/Rect'

SCREEN_WIDTH = 80
SCREEN_HEIGHT = 50

MAP_WIDTH = SCREEN_WIDTH
MAP_HEIGHT = SCREEN_HEIGHT

# parameters for dungeon generator
ROOM_MAX_SIZE = 10
ROOM_MIN_SIZE = 6
MAX_ROOMS = 30

FOV_ALGO = 0
FOV_LIGHT_WALLS = true
TORCH_RADIUS = 10

LIMIT_FPS = 20

GROUND_COLOR = TCOD::Color.rgb(77, 60, 41)

def create_room(room)
    #go through the tiles in the rectangle and make them passable
    p "#{room.x1}, #{room.x2}, #{room.y1}, #{room.y2}"
    (room.x1 + 1 ... room.x2).each do |x|
        (room.y1 + 1 ... room.y2).each do |y|
            $map[x][y].blocked = false
            $map[x][y].block_sight = false
        end
    end
end

def create_h_tunnel(x1, x2, y)
    #horizontal tunnel. min() and max() are used in case x1>x2
    ([x1,x2].min ... [x1,x2].max + 1).each do |x|
        $map[x][y].blocked = false
        $map[x][y].block_sight = false
    end
end

def create_v_tunnel(y1, y2, x)
    #vertical tunnel
    ([y1,y2].min ... [y1,y2].max + 1).each do |y|
        $map[x][y].blocked = false
        $map[x][y].block_sight = false
    end
end

def make_map
    $map = []
    0.upto(MAP_WIDTH - 1) do |x|
        $map.push([])
        0.upto(MAP_HEIGHT - 1) do |y|
            $map[x].push(Tile.new(true))
        end
    end

    rooms = []
    num_rooms = 0

    0.upto(MAX_ROOMS) do |r|
        # random width and height
        w = TCOD.random_get_int(nil, ROOM_MIN_SIZE, ROOM_MAX_SIZE)
        h = TCOD.random_get_int(nil, ROOM_MIN_SIZE, ROOM_MAX_SIZE)
        # random position without going out of the boundaries of the $map
        x = TCOD.random_get_int(nil, 0, MAP_WIDTH - w - 1)
        y = TCOD.random_get_int(nil, 0, MAP_HEIGHT - h - 1)

        # "Rect" class makes rectangles easier to work with
        new_room = Rect.new(x, y, w, h)

        # loop through other rooms, see if they intersect with this one
        failed = false
        rooms.each do |other_room|
            if new_room.intersect(other_room)
                failed = true
                break
            end
        end

        unless failed
            # this means there are no intersection, so this room.equal? valid

            # "paint" it to the $map's tiles
            create_room(new_room)

            # center coordinates of new room, will be useful later
            new_x, new_y = new_room.center

            #there's a 30% chance of placin a skeleton slightly off to the center of this room
            if TCOD.random_get_int(nil, 1, 100) <= 30
                skeleton = Object.new(new_x + 1, new_y, 'S', TCOD::Color::LIGHT_YELLOW)
                $objects.push(skeleton)
            end

            if num_rooms == 0
                $player.x = new_x
                $player.y = new_y
            else
                prev_x, prev_y = rooms[num_rooms-1].center()

                if TCOD.random_get_int(nil, 0, 1) == 1
                    #first move horizontally, then vertically
                    create_h_tunnel(prev_x, new_x, prev_y)
                    create_v_tunnel(prev_y, new_y, new_x)
                else
                    #first move vertically, then horizontally
                    create_v_tunnel(prev_y, new_y, prev_x)
                    create_h_tunnel(prev_x, new_x, new_y)
                end
            end

            rooms.push(new_room)
            num_rooms += 1
        end
    end
end



def handle_keys
    key = TCOD.console_wait_for_keypress(true)

    #fullscreen
    if key.vk == TCOD::KEY_ENTER && key.lalt
        TCOD.console_set_fullscreen(!TCOD.console_is_fullscreen())
    #exit game
    elsif key.vk == TCOD:: KEY_ESCAPE
        return true
    end

    #movement keys
    if TCOD.console_is_key_pressed(TCOD::KEY_UP)
        $player.move(0, -1)
        $fov_recompute = true
    elsif TCOD.console_is_key_pressed(TCOD::KEY_DOWN)
        $player.move(0, 1)
        $fov_recompute = true
    elsif TCOD.console_is_key_pressed(TCOD::KEY_LEFT)
        $player.move(-1, 0)
        $fov_recompute = true
    elsif TCOD.console_is_key_pressed(TCOD::KEY_RIGHT)
        $player.move(1, 0)
        $fov_recompute = true
    end
    false

    false
end

def render_all
    if $fov_recompute
        #recompute FOV if needed(the $player moved or something)
        $fov_recompute = false
        TCOD.map_compute_fov($fov_map, $player.x, $player.y, TORCH_RADIUS, FOV_LIGHT_WALLS, FOV_ALGO)

        #go through all tiles, and set their background color according to the FOV
        0.upto(MAP_HEIGHT-1) do |y|
            0.upto(MAP_WIDTH-1) do |x|
                visible = TCOD.map_is_in_fov($fov_map, x, y)
                wall = $map[x][y].block_sight
                if not visible
                    #if it's not visible right now, the $player can only see it if it's explored
                    if $map[x][y].explored
                        if wall
                            TCOD.console_put_char_ex($con, x, y, '#'.ord, TCOD::Color::WHITE * 0.5, TCOD::Color::BLACK)
                        else
                            TCOD.console_put_char_ex($con, x, y, ' '.ord, TCOD::Color::BLACK, GROUND_COLOR * 0.5)
                        end
                    end
                else
                    #it's visible
                    if wall
                        TCOD.console_put_char_ex($con, x, y, '#'.ord, TCOD::Color::WHITE, TCOD::Color::BLACK)
                    else
                        TCOD.console_put_char_ex($con, x, y, ' '.ord, TCOD::Color::BLACK, GROUND_COLOR)
                    end
                    #since it's visible, explore it
                    $map[x][y].explored = true
                end
            end
        end
    end

    #draw all objects in the list
    $objects.each do |object|
        object.draw()
    end

    #blit the contents of "con" to the root console
    TCOD.console_blit($con, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, nil, 0, 0, 1.0, 1.0)
end

##############################
# Initialization and Main Loop
##############################

TCOD.console_set_custom_font('../resources/arial10x10.png', TCOD::FONT_TYPE_GREYSCALE | TCOD::FONT_LAYOUT_TCOD, 0, 0)
TCOD.console_init_root(SCREEN_WIDTH, SCREEN_HEIGHT, 'ruby/TCOD tutorial', false, TCOD::RENDERER_SDL)
TCOD.sys_set_fps(LIMIT_FPS)
$con = TCOD.console_new(SCREEN_WIDTH, SCREEN_HEIGHT)

$player = Object.new(0, 0, '@', TCOD::Color::WHITE)

$objects = [$player]

make_map()

#create the FOV $map, according to the generated $map
$fov_map = TCOD.map_new(MAP_WIDTH, MAP_HEIGHT)
0.upto(MAP_HEIGHT-1) do |y|
    0.upto(MAP_WIDTH-1) do |x|
        TCOD.map_set_properties($fov_map, x, y, !$map[x][y].block_sight, !$map[x][y].blocked)
    end
end

$fov_recompute = true

trap('SIGINT') { exit! }

until TCOD.console_is_window_closed
    render_all()

    TCOD.console_flush()

    $objects.each do |object|
        object.clear()
    end

    will_exit = handle_keys
    break if will_exit
end
