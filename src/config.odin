package main

CLAY_DEBUG_ENABLED :: false
LOG_LEVEL :: LogLevel.Trace
MAX_PLAYERS :: 8
MAX_ENTITIES :: 2048
SPRITE_SIZE :: 16
GRID_SIZE :: 16
DEFAULT_ZOOM :: 2
CAMERA_SPRING_CONSTANT :: 100
CAMERA_SPRING_DAMPER :: 20

// Whether to send cursor coords to the server. It's a nice feature but makes the messaging logs noisy
CURSOR_REPORTING_ENABLED :: true

// Whether to record messages received by host
HOST_LOG_MESSAGES :: false
// Whether to record messages received by client
CLIENT_LOG_MESSAGES :: false

/**********************
 * SPRITE COORDINATES *
 **********************/
SPRITE_COORD_PLAYER :: [2]f32{16 * 1, 16 * 0}
SPRITE_COORD_PLAYER_OUTLINE :: [2]f32{16 * 5, 16 * 5}
SPRITE_COORD_RECT :: [2]f32{5 * 16, 2 * 16}
SPRITE_COORD_OTHER_PLAYER_CURSOR :: [2]f32{16 * 3, 16 * 5}
SPRITE_COORD_ACTIVE_CHEVRON :: [2]f32{16, 64}
