package main
import clay "clay-odin"
import "core:c"
import "core:fmt"
import "core:math"
import "fresnel"
import "prism"

// Define some colors.
COLOR_LIGHT :: clay.Color{224, 215, 210, 50}
COLOR_RED :: clay.Color{168, 66, 28, 150}
COLOR_ORANGE :: clay.Color{225, 138, 50, 150}
COLOR_BLACK :: clay.Color{0, 0, 0, 255}
COLOR_WHITE :: clay.Color{255, 255, 255, 255}
COLOR_GRAY_200 :: clay.Color{170, 170, 170, 255}
COLOR_GRAY_700 :: clay.Color{30, 30, 30, 255}
COLOR_LIGHT_RED :: clay.Color{255, 170, 170, 150}
COLOR_LIGHT_YELLOW :: clay.Color{255, 255, 170, 150}
COLOR_LIGHT_GREEN :: clay.Color{170, 255, 170, 150}
COLOR_PURPLE_800 :: clay.Color{20, 16, 24, 255}
COLOR_PURPLE_900 :: clay.Color{10, 8, 12, 255}
COLOR_PURPLE_500 :: clay.Color{45, 32, 59, 255}
COLOR_PURPLE_400 :: clay.Color{80, 60, 100, 255}
COLOR_PURPLE_200 :: clay.Color{128, 106, 153, 255}

with_alpha :: proc(color: clay.Color, a: f32) -> clay.Color {
	return clay.Color{color.r, color.g, color.b, a}
}

// Layout config is just a struct that can be declared statically, or inline
sidebar_item_layout := clay.LayoutConfig {
	sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(50)},
}

string_from_clay_slice :: proc(slice: clay.StringSlice) -> string {
	return string(slice.chars[:slice.length])
}

// Re-useable components are just normal procs.
sidebar_item_component :: proc(index: u32) {
	if clay.UI()(
	{
		id = clay.ID("SidebarBlob", index),
		layout = sidebar_item_layout,
		backgroundColor = COLOR_ORANGE,
	},
	) {}
}

CustomClayElement :: union {
	TextInput,
}
TextInput :: struct {
	value: string,
}

