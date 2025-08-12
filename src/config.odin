package main

CLAY_DEBUG_ENABLED :: false
MAX_PLAYERS :: 8
MAX_ENTITIES :: 2048
SPRITE_SIZE :: 16
GRID_SIZE :: 16
DEFAULT_ZOOM :: 2
CAMERA_SPRING_CONSTANT :: 40
CAMERA_SPRING_DAMPER :: 10
LEVEL_WIDTH :: 40
LEVEL_HEIGHT :: 40
ENTITY_SPRING_CONSTANT :: 40
ENTITY_SPRING_DAMPER :: 10

/***************
 * FUTURE STATE
 ***************/

GAME_SEED :: 0xdeadbeef8
TURN_DELAY :: 0.1
MUSIC_ENABLED :: false
SPRINGS_ENABLED :: true

/*****************
 * DEBUG OPTIONS
 *****************/

DEBUG_OVERLAYS_ENABLED :: false
STUTTER_CHECKER_ENABLED :: true
// Delay procedural generation iterations by this many frames
// (to help visualise the generation)
PCG_ITERATION_DELAY :: 0
TESTS_ENABLED :: true

/**************
 * ASSERTIONS *
 *************/
MEMORY_VALIDATE_PADDING :: true

/***********
 * LOGGING *
 ***********/
LOG_LEVEL :: LogLevel.Trace
// Whether to record messages received by host
LOG_HOST_MESSAGES :: true
// Whether to record messages received by client
LOG_CLIENT_MESSAGES :: true
LOG_COMMANDS :: false

/***********
 * DERIVED *
 ***********/

// Whether to send cursor coords to the server. It's a nice feature but makes the messaging logs noisy
CURSOR_REPORTING_ENABLED :: LOG_HOST_MESSAGES == false && LOG_CLIENT_MESSAGES == false

/**********************
 * SPRITE COORDINATES *
 **********************/
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
SPRITE_COORD_SPIDER :: [2]f32{0 * 16, 2 * 16}
SPRITE_COORD_CORPSE :: [2]f32{1 * 16, 2 * 16}
SPRITE_COORD_WATER :: [2]f32{6 * 16, 2 * 16}
SPRITE_COORD_CURSOR_ATTACK :: [2]f32{6 * 16, 5 * 16}
SPRITE_COORD_OTHER_PLAYER_CURSOR :: [2]f32{16 * 2, 16 * 5}
SPRITE_COORD_ACTIVE_CHEVRON :: [2]f32{16, 64}
SPRITE_COORD_DOT :: [2]f32{16 * 6, 16 * 4}
SPRITE_COORD_FOOTSTEPS :: [2]f32{7 * 16, 4 * 16}
SPRITE_COORD_THOUGHT_BUBBLE :: [2]f32{0, 64}

/********************
 * RANDOMNESS STREAMS
 ********************/

RNG_ROOM_PLACEMENT :: u64(0x7687ffa2b52a)
RNG_TILE_VARIANCE :: u64(0xbc7ad7b8ef)
RNG_ENEMY_PLACEMENT :: u64(0x87fc86c6bca)
RNG_AUDIO :: u64(0x8762fa86fa)
RNG_AI :: u64(0x0897fce5ac67)
RNG_HIT :: u64(0x81beef6263aa)
