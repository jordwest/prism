package main

import "core:fmt"
import "core:mem"
import "prism"

first_name: []string = {
	"Ada",
	"George",
	"Claire",
	"Odin",
	"Boris",
	"Baldric",
	"Jo",
	"Chuck",
	"Ton",
	"Verity",
	"Karl",
	"Sally",
	"Brenton",
	"Jeremy",
	"Fenton",
	"Karen",
	"Stanislav",
	"Don",
}

last_name_pre: []string = {
	"Love",
	"Bung",
	"Cake",
	"Offal",
	"Straw",
	"Ful",
	"Crab",
	"Bare",
	"Scar",
	"Hail",
	"Fail",
	"Dead",
	"Grumble",
	"Dul",
	"Sniffl",
	"Don",
	"Big",
	"Free",
	"Tiny",
	"Smal",
	"Smol",
	"Broke",
	"No",
	"Nor",
	"Side",
	"Cran",
	"Flan",
	"Ou",
	"Sal",
	"Soft",
	"Rua",
	"Spu",
	"Chuck",
	"Dur",
	"Fel",
	"Jug",
	"Smel",
	"Of",
	"Can",
	"Box",
	"Stin",
	"Fec",
	"Shy",
	"Rus",
	"Lux",
}
last_name_post: []string = {
	"bottom",
	"bum",
	"an",
	"face",
	"foot",
	"leg",
	"ton",
	"as",
	"sel",
	"den",
	"but",
	"eman",
	"man",
	"burn",
	"bery",
	"ful",
	"les",
	"nikov",
	"ary",
	"lace",
	"sol",
}

name_player_generate :: proc(
	rng: ^prism.SplitMixState,
	alloc: mem.Allocator = context.allocator,
) -> string {
	trace("%d unique lastnames", len(last_name_pre) * len(last_name_post))
	first := rng_range(rng, 0, i32(len(first_name)))
	last_pre := rng_range(rng, 0, i32(len(last_name_pre)))
	last_post := rng_range(rng, 0, i32(len(last_name_post)))

	return fmt.aprintfln(
		"%s %s%s",
		first_name[first],
		last_name_pre[last_pre],
		last_name_post[last_post],
		allocator = alloc,
	)
}
