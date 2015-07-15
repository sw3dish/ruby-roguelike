#!/usr/bin/env/ruby

require 'libtcod'
require '../roguelike-sw3dish/Object.rb'
require '../roguelike-sw3dish/Tile.rb'

SCREEN_WIDTH = 80
SCREEN_HEIGHT = 50

MAP_WIDTH = 80
MAP_HEIGHT = 45

LIMIT_FPS = 20

def make_map
    $map = []
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
        $playery -= 1
    elsif TCOD.console_is_key_pressed(TCOD::KEY_DOWN)
        $playery += 1
    elsif TCOD.console_is_key_pressed(TCOD::KEY_LEFT)
        $playerx -= 1
    elsif TCOD.console_is_key_pressed(TCOD::KEY_RIGHT)
        $playerx += 1
    end

    false
end

##############################
# Initialization and Main Loop
##############################

TCOD.console_set_custom_font('../arial10x10.png', TCOD::FONT_TYPE_GREYSCALE | TCOD::FONT_LAYOUT_TCOD, 0, 0)
TCOD.console_init_root(SCREEN_WIDTH, SCREEN_HEIGHT, 'ruby/TCOD tutorial', false, TCOD::RENDERER_SDL)
$con = TCOD.console_new(SCREEN_WIDTH, SCREEN_HEIGHT)
TCOD.sys_set_fps(LIMIT_FPS)

$playerx = SCREEN_WIDTH / 2
$playery = SCREEN_HEIGHT / 2

trap('SIGINT') { exit! }

until TCOD.console_is_window_closed
    TCOD.console_set_default_foreground($con, TCOD::Color::WHITE)
    TCOD.console_put_char($con, $playerx, $playery, '@'.ord, TCOD::BKGND_NONE)

    TCOD.console_blit($con, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, nil, 0, 0, 1.0, 1.0)
    TCOD.console_flush()

    TCOD.console_put_char($con, $playerx, $playery, ' '.ord, TCOD::BKGND_NONE)

    #handle keys and exit game if needed
    will_exit = handle_keys
    break if will_exit
end