// An example function to create your layout tree
ui_layout_screen :: proc() -> clay.ClayArray(clay.RenderCommand) {
	context.temp_allocator = arena_ui_frame.allocator

	if state.client.game.status != .Started do return ui_layout_menu()

	if mode, ok := state.client.ui.mode.(UiThrowingItem); ok {
		return ui_layout_throw()
	}

	// Begin constructing the layout.
	clay.BeginLayout()
	default_text_config := clay.TextConfig({textColor = COLOR_WHITE, fontSize = FONT_SIZE_BASE})

	// An example of laying out a UI with a fixed-width sidebar and flexible-width main content
	// NOTE: To create a scope for child components, the Odin API uses `if` with components that have children
	if clay.UI()(
	{
		id = clay.ID("OuterContainer"),
		layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})}},
		// backgroundColor = {250, 250, 255, 0},
	},
	) {
		if clay.UI()(
		{
			id = clay.ID("PlayArea"),
			layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})}},
		},
		) {}
		if clay.UI()(
		{
			id = clay.ID("InventorySidebar"),
			layout = {
				layoutDirection = .TopToBottom,
				padding = {8, 8, 8, 8},
				sizing = {width = clay.SizingPercent(0.25), height = clay.SizingGrow({})},
				childGap = 8,
			},
			backgroundColor = COLOR_PURPLE_800,
		},
		) {
			player, found_player_entity := player_entity().?
			if found_player_entity {
				_add_fmt_text("HP: %d/%d", player.hp, player.meta.max_hp)
			}
			clay.Text(
				"Inventory",
				clay.TextConfig({textColor = COLOR_GRAY_200, fontSize = FONT_SIZE_BASE}),
			)
			if clay.UI()(
			{
				id = clay.ID("InventoryList"),
				layout = {
					layoutDirection = .TopToBottom,
					sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
					// childGap = 4,
				},
			},
			) {
				button_config: clay.ElementDeclaration = {
					layout = {padding = {16, 16, 8, 8}, sizing = {width = clay.SizingGrow({})}},
					backgroundColor = clay.Hovered() ? COLOR_PURPLE_200 : COLOR_PURPLE_500,
				}

				player_entity_id := state.client.controlling_entity_id
				inventory_iter := container_iterator(SharedLootContainer)
				mode := ui_mode()
				activate_mode, is_activating_item := mode.(UiActivatingItem)

				for item in container_iterate(&inventory_iter) {
					is_activating_this_item :=
						is_activating_item && activate_mode.item_id == item.id
					if clay.UI()(
					{
						layout = {padding = {8, 8, 8, 8}, sizing = {width = clay.SizingGrow({})}},
						backgroundColor = is_activating_this_item ? COLOR_PURPLE_400 : (clay.Hovered() ? COLOR_PURPLE_500 : COLOR_PURPLE_800),
					},
					) {
						clay.OnHover(input_on_hover_inventory_item, item)
						switch t in item.type {
						case PotionType:
							_add_fmt_text("%d Potion of %s", item.count, item.type)
						}
					}

					if is_activating_this_item {
						if clay.UI()(
						{
							layout = {
								padding = {4, 4, 4, 4},
								sizing = {width = clay.SizingGrow({})},
								childGap = 8,
								layoutDirection = .TopToBottom,
							},
						},
						) {
							ui_button(
								{
									on_hover = input_on_hover_consume,
									on_hover_user_data = item,
									text = "Consume",
								},
							)
							ui_button(
								{
									text = "Throw",
									on_hover = input_on_hover_throw,
									on_hover_user_data = item,
								},
							)
							ui_button(
								{
									text = "Drop",
									on_hover = input_on_hover_drop,
									on_hover_user_data = item,
								},
							)
						}
					}
				}
			}
		}
	}

	// Returns a list of render commands
	return clay.EndLayout()
} // An example function to create your layout tree

ui_layout_throw :: proc() -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	{
		clay.OpenElement(
			{
				id = clay.ID("OuterContainer"),
				layout = {
					sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
					layoutDirection = .TopToBottom,
				},
			},
		)

		{
			clay.OpenElement(
				{
					id = clay.ID("ModHeader"),
					layout = {
						sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
						padding = {32, 32, 32, 32},
						childAlignment = {x = .Center, y = .Center},
					},
					backgroundColor = COLOR_PURPLE_800,
				},
			)

			clay.Text(
				"Throw where?",
				clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_WHITE}),
			)
		}
	}
	return clay.EndLayout()
}

ui_component_lobby :: proc() {
	clay.OpenElement(
		{
			id = clay.ID("Lobby"),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {width = clay.SizingFixed(400), height = clay.SizingFit({})},
				childAlignment = {
					x = clay.LayoutAlignmentX.Center,
					y = clay.LayoutAlignmentY.Center,
				},
				childGap = 16,
			},
		},
	)

	clay.Text("Lobby", clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_WHITE}))

	if (state.host.is_host) {
		clay.Text(
			"Send this URL to other players:",
			clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_GRAY_200}),
		)
		{
			clay.OpenElement(
				{
					id = clay.ID("ConnectionPath"),
					layout = {padding = {8, 8, 8, 8}, sizing = {width = clay.SizingGrow({})}},
					backgroundColor = COLOR_PURPLE_900,
				},
			)
			{
				text_input := new(CustomClayElement, allocator = context.temp_allocator)
				text_input^ = TextInput {
					value = state.host.connection_path,
				}
				clay.OpenElement(
					{
						id = clay.ID("ConnectionPathInput"),
						layout = {
							sizing = {
								width = clay.SizingGrow({}),
								height = clay.SizingFixed(FONT_SIZE_BASE),
							},
						},
						custom = {customData = text_input},
					},
				)
			}
		}
	}

	_add_fmt_text("%d players joined", len(state.client.game.players))
	{
		clay.OpenElement(
			{
				id = clay.ID("PlayerList"),
				layout = {
					padding = {8, 8, 8, 8},
					sizing = {width = clay.SizingGrow({})},
					layoutDirection = .TopToBottom,
					childGap = 8,
				},
				backgroundColor = COLOR_PURPLE_900,
			},
		)

		for _, &player in state.client.game.players {
			clay.TextDynamic(
				prism.bufstring_as_str(&player.display_name),
				clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_WHITE}),
			)
		}
	}

	if state.host.is_host {
		ui_button(
			{
				text = "Start game",
				on_hover = input_on_hover_start_game,
				disabled = len(state.client.game.players) < 1,
			},
		)
	} else {
		clay.Text(
			"Waiting for host to start game...",
			clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_GRAY_200}),
		)
	}
}

