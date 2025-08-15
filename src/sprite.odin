package main

Sprite :: enum {
	Fire,
	Grass,
	Potion,
	HitEffect,
}

SpriteMeta :: struct {
	ascii_char: u8,
	frames:     []SpriteFrame,
}

SpriteFrame :: struct {
	offset: [2]f32,
}

sprite_meta: [Sprite]SpriteMeta = {
	.Fire = SpriteMeta {
		ascii_char = '^',
		frames = {
			SpriteFrame{offset = {0 * SPRITE_SIZE, 7 * SPRITE_SIZE}},
			SpriteFrame{offset = {1 * SPRITE_SIZE, 7 * SPRITE_SIZE}},
			SpriteFrame{offset = {2 * SPRITE_SIZE, 7 * SPRITE_SIZE}},
		},
	},
	.Grass = SpriteMeta {
		ascii_char = '"',
		frames = {
			SpriteFrame{offset = {0 * SPRITE_SIZE, 6 * SPRITE_SIZE}},
			SpriteFrame{offset = {1 * SPRITE_SIZE, 6 * SPRITE_SIZE}},
		},
	},
	.Potion = SpriteMeta {
		ascii_char = '"',
		frames = {SpriteFrame{offset = {7 * SPRITE_SIZE, 5 * SPRITE_SIZE}}},
	},
	.HitEffect = SpriteMeta {
		ascii_char = 'X',
		frames = {SpriteFrame{offset = {5 * SPRITE_SIZE, 1 * SPRITE_SIZE}}},
	},
}

sprite_frame :: proc(x: f32, y: f32, size: f32 = 16) -> SpriteFrame {
	return SpriteFrame{offset = {x * size, y * size}}
}

sprite_choose_frame :: proc(meta: ^SpriteMeta, frame: int) -> ^SpriteFrame {
	return &meta.frames[frame % len(meta.frames)]
}
