#!/usr/bin/env/ruby

require 'libtcod'
require './roguelike-sw3dish/Object'
require './roguelike-sw3dish/Tile'
require './roguelike-sw3dish/Rect'
require './roguelike-sw3dish/Fighter'
require './roguelike-sw3dish/ai/BasicMonster'
require './roguelike-sw3dish/ai/ConfusedMonster'
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

INVENTORY_WIDTH = 50

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

HEAL_AMOUNT = 4

LIGHTNING_DAMAGE = 20
LIGHTNING_RANGE = 5

FIREBALL_RADIUS = 3
FIREBALL_DAMAGE = 12

CONFUSE_NUM_TURNS = 10

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

            dice = TCOD.random_get_int(nil, 0, 100)
            if dice < 70
                # create a healing potion (70% chance)
                item_component = Item.new(use_function: method(:cast_heal))
                item = Object.new(
                    x,
                    y,
                    '!',
                    'healing potion',
                    TCOD::Color::VIOLET,
                    item: item_component
                )
            elsif dice < 70 + 10
                # create a lightning bolt scroll (10% chance)
                item_component = Item(use_function = cast_lightning)
                item = Object.new(
                    x,
                    y,
                    '#',
                    'scroll of lightning bolt',
                    TCOD::Color::LIGHT_YELLOW,
                    item: item_component
                )

            elsif dice < 70 + 10 + 10
                # create a fireball scroll (10% chance)
                item_component = Item(use_function = cast_fireball)
                item = Object.new(
                    x,
                    y,
                    '#',
                    'scroll of fireball',
                    TCOD::Color::LIGHT_YELLOW,
                    item: item_component
                )

            else
                # create a confuse scroll (10% chance)
                item_component = Item.new(use_function: method(cast_confuse))
                item = Object.new(
                    x,
                    y,
                    '#',
                    'scroll of confusion',
                    TCOD::Color::LIGHT_YELLOW,
                    item: item_component
                )
            end

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
                       !object.item.nil?
                        object.item.pick_up
                        break
                    end
                end
            end

            if key_char == 'i'
                # show the inventory
                chosen_item = inventory_menu(
                    "Press the key next to an item to use it, or any other to cancel.\n"
                )

                if !chosen_item.nil?
                    chosen_item.use
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

def target_tile(max_range = nil)
    # return the position of a tile left-flicked in player's FOV(optionally in a
    # range), or (nil, nil) if right-clicked
    while true
        # render the screen. this erases the inventory
        # and shows the names of objects under the mouse
        TCOD.console_flush()
        TCOD.sys_check_for_event(
            TCOD::EVENT_KEY_PRESS | TCOD::EVENT_MOUSE,
            $key,
            $mouse
        )
        render_all()

        x, y = $mouse.cx, $mouse.cy

        if $mouse.lbutton_pressed &&
            TCOD.map_is_in_fov($fov_map, x, y) &&
            (max_range.nil? || $player.distance(x, y) <= max_range)
            return {"x" => x, "y" => y}
        elsif $mouse.rbutton_pressed || key.vk == TCOD::KEY_ESCAPE
            return {"x" => nil, "y" => nil}
        end
    end
end

def target_monster(max_range = nil)
    # returns a clicked monster inside FOV up to a range, or nil if right-clicked
    while true
        x, y = target_tile(max_range).x, target_tile(max_range).y
        if x.nil?
            return nil
        end

        # return the first clicked monster, otherwise continue looping through
        # objects
        $objects.each do |object|
            if object.x == x &&
                object.y == y &&
                !object.fighter.nil? &&
                object != $player
                return object
            end
        end
    end
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
        "#{name} :  #{value.to_s}/#{maximum.to_s}"
    )
end

def message(new_msg, color = TCOD::Color::WHITE)
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

def menu(header, options, width)
    raise(
        ArgumentError,
        'Cannot have a menu with more than 26 options.'
    ) unless options.length <= 26

    # calculate total height for the header (after auto-wrap) and one line
    # per option
    header_height = TCOD.console_get_height_rect(
        $con,
        0,
        0,
        width,
        SCREEN_HEIGHT,
        header
    )
    height = options.length + header_height

    # create an off screen console that represents the menu's window
    window = TCOD.console_new(width, height)

    #print the header, with auto-wrap
    TCOD.console_set_default_foreground(window, TCOD::Color::WHITE)
    TCOD.console_print_rect_ex(
        window,
        0,
        0,
        width,
        height,
        TCOD::BKGND_NONE,
        TCOD::LEFT,
        header
    )

    # print all the options
    y = header_height
    letter_index = 'a'.ord
    options.each do |option_text|
        text = "(#{letter_index.chr}) #{option_text}"
        TCOD.console_print_ex(window, 0, y, TCOD::BKGND_NONE, TCOD::LEFT, text)
        y += 1
        letter_index += 1
    end

    # blit the contents of window to the root console
    x = SCREEN_WIDTH / 2 - width / 2
    y = SCREEN_HEIGHT / 2 - height / 2
    TCOD.console_blit(
        window,
        0,
        0,
        width,
        height,
        nil,
        x,
        y,
        1.0,
        0.7
    )
    TCOD.console_flush
    key = TCOD.console_wait_for_keypress(true)

    index = key.c.ord - 'a'.ord
    if index >= 0 && index < options.length
        return index
    end
    nil
