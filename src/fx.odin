package main

import "prism"

Fx :: struct {
	type:     FxType,
	pos:      TileCoord,
	t0:       f32,
	lifetime: f32,
	dmg:      i32,
}

FxType :: enum {
	HitIndicator,
	MissIndicator,
	SlowedIndicator,
}

fx_init :: proc() {
	prism.pool_init(&state.client.fx)
}

fx_add :: proc(fx: Fx) -> bool {
	id, _, ok := prism.pool_add(&state.client.fx, fx)
	return ok
}

fx_spawn_dmg :: proc(pos: TileCoord, dmg: i32) {
	fx_add(
		Fx {
			type = dmg == 0 ? .MissIndicator : .HitIndicator,
			pos = pos,
			t0 = state.t,
			dmg = dmg,
			lifetime = 1.5,
		},
	)
}

fx_process :: proc(id: prism.PoolId, fx: ^Fx) {
	if state.t - fx.t0 >= fx.lifetime {
		prism.pool_delete(&state.client.fx, id)
	}
}
