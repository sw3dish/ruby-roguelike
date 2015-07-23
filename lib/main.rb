#!/usr/bin/env/ruby

require 'libtcod'
require './roguelike-sw3dish/Object'
require './roguelike-sw3dish/Tile'
require './roguelike-sw3dish/Rect'
require './roguelike-sw3dish/Fighter'
require './roguelike-sw3dish/BasicMonster'
require './roguelike-sw3dish/Item'

SCREEN_WIDTH = 80
SCREEN_HEIGHT = 50

BAR_WIDTH = 20
PANEL_HEIGHT = 7
PANEL_Y = SCREEN_HEIGHT - PANEL_HEIGHT

MAP_WIDTH = SCREEN_WIDTH
MAP_HEIGHT = 43

MSG_X = BAR_WIDTH + 2
MSG_WIDTH = SCREEN_WIDTH - BAR_WIDTH - 2
MSG_HEIGHT = PANEL_HEIGHT - 1


# parameters for dungeon generator
ROOM_MAX_SIZE = 10
ROOM_MIN_SIZE = 6
MAX_ROOMS = 30

MAX_ROOM_MONSTERS = 3
MAX_ROOM_ITEMS = 2

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
    #horizontal tunnel. min and max are used in case x1>x2
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

            place_objects(new_room)

            # center coordinates of new room, will be useful later
            new_x, new_y = new_room.center


            if num_rooms == 0
                $player.x = new_x
                $player.y = new_y
            else
                prev_x, prev_y = rooms[num_rooms-1].center

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

def place_objects(room)
    # choose random number of monsters
    num_monsters = TCOD.random_get_int(nil, 0, MAX_ROOM_MONSTERS)

    0.upto(num_monsters) do |i|
        # choose random spot for this monster
        x = TCOD.random_get_int(nil, room.x1 + 1, room.x2 - 1)
        y = TCOD.random_get_int(nil, room.y1 + 1, room.y2 - 1)

        if not is_blocked(x, y)
            if TCOD.random_get_int(nil, 0, 100) < 80
                # create an orc
                fighter_component = Fighter.new(
                    hp: 10,
                    defense: 0,
                    power: 3,
                    death_function: method(:monster_death)
                )
                ai_component = BasicMonster.new
                monster = Object.new(
                    x,
                    y,
                    'o',
                    'orc',
                    TCOD::Color::DESATURATED_GREEN,
                    blocks: true,
                    fighter: fighter_component,
                    ai: ai_component
                )
            else
                # create a troll
                fighter_component = Fighter.new(
                    hp: 16,
                    defense: 1,
                    power: 4,
                    death_function: method(:monster_death)
                )
                ai_component = BasicMonster.new
                monster = Object.new(
                    x,
                    y,
                    'T',
                    'troll',
                    TCOD::Color::DARKER_GREEN,
                    blocks: true,
                    fighter: fighter_component,
                    ai: ai_component
                )
            end

            $objects << monster
        end
    end

    num_items = TCOD.random_get_int(nil, 0, MAX_ROOM_ITEMS)

    0.upto(num_items) do |i|
        x = TCOD.random_get_int(nil, room.x1 + 1, room.x2 - 1)
        y = TCOD.random_get_int(nil, room.y1 + 1, room.y2 - 1)

        # only place it if the tile is not blocked
        if !is_blocked(x, y)
            # create a healing position
            item_component = Item.new()
            item = Object.new(
                x,
                y,
                '!',
                'healing potion',
                TCOD::Color::VIOLET,
                item: item_component
            )

            $objects.push(item)
            item.send_to_back
        end
    end
end

def handle_keys
    #fullscreen
    if $key.vk == TCOD::KEY_ENTER && $key.lalt
        TCOD.console_set_fullscreen(!TCOD.console_is_fullscreen)
    #exit game
    elsif $key.vk == TCOD:: KEY_ESCAPE
        return 'exit'
    end

    if $game_state == 'playing'
        #movement keys
        if $key.vk == TCOD::KEY_UP
            player_move_or_attack(0, -1)
        elsif $key.vk == TCOD::KEY_DOWN
            player_move_or_attack(0, 1)
        elsif $key.vk == TCOD::KEY_LEFT
            player_move_or_attack(-1, 0)
        elsif $key.vk == TCOD::KEY_RIGHT
            player_move_or_attack(1, 0)
        else
            # test for other keys
            key_char = $key.c.chr

            if key_char == 'g'
                # pick up an item
                $objects.each do |object| # look for an item in the player's tile
                    if object.x == $player.x &&
                       object.y == $player.y &&
                       !object.nil?
                        object.item.pick_up
                        break
                    end
                end
            end
            return 'didnt-take-turn'
        end
    end

    false