ui_component_menu :: proc() {
	clay.OpenElement(
		{
			id = clay.ID("Menu"),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {width = clay.SizingFixed(300), height = clay.SizingFit({})},
				childAlignment = {
					x = clay.LayoutAlignmentX.Center,
					y = clay.LayoutAlignmentY.Center,
				},
				childGap = 16,
			},
		},
	)

	// clay.Text(
	// 	"Untitled.odin",
	// 	clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_WHITE}),
	// )

	clay.Text(
		"Enter your name:",
		clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_GRAY_200}),
	)
	{
		clay.OpenElement(
			{
				id = clay.ID("DisplayName"),
				layout = {padding = {8, 8, 8, 8}, sizing = {width = clay.SizingGrow({})}},
				backgroundColor = COLOR_PURPLE_900,
			},
		)
		if (state.client.ui.input_destination == .DisplayName) {
			text_input := new(CustomClayElement, allocator = context.temp_allocator)
			text_input^ = TextInput {
				value = prism.bufstring_as_str(&state.client.my_display_name),
			}
			clay.OpenElement(
				{
					id = clay.ID("DisplayNameInput"),
					layout = {
						sizing = {
							width = clay.SizingGrow({}),
							height = clay.SizingFixed(FONT_SIZE_BASE),
						},
					},
					custom = {customData = text_input},
				},
			)
		}
	}

	empty_display_name := prism.bufstring_as_str(&state.client.my_display_name) == ""

	ui_button(
		{text = "Host game", on_hover = input_on_hover_host_game, disabled = empty_display_name},
	)
	ui_button(
		{text = "Join game", on_hover = input_on_hover_join_game, disabled = empty_display_name},
	)
}

ui_component_join :: proc() {
	clay.OpenElement(
		{
			id = clay.ID("Join"),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {width = clay.SizingFixed(300), height = clay.SizingFit({})},
				childAlignment = {
					x = clay.LayoutAlignmentX.Center,
					y = clay.LayoutAlignmentY.Center,
				},
				childGap = 16,
			},
		},
	)

	connection_path := prism.bufstring_as_str(&state.client.connection_path)

	clay.Text(
		"Enter join URL:",
		clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_GRAY_200}),
	)
	{
		clay.OpenElement(
			{
				id = clay.ID("JoinURL"),
				layout = {padding = {8, 8, 8, 8}, sizing = {width = clay.SizingGrow({})}},
				backgroundColor = COLOR_PURPLE_900,
			},
		)
		if (state.client.ui.input_destination == .JoinURL) {
			text_input := new(CustomClayElement, allocator = context.temp_allocator)
			text_input^ = TextInput {
				value = connection_path,
			}
			clay.OpenElement(
				{
					id = clay.ID("JoinURLInput"),
					layout = {
						sizing = {
							width = clay.SizingGrow({}),
							height = clay.SizingFixed(FONT_SIZE_BASE),
						},
					},
					custom = {customData = text_input},
				},
			)
		}
	}

	ui_button(
		{
			text = "Join game",
			on_hover = input_on_hover_join_game,
			disabled = connection_path == "",
		},
	)
}

