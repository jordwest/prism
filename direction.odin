package prism

Cardinal :: enum {
	North,
	East,
	South,
	West,
}

NEIGHBOUR_TILES_4D: []([2]i32) = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}
NEIGHBOUR_TILES_8D: []([2]i32) = {
	{1, 1}, // SE
	{-1, -1}, // NW
	{1, -1}, // NE
	{-1, 1}, // SW
	{1, 0}, // EAST
	{0, 1}, // SOUTH
	{-1, 0}, // WEST
	{0, -1}, // NORTH
}