end

def get_names_under_mouse
    x, y = $mouse.cx, $mouse.cy
    names = []
    $objects.each do |object|
        if object.x == x &&
           object.y == y &&
           TCOD.map_is_in_fov($fov_map, object.x, object.y)
          names.push(object.name)
       end
    end
    names.join(', ').capitalize
end

def render_all
    if $fov_recompute
        #recompute FOV if needed(the $player moved or something)
        $fov_recompute = false
        TCOD.map_compute_fov(
            $fov_map,
            $player.x,
            $player.y,
            TORCH_RADIUS,
            FOV_LIGHT_WALLS,
            FOV_ALGO
        )

        #go through all tiles, and set their background color according to the FOV
        0.upto(MAP_HEIGHT-1) do |y|
            0.upto(MAP_WIDTH-1) do |x|
                visible = TCOD.map_is_in_fov($fov_map, x, y)
                wall = $map[x][y].block_sight
                if not visible
                    #if it's not visible right now,
                    # the $player can only see it if it's explored
                    if $map[x][y].explored
                        if wall
                            TCOD.console_put_char_ex(
                                $con,
                                x,
                                y,
                                '#'.ord,
                                TCOD::Color::WHITE * 0.5,
                                TCOD::Color::BLACK
                            )
                        else
                            TCOD.console_put_char_ex(
                                $con,
                                x,
                                y,
                                ' '.ord,
                                TCOD::Color::BLACK,
                                GROUND_COLOR * 0.5
                            )
                        end
                    end
                else
                    #it's visible
                    if wall
                        TCOD.console_put_char_ex(
                            $con,
                            x,
                            y,
                            '#'.ord,
                            TCOD::Color::WHITE,
                            TCOD::Color::BLACK
                        )
                    else
                        TCOD.console_put_char_ex(
                            $con,
                            x,
                            y,
                            ' '.ord,
                            TCOD::Color::BLACK,
                            GROUND_COLOR
                        )
                    end
                    #since it's visible, explore it
                    $map[x][y].explored = true
                end
            end
        end
    end

    #draw all objects in the list
    $objects.each do |object|
        if object != $player
            object.draw
        end
        $player.draw
    end

    #blit the contents of "con" to the root console
    TCOD.console_blit(
        $con,
        0,
        0,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        nil,
        0,
        0,
        1.0,
        1.0
    )

    # prepare to render the GUI panel
    TCOD.console_set_default_background($panel, TCOD::Color::BLACK)
    TCOD.console_clear($panel)

    # print the game messages, one line at a time
    y = 1
    $game_msgs.each do |message|
        TCOD.console_set_default_foreground($panel, message["color"])
        TCOD.console_print_ex(
            $panel,
            MSG_X,
            y,
            TCOD::BKGND_NONE,
            TCOD::LEFT,
            message["line"]
        )
        y += 1
    end

    # show the player's stats
    render_bar(
        1,
        1,
        BAR_WIDTH,
        'HP',
        $player.fighter.hp,
        $player.fighter.max_hp,
        TCOD::Color::LIGHT_RED,
        TCOD::Color::DARKER_RED
    )

    # display names of objects under the mouse
    TCOD.console_set_default_foreground($panel, TCOD::Color::LIGHT_GREY)
    TCOD.console_print_ex(
        $panel,
        1,
        0,
        TCOD::BKGND_NONE,
        TCOD::LEFT,
        get_names_under_mouse
    )

    # blit the contents to the root console
    TCOD.console_blit(
        $panel,
        0,
        0,
        SCREEN_WIDTH,
        PANEL_HEIGHT,
        nil,
        0,
        PANEL_Y,
        1.0,
        1.0
    )
end