ui_component_game_over :: proc() {
	clay.Text(
		"Game Over",
		clay.TextConfig({fontSize = FONT_SIZE_BASE * 4, textColor = COLOR_WHITE}),
	)
	clay.Text(
		"Everyone is dead",
		clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_GRAY_200}),
	)
}

ui_component_game_won :: proc() {
	clay.OpenElement(
		{
			layout = {
				childAlignment = {
					x = clay.LayoutAlignmentX.Center,
					y = clay.LayoutAlignmentY.Center,
				},
				layoutDirection = .TopToBottom,
				childGap = 8,
			},
		},
	)

	clay.Text(
		"You win... for now",
		clay.TextConfig({fontSize = FONT_SIZE_BASE * 4, textColor = COLOR_WHITE}),
	)
	clay.Text(
		"You descend the stairwell only to discover a sign that says:",
		clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_GRAY_200}),
	)
	clay.Text(
		"Under construction, come back later",
		clay.TextConfig({fontSize = FONT_SIZE_BASE, textColor = COLOR_WHITE}),
	)
}

ui_layout_menu :: proc() -> clay.ClayArray(clay.RenderCommand) {
	//f
	clay.BeginLayout()


	{
		clay.OpenElement(
			{
				id = clay.ID("OuterContainer"),
				layout = {
					childAlignment = {
						x = clay.LayoutAlignmentX.Center,
						y = clay.LayoutAlignmentY.Center,
					},
					sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
				},
			},
		)

		{
			clay.OpenElement(
				{
					id = clay.ID("MenuContainer"),
					layout = {
						sizing = {width = clay.SizingFit({}), height = clay.SizingFit({})},
						padding = {16, 16, 16, 16},
						childAlignment = {
							x = clay.LayoutAlignmentX.Center,
							y = clay.LayoutAlignmentY.Center,
						},
						layoutDirection = .TopToBottom,
					},
					backgroundColor = COLOR_PURPLE_800,
				},
			)

			switch state.client.game.status {
			case .Lobby:
				fallthrough
			case .Started:
				switch state.client.ui.current_menu {
				case .MainMenu:
					ui_component_menu()
				case .Lobby:
					ui_component_lobby()
				case .Join:
					ui_component_join()
				}
			case .GameOver:
				ui_component_game_over()
			case .GameWon:
				ui_component_game_won()
			}
		}
	}

	return clay.EndLayout()
}

HoverProc :: proc "c" (
	element_id: clay.ElementId,
	pointer_data: clay.PointerData,
	user_data: rawptr,
)

UiButtonProps :: struct {
	disabled:           bool,
	text:               string,
	on_hover:           HoverProc,
	on_hover_user_data: rawptr,
}
ui_button :: proc(props: UiButtonProps) {
	if clay.UI()(
	{
		layout = {
			childAlignment = {x = clay.LayoutAlignmentX.Center},
			padding = {16, 16, 8, 8},
			sizing = {width = clay.SizingGrow({})},
		},
		backgroundColor = props.disabled ? COLOR_GRAY_700 : (clay.Hovered() ? COLOR_PURPLE_200 : COLOR_PURPLE_500),
	},
	) {
		if !props.disabled && props.on_hover != nil do clay.OnHover(props.on_hover, props.on_hover_user_data)

		clay.TextDynamic(
			props.text,
			clay.TextConfig(
				{
					textColor = props.disabled ? COLOR_GRAY_200 : COLOR_WHITE,
					fontSize = FONT_SIZE_BASE,
				},
			),
		)
	}
}

ui_tooltip_latch := false

