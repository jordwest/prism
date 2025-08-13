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
	IntroSong, // TODO: Add a music enum
}

Ambience :: enum {
	Fire,
}

@(private = "file")
audio_queue_backing: [32]SoundEffect

AudioQueue :: queue.Queue(SoundEffect)

AudioState :: struct {
	queue:              AudioQueue,
	ambience:           bit_set[Ambience],
	intro_music_played: bool,
}

audio_init :: proc() {
	if !queue.init_from_slice(&state.client.audio.queue, audio_queue_backing[:]) {
		err("Failed to init")
	}
	trace("init")
}

audio_frame :: proc() {
	rng := prism.rand_splitmix_create(GAME_SEED, RNG_AUDIO)
	prism.rand_splitmix_add_f32(&rng, state.t)

	audio := &state.client.audio
	if .Fire in audio.ambience {fresnel.play(200)} else {fresnel.stop(200)}

	if state.client.game.enemies_killed >= 5 && !state.client.audio.intro_music_played do audio_play(.IntroSong)

	for {
		sfx, ok := queue.pop_front_safe(&state.client.audio.queue)
		if !ok do break

		switch sfx {
		case .Punch:
			fresnel.play(2, true)
		case .Footstep:
			fresnel.play(prism.rand_splitmix_get_i32_range(&rng, 4, 13), true)
		case .Miss:
			fresnel.play(3, true)
		case .EnemyDeath:
		// TODO
		case .PlayerDeath:
			// fresnel.play(14, true)
			fresnel.play(15, true)
		case .IntroSong:
			if !MUSIC_ENABLED do continue
			state.client.audio.intro_music_played = true
			fresnel.play(100, false)
		}
	}
}

audio_play :: proc(sound: SoundEffect) {
	ok, e := queue.push_back(&state.client.audio.queue, sound)
	if !ok || e != nil {
		err("Failed to queue sound %s: %v", sound, e)
	}
}
