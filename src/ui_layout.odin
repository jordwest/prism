package main
import clay "clay-odin"
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
COLOR_LIGHT_RED :: clay.Color{255, 170, 170, 150}
COLOR_LIGHT_YELLOW :: clay.Color{255, 255, 170, 150}
COLOR_LIGHT_GREEN :: clay.Color{170, 255, 170, 150}
COLOR_PURPLE_800 :: clay.Color{20, 16, 24, 255}
COLOR_PURPLE_500 :: clay.Color{45, 32, 59, 255}
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

_test_ui_text_buf: [200]u8
// An example function to create your layout tree
ui_layout_screen :: proc() -> clay.ClayArray(clay.RenderCommand) {
	context.temp_allocator = arena_ui_frame.allocator
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
			clay.Text(
				"Inventory",
				clay.TextConfig({textColor = COLOR_GRAY_200, fontSize = FONT_SIZE_BASE}),
			)
			if state.host.is_host && state.client.game.status != .Started {

				if clay.UI()(
				{
					id = clay.ID("StartButton"),
					layout = {
						padding = {16, 16, 16, 16},
						sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
					},
					backgroundColor = clay.Hovered() ? COLOR_PURPLE_200 : COLOR_PURPLE_500,
				},
				) {
					clay.Text("Start", default_text_config)
				}
			}
			if clay.UI()(
			{
				id = clay.ID("InventoryList"),
				layout = {
					layoutDirection = .TopToBottom,
					sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
					childGap = 4,
				},
			},
			) {

				button_config: clay.ElementDeclaration = {
					layout = {padding = {16, 16, 8, 8}, sizing = {width = clay.SizingGrow({})}},
					backgroundColor = clay.Hovered() ? COLOR_PURPLE_200 : COLOR_PURPLE_500,
				}

				player_entity_id := state.client.controlling_entity_id
				inventory_iter := container_iterator(SharedLootContainer)
				activate_mode, is_activating_item := state.client.ui.mode.(UiActivatingItem)
				for item in container_iterate(&inventory_iter) {
					if clay.UI()(
					{
						layout = {padding = {4, 4, 4, 4}, sizing = {width = clay.SizingGrow({})}},
						backgroundColor = clay.Hovered() ? COLOR_PURPLE_500 : COLOR_PURPLE_800,
					},
					) {
						clay.OnHover(input_on_hover_inventory_item, item)
						switch t in item.type {
						case PotionType:
							_add_fmt_text("%d Potion of %s", item.count, item.type)
						}
					}

					if is_activating_item && activate_mode.item_id == item.id {
						if clay.UI()(
						{
							layout = {
								padding = {4, 4, 4, 4},
								sizing = {width = clay.SizingGrow({})},
								childGap = 8,
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

HoverProc :: proc "c" (
	element_id: clay.ElementId,
	pointer_data: clay.PointerData,
	user_data: rawptr,
)

UiButtonProps :: struct {
	text:               string,
	on_hover:           HoverProc,
	on_hover_user_data: rawptr,
}
ui_button :: proc(props: UiButtonProps) {
	if clay.UI()(
	{
		layout = {padding = {16, 16, 8, 8}, sizing = {width = clay.SizingGrow({})}},
		backgroundColor = clay.Hovered() ? COLOR_PURPLE_200 : COLOR_PURPLE_500,
	},
	) {
		if props.on_hover != nil do clay.OnHover(props.on_hover, props.on_hover_user_data)
		clay.TextDynamic(
			props.text,
			clay.TextConfig({textColor = COLOR_WHITE, fontSize = FONT_SIZE_BASE}),
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
					clay.TextDynamic(player.display_name, default_text_config)
				} else {
					_add_fmt_text("%s", hover_entity.meta_id, size = FONT_SIZE_BASE)
				}

				if .IsFast in hover_entity.meta.flags {
					clay.Text(
						"Fast",
						clay.TextConfig(
							{textColor = COLOR_LIGHT_YELLOW, fontSize = FONT_SIZE_BASE},
						),
					)
				}
				if .IsSlow in hover_entity.meta.flags {
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