ui_layout_tooltip :: proc() -> clay.ClayArray(clay.RenderCommand) {
	context.temp_allocator = arena_ui_frame.allocator
	clay.BeginLayout()

	entities_at_cursor := derived_entities_at(state.client.cursor_pos, ignore_out_of_bounds = true)
	hover_entity, has_hover_entity := prism.maybe_any(
		^Entity,
		[]Maybe(^Entity){entities_at_cursor.obstacle, entities_at_cursor.ground},
	).?

	if !ui_tooltip_latch && state.t - state.client.cursor_last_moved < 0.5 do return clay.EndLayout()

	if state.client.cursor_over_ui || (!has_hover_entity && !state.debug.render_debug_overlays) {
		ui_tooltip_latch = false
		return clay.EndLayout()
	}

	ui_tooltip_latch = true

	default_text_config := clay.TextConfig({textColor = COLOR_WHITE, fontSize = FONT_SIZE_BASE})

	if clay.UI()(
	{
		id = clay.ID("TooltipSizer"),
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingFit({}), height = clay.SizingFit({})},
			padding = {2, 2, 2, 2},
		},
		backgroundColor = COLOR_PURPLE_200,
	},
	) {
		if clay.UI()(
		{
			id = clay.ID("TooltipPadder"),
			layout = {layoutDirection = .TopToBottom, padding = {8, 8, 8, 8}, childGap = 4},
			backgroundColor = COLOR_PURPLE_500,
		},
		) {

			if clay.UI()(
			{
				id = clay.ID("MinWidth"),
				layout = {sizing = {width = clay.SizingFixed(200)}},
				backgroundColor = COLOR_RED,
			},
			) {

			}
			if has_hover_entity {
				player, is_player := player_from_entity(hover_entity).?

				if is_player {
					clay.TextDynamic(
						prism.bufstring_as_str(&player.display_name),
						default_text_config,
					)
				} else {
					_add_fmt_text("%s", hover_entity.meta_id, size = FONT_SIZE_BASE)
				}

				if hover_entity.meta.base_action_cost < 100 {
					clay.Text(
						"Fast",
						clay.TextConfig(
							{textColor = COLOR_LIGHT_YELLOW, fontSize = FONT_SIZE_BASE},
						),
					)
				}
				if hover_entity.meta.base_action_cost > 100 {
					clay.Text(
						"Slow",
						clay.TextConfig(
							{textColor = COLOR_LIGHT_GREEN, fontSize = FONT_SIZE_BASE},
						),
					)
				}
				if hover_entity.meta.max_hp > 0 do _add_fmt_text("HP: %d/%d", hover_entity.hp, hover_entity.meta.max_hp, color = COLOR_LIGHT_RED)
				if len(hover_entity.meta.flavor_text) > 0 {
					// _vertical_spacer(4)
					clay.TextDynamic(
						hover_entity.meta.flavor_text,
						clay.TextConfig(
							{textColor = COLOR_GRAY_200, fontSize = default_text_config.fontSize},
						),
					)
				}

				if state.debug.render_debug_overlays {
					_vertical_spacer(16)
					_add_fmt_text("ID: %d", hover_entity.id)
					_add_fmt_text("Player ID: %d", hover_entity.player_id)
					_add_fmt_text("AP: %d", hover_entity.action_points)
					_add_fmt_text("%w", hover_entity.status_effects)
					_add_fmt_text("%v", hover_entity.cmd)
					_add_fmt_text("%v", hover_entity.meta.flags)
				}
			}

			if state.debug.render_debug_overlays {
				_vertical_spacer(16)
				tile, valid_tile := tile_at(state.client.cursor_pos).?
				if valid_tile {
					_add_fmt_text("%s", tile.type, size = FONT_SIZE_BASE)
					_add_fmt_text("%w", tile.flags, size = FONT_SIZE_BASE)
					if tile.fire.fuel > 0 do _add_fmt_text("%v", tile.fire, size = FONT_SIZE_BASE)
				} else {
					_add_fmt_text("Out of bounds")
				}
			}
		}
	}
	return clay.EndLayout()
}

_vertical_spacer :: proc(size: f32 = 8) {
	if clay.UI()({layout = {sizing = {height = clay.SizingFixed(size)}}}) {}

}

_add_fmt_text :: proc(
	fmtstr: string,
	args: ..any,
	color: [4]f32 = COLOR_WHITE,
	size: u16 = FONT_SIZE_BASE,
) {
	text := fmt.tprintf(fmtstr, ..args)
	clay.TextDynamic(text, clay.TextConfig({textColor = color, fontSize = size}))
}
