package main

////////// CHEATS \\\\\\\\\\\\

FOG_OF_WAR_OFF :: true
NO_ENEMIES :: true
GOD_MODE :: false

////////// DEBUG OPTIONS \\\\\\\\\\

DEBUG_SPECTATE :: false
DEBUG_TURN_STEPPING :: false
DEBUG_OVERLAYS_ENABLED :: false
STUTTER_CHECKER_ENABLED :: false
CLAY_DEBUG_ENABLED :: false
// Delay procedural generation iterations by this many frames
// (to help visualise the generation)
PCG_ITERATION_DELAY :: 0
TESTS_ENABLED :: true

////////// ASSERTIONS \\\\\\\\\\\\\

MEMORY_VALIDATE_PADDING :: true

/////////// LOGGING \\\\\\\\\\\\\
when ODIN_DEBUG {
	LOG_LEVEL :: LogLevel.Trace
} else {
	LOG_LEVEL :: LogLevel.Error
}
// Whether to record messages received by host
LOG_HOST_MESSAGES :: false
// Whether to record messages received by client
LOG_CLIENT_MESSAGES :: false
LOG_LOG_ENTRIES :: false
LOG_COMMANDS :: false
LOG_EVENTS :: false

/////// MAGIC NUMBERS \\\\\\\\\\\

MAX_PLAYERS :: 8
MAX_ENTITIES :: 2048
SPRITE_SIZE :: 16
GRID_SIZE :: 16
DEFAULT_ZOOM :: 1
CAMERA_SPRING_CONSTANT :: 40
CAMERA_SPRING_DAMPER :: 10
LEVEL_WIDTH :: 60
LEVEL_HEIGHT :: 40
ENTITY_SPRING_CONSTANT :: 40
ENTITY_SPRING_DAMPER :: 10
FONT_SIZE_BASE :: 22

///////// FUTURE STATE \\\\\\\\\

GAME_SEED: u64 : 0 // Generate seed on each new game
// GAME_SEED: u64 : 0xdeadbeef653293
// GAME_SEED: u64 : 0x8d49336d22dd0a3
TURN_DELAY :: 0.1
ANIMATION_DELAY :: 0.25
MUSIC_ENABLED :: true
SPRINGS_ENABLED :: true

/////////// DERIVED \\\\\\\\\\\\\

// Whether to send cursor coords to the server. It's a nice feature but makes the messaging logs noisy
CURSOR_REPORTING_ENABLED :: LOG_HOST_MESSAGES == false && LOG_CLIENT_MESSAGES == false

//////////// SPRITE COORDINATES ////////////

SPRITE_COORD_PLAYER :: [2]f32{16 * 1, 16 * 0}
SPRITE_COORD_PLAYER_A :: [2]f32{16 * 2, 16 * 0}
SPRITE_COORD_PLAYER_B :: [2]f32{16 * 3, 16 * 0}
SPRITE_COORD_PLAYER_C :: [2]f32{16 * 4, 16 * 0}
SPRITE_COORD_PLAYER_OUTLINE :: [2]f32{16 * 5, 16 * 5}
SPRITE_COORD_RECT :: [2]f32{5 * 16, 2 * 16}
SPRITE_COORD_FLOOR_STONE :: [2]f32{2 * 16, 3 * 16}
SPRITE_COORD_FLOOR_STONE_2 :: [2]f32{3 * 16, 3 * 16}
SPRITE_COORD_BRICK_WALL_FACE :: [2]f32{0 * 16, 3 * 16}
SPRITE_COORD_BRICK_WALL_FACE_2 :: [2]f32{4 * 16, 3 * 16}
SPRITE_COORD_BRICK_WALL_BEHIND :: [2]f32{1 * 16, 3 * 16}
SPRITE_COORD_PIT_WALL :: [2]f32{4 * 16, 2 * 16}
SPRITE_COORD_SPIDER :: [2]f32{0 * 16, 2 * 16}
SPRITE_COORD_FIREBUG :: [2]f32{4 * 16, 1 * 16}
SPRITE_COORD_CORPSE :: [2]f32{1 * 16, 2 * 16}
SPRITE_COORD_WATER :: [2]f32{6 * 16, 2 * 16}
SPRITE_COORD_ROPE_BRIDGE :: [2]f32{6 * 16, 3 * 16}
SPRITE_COORD_ROPE_BRIDGE_2 :: [2]f32{7 * 16, 3 * 16}
SPRITE_COORD_CURSOR_ATTACK :: [2]f32{6 * 16, 5 * 16}
SPRITE_COORD_OTHER_PLAYER_CURSOR :: [2]f32{16 * 2, 16 * 5}
SPRITE_COORD_ACTIVE_CHEVRON :: [2]f32{16, 64}
SPRITE_COORD_DOT :: [2]f32{16 * 6, 16 * 4}
SPRITE_COORD_FOOTSTEPS :: [2]f32{7 * 16, 4 * 16}
SPRITE_COORD_THOUGHT_BUBBLE :: [2]f32{0, 64}
SPRITE_COORD_FIRE :: [2]f32{16 * 0, 16 * 7}

/********************
 * RANDOMNESS STREAMS
 ********************/

RNG_ROOM_PLACEMENT :: u64(0x7687ffa2b52a)
RNG_TILE_VARIANCE :: u64(0xbc7ad7b8ef)
RNG_ENEMY_PLACEMENT :: u64(0x87fc86c6bca)
RNG_GRASS_PLACEMENT :: 0x048736263aa
RNG_ITEM_PLACEMENT :: 0x2765bdf387cc
RNG_AUDIO :: u64(0x8762fa86fa)
RNG_AI :: u64(0x0897fce5ac67)
RNG_HIT :: u64(0x81beef6263aa)
