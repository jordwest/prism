package prism

import "core:math"

TileCoord :: distinct [2]i32
TileCoordF :: distinct [2]f32

tile_distance :: proc(vector: TileCoord) -> i32 {
    return math.max(math.abs(vector.x), math.abs(vector.y))
}
