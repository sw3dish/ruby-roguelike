# Game screen constants
SCREEN_WIDTH = 80
SCREEN_HEIGHT = 50

# GUI constants
BAR_WIDTH = 20
PANEL_HEIGHT = 7
PANEL_Y = SCREEN_HEIGHT - PANEL_HEIGHT

# Dungeon map constants
MAP_WIDTH = SCREEN_WIDTH
MAP_HEIGHT = 43

# Message log constants
MSG_X = BAR_WIDTH + 2
MSG_WIDTH = SCREEN_WIDTH - BAR_WIDTH - 2
MSG_HEIGHT = PANEL_HEIGHT - 1

# Inventory screen
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

# parameters for spells
HEAL_AMOUNT = 4

LIGHTNING_DAMAGE = 20
LIGHTNING_RANGE = 5

FIREBALL_RADIUS = 3
FIREBALL_DAMAGE = 12

CONFUSE_NUM_TURNS = 10
