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

/***************
 * FUTURE STATE
 ***************/

GAME_SEED :: 0xdeadbeef3
TURN_DELAY :: 0.1

/*****************
 * DEBUG OPTIONS
 *****************/

DEBUG_OVERLAYS_ENABLED :: false
STUTTER_CHECKER_ENABLED :: true
// Delay procedural generation iterations by this many frames
// (to help visualise the generation)
PCG_ITERATION_DELAY :: 0
TESTS_ENABLED :: true

/***********
 * LOGGING *
 ***********/
LOG_LEVEL :: LogLevel.Trace
// Whether to record messages received by host
HOST_LOG_MESSAGES :: false
// Whether to record messages received by client
CLIENT_LOG_MESSAGES :: false

/***********
 * DERIVED *
 ***********/

// Whether to send cursor coords to the server. It's a nice feature but makes the messaging logs noisy
CURSOR_REPORTING_ENABLED :: HOST_LOG_MESSAGES == false && CLIENT_LOG_MESSAGES == false

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
SPRITE_COORD_WATER :: [2]f32{6 * 16, 2 * 16}
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