end

def inventory_menu(header)
    # show a menu with each item of the inventory as an option
    if $inventory.length == 0
        options = ['Inventory is empty.']
    else
        options = []
        $inventory.each do |item|
            options.push(item.name)
        end
    end

    index = menu(header, options, INVENTORY_WIDTH)

    if index.nil? || $inventory.length == 0
        return nil
    end
    $inventory[index].item
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

def player_death(player)
    message('You died!', TCOD::Color::RED)
    $game_state = 'dead'

    # for added effect, transform the player into a corpse
    $player.char = '%'
    $player.color = TCOD::Color::DARK_RED
end

def monster_death(monster)
    # transform it into a corpse.
    # it doesn't block, can't be attacked/attack, and doesn't move
    message("#{monster.name.capitalize} is dead!", TCOD::Color::ORANGE)
    monster.send_to_back
    monster.char = '%'
    monster.color = TCOD::Color::DARK_RED
    monster.blocks = false
    monster.fighter = nil
    monster.ai = nil
    monster.name = "remains of #{monster.name}"
end

def cast_heal
    #heal the player
    if $player.fighter.hp == $player.fighter.max_hp
        message('You are already at full health.', TCOD::Color::RED)
        return 'cancelled'
    end
    message('Your wounds start to feel better!', TCOD::Color::LIGHT_VIOLET)
    $player.fighter.heal(HEAL_AMOUNT)
end

def cast_lightning
    # find closest enemy (inside a maximum range) and damage it
    monster = closest_monster(LIGHTNING_RANGE)
    if monster.nil?
        message('No enemy is close enough to strike', TCOD::Color::RED)
        return 'cancelled'
    end

    # zap it!
    message("A lightning bolt strikes the #{monster.name} with a loud thunder "\
                "for #{LIGHTNING_DAMAGE.to_s} hit points", TCOD::Color::LIGHT_BLUE)
    monster.fighter.take_damage(LIGHTNING_DAMAGE)
end

def cast_confuse
    message(
        "Left-click an enemy to confuse it, or right-click to cancel.",
        TCOD::Color::LIGHT_CYAN
    )
    monster = target_monster(CONFUSE_RANGE)
    if monster.nil?
        return 'cancelled'
    end
    old_ai = monster.ai
    monster.ai = ConfusedMonster.new(old_ai)
    monster.ai.owner = monster
    message("The eyes of the #{monster.name} look vacant, as it starts to "\
            "stumble around!", TCOD::Color::LIGHT_GREEN)

end

def cast_fireball
    # ask the player for a target tile to throw a fireball at
    message(
        "Left-click a target tile for the fireball, or right-click to cancel",
        TCOD::Color::LIGHT_CYAN
    )
    coords = target_tile()
    if coords.x.nil?
        return 'cancelled'
    end
    message(
        "The fireball explodes burning everything within "\
            "#{FIREBALL_RADIUS.to_s} tiles!",
        TCOD::Color::ORANGE
    )
    $objects.each do |object|
        if object.distance(coords.x, coords.y) <= FIREBALL_RADIUS &&
            !object.fighter.nil?
            message(
                "The #{object.name} gets burned for"\
                    "#{FIREBALL_DAMAGE.to_s} hit points.",
                TCOD::Color::ORANGE
            )
            object.fighter.take_damage(FIREBALL_DAMAGE)
        end
end

def closest_monster(max_range)
    # find closest enemy, up to a maximum range, and in the player's fov
    closest_enemy = nil
    # start with (slightly more than) maximum damage
    closest_dist = max_range + 1

    objects.each do |object|
        if !object.fighter.nil? &&
            !object == $player &&
            TCOD.map_is_in_fov($fov_map, object.x, object.y)
            # calculate distance between this object and the player
            dist = $player.distance_to(object)
            if dist < closest_dist
                closest_enemy = object
                closest_dist = dist
            end
        end
    end
    closest_enemy
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
