package main

EffectList :: [EffectType]Effect

Effect :: struct {
	flags:        bit_set[EffectFlag],
	turns:        u8,
	turns_remain: u8,
}

EffectFlag :: enum {
	Active,
}

EffectType :: enum {
	Slowed,
}

effect_remove :: proc(eff_list: ^EffectList, type: EffectType) {
	eff_list[type].flags -= {.Active}
	eff_list[type].turns = 0
	eff_list[type].turns_remain = 0
}

effect_turn :: proc(eff_list: ^EffectList) {
	for &eff, type in eff_list {
		if .Active not_in eff.flags do continue

		switch type {
		case .Slowed:
			if eff.turns_remain <= 1 {
				effect_remove(eff_list, type)
			} else {
				eff.turns_remain -= 1
			}
		}
	}
}