def render_bar(x, y, total_width, name, value, maximum, bar_color, back_color)
    # render a bar (HP, experience, etc.)
    # first, calculate the width of the bar
    bar_width = (value / maximum).to_int * total_width

    # render the background first
    TCOD.console_set_default_background($panel, back_color)
    TCOD.console_rect($panel, x, y, total_width, 1, false, TCOD::BKGND_SCREEN)

    # now render the bar on top
    TCOD.console_set_default_background($panel, bar_color)
    if bar_width > 0
        TCOD.console_rect($panel, x, y, bar_width, 1, false, TCOD::BKGND_SCREEN)
    end

    # finally, some centered text with the values
    TCOD.console_set_default_foreground($panel, TCOD::Color::WHITE)
    TCOD.console_print_ex(
        $panel,
        x + total_width / 2,
        y,
        TCOD::BKGND_NONE,
        TCOD::CENTER,
        name + ": " + value.to_s + '/' + maximum.to_s
    )
end

def message(new_msg, color = TCOD::Color::White)
    new_msg_lines = wrap(new_msg, MSG_WIDTH)

    new_msg_lines.each do |line|
        if $game_msgs.length == MSG_HEIGHT
            $game_msgs.delete_at(0)
        end

        $game_msgs.push({"line" => line, "color" => color})
    end
end

def wrap(text, width = MSG_WIDTH)
    text.gsub(/(.{1,#{width}})( +|$\n?)|(.{1,#{width}})/,
    "\\1\\3\n").split("\n")
end

def player_move_or_attack(dx, dy)
    x = $player.x + dx
    y = $player.y + dy

    target = nil
    $objects.each do |object|
        if !object.fighter.nil? && object.x == x && object.y == y
            target = object
        end
    end

    if not target.nil?
        $player.fighter.attack(target)
    else
        $player.move(dx, dy)
        $fov_recompute = true
    end
end

def player_death
    puts 'You died!'
    $game_state = 'dead'

    # for added effect, transform the player into a corpse
    $player.char = '%'
    $player.color = TCOD::Color::DARK_RED
end

def monster_death(monster)
    # transform it into a corpse.
    # it doesn't block, can't be attacked/attack, and doesn't move
    puts monster.name.capitalize + ' is dead!'
    monster.send_to_back
    monster.char = '%'
    monster.color = TCOD::Color::DARK_RED
    monster.blocks = false
    monster.fighter = nil
    monster.ai = nil
    monster.name = 'remains of ' + monster.name
end
##############################
# Initialization and Main Loop
##############################

TCOD.console_set_custom_font(
    '../resources/arial10x10.png',
    TCOD::FONT_TYPE_GREYSCALE | TCOD::FONT_LAYOUT_TCOD,
    0,
    0
)

TCOD.console_init_root(
    SCREEN_WIDTH,
    SCREEN_HEIGHT,
    'ruby/TCOD tutorial',
    false,
    TCOD::RENDERER_SDL
)
TCOD.sys_set_fps(LIMIT_FPS)
$con = TCOD.console_new(SCREEN_WIDTH, SCREEN_HEIGHT)
$panel = TCOD.console_new(SCREEN_WIDTH, PANEL_HEIGHT)

fighter_component = Fighter.new(
    hp: 30,
    defense: 2,
    power: 5,
    death_function: method(:player_death)
)
$player = Object.new(
    0,
    0,
    '@',
    'player',
    TCOD::Color::WHITE,
    blocks: true,
    fighter: fighter_component
)

$objects = [$player]

make_map

#create the FOV $map, according to the generated $map
$fov_map = TCOD.map_new(MAP_WIDTH, MAP_HEIGHT)
0.upto(MAP_HEIGHT-1) do |y|
    0.upto(MAP_WIDTH-1) do |x|
        TCOD.map_set_properties(
            $fov_map,
            x,
            y,
            !$map[x][y].block_sight,
            !$map[x][y].blocked
        )
    end
end

$fov_recompute = true

trap('SIGINT') { exit! }

$game_state = 'playing'
$player_action = nil

# create the list of game messages and their colors, starts empty
$game_msgs = []

message(
    "Welcome stranger! Prepare to perish in the Tombs of the Ancient Kings.",
    TCOD::Color::RED
)

$key = TCOD::Key.new()
$mouse = TCOD::Mouse.new()

$inventory = []

until TCOD.console_is_window_closed
    TCOD.sys_check_for_event(
        TCOD::EVENT_KEY_PRESS | TCOD::EVENT_MOUSE,
        $key,
        $mouse
    )
    render_all

    TCOD.console_flush

    $objects.each do |object|
        object.clear
    end

    $player_action = handle_keys
    if $game_state == 'playing' && $player_action != 'didnt-take-turn'
        $objects.each do |object|
            if object.ai
                object.ai.take_turn
            end
        end
    end
    break if $player_action == 'exit'
end
