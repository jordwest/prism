package main

import "core:container/queue"
import "fresnel"
import "prism"

SoundEffect :: enum {
	Footstep,
	Punch,
	Miss,
	EnemyDeath,
	PlayerDeath,
}

@(private = "file")
audio_queue_backing: [32]SoundEffect

AudioQueue :: queue.Queue(SoundEffect)

audio_init :: proc() {
	if !queue.init_from_slice(&state.client.audio_queue, audio_queue_backing[:]) {
		err("Failed to init")
	}
	trace("init")
}

audio_system :: proc() {
	rng := prism.rand_splitmix_create(GAME_SEED, RNG_AUDIO)
	prism.rand_splitmix_add_f32(&rng, state.t)

	for {
		sfx, ok := queue.pop_front_safe(&state.client.audio_queue)
		if !ok do break

		switch sfx {
		case .Punch:
			fresnel.play(2)
		case .Footstep:
			fresnel.play(prism.rand_splitmix_get_i32_range(&rng, 4, 13))
		case .Miss:
			fresnel.play(3)
		case .EnemyDeath:
		// TODO
		case .PlayerDeath:
			fresnel.play(14)
		}
	}
}

audio_play :: proc(sound: SoundEffect) {
	ok, e := queue.push_back(&state.client.audio_queue, sound)
	if !ok || e != nil {
		err("Failed to queue sound %s: %v", sound, err)
	}
}
