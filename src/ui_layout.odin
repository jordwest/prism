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
COLOR_PURPLE_800 :: clay.Color{45, 32, 59, 255}
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
ui_layout_create :: proc() -> clay.ClayArray(clay.RenderCommand) {
	// Begin constructing the layout.
	clay.BeginLayout()

	// An example of laying out a UI with a fixed-width sidebar and flexible-width main content
	// NOTE: To create a scope for child components, the Odin API uses `if` with components that have children
	if clay.UI()(
	{
		id = clay.ID("OuterContainer"),
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
			padding = {16, 16, 16, 16},
			childGap = 16,
		},
		// backgroundColor = {250, 250, 255, 0},
	},
	) {
		if clay.UI()(
		{
			id = clay.ID("SideBar"),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {
					width = clay.SizingFixed(300 + math.cos(state.t * 0.2) * 100),
					height = clay.SizingGrow({}),
				},
				padding = {16, 16, 16, 16},
				childGap = 16,
			},
			backgroundColor = COLOR_LIGHT,
		},
		) {
			if clay.UI()(
			{
				id = clay.ID("ProfilePictureOuter"),
				layout = {
					layoutDirection = clay.LayoutDirection.TopToBottom,
					sizing = {width = clay.SizingGrow({})},
					padding = {16, 16, 16, 16},
					childGap = 16,
					childAlignment = {y = .Center},
				},
				backgroundColor = COLOR_RED,
				cornerRadius = {6, 6, 6, 6},
			},
			) {
				if clay.UI()(
				{
					id = clay.ID("ProfilePicture"),
					layout = {
						sizing = {width = clay.SizingFixed(60), height = clay.SizingFixed(60)},
					},
					// image = {
					// 	// How you define `profile_picture` depends on your renderer.
					// 	imageData = &profile_picture,
					// 	sourceDimensions = {width = 60, height = 60},
					// },
				},
				) {}
				if clay.UI()(
				{
					id = clay.ID("Sizer"),
					layout = {
						sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
					},
					backgroundColor = COLOR_LIGHT,
				},
				) {
					clay.Text(
						"Here's some text inside the sizing area",
						clay.TextConfig({textColor = COLOR_BLACK, fontSize = 32}),
					)
				}
				if clay.UI()(
				{
					id = clay.ID("Textual"),
					layout = {
						sizing = {
							width  = clay.SizingGrow({}),
							height = clay.SizingGrow({}), // + math.sin(state.t) * 20),
						},
					},
					backgroundColor = clay.Hovered() ? COLOR_LIGHT : COLOR_ORANGE,
				},
				) {

					count := int(42 + 50 + math.sin(state.t) * 50)
					fresnel.metric_i32("count", i32(count))
					chars := _test_ui_text_buf[:count]
					for x := 0; x < count; x += 1 {
						if x % 5 == 0 {
							chars[x] = ' '
						} else {
							chars[x] = u8(x)
						}
					}

					clay.TextDynamic(
						string(chars), // "Clay - A UI Library with text wrapping",
						clay.TextConfig({textColor = COLOR_BLACK, fontSize = 16}),
					)
				}

			}

			// Standard Odin code like loops, etc. work inside components.
			// Here we render 5 sidebar items.
			for i in u32(0) ..< 5 {
				sidebar_item_component(i)
			}
		}

		if clay.UI()(
		{
			id = clay.ID("MainContent"),
			layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})}},
			backgroundColor = COLOR_LIGHT,
		},
		) {
			clay.Text("One ", clay.TextConfig({textColor = COLOR_BLACK, fontSize = 16}))
			clay.Text("Two", clay.TextConfig({textColor = COLOR_BLACK, fontSize = 16}))
			clay.Text(" Three", clay.TextConfig({textColor = COLOR_BLACK, fontSize = 16}))
		}
	}

	// Returns a list of render commands
	return clay.EndLayout()
} // An example function to create your layout tree

ui_tooltip_latch := false

ui_tooltip_layout :: proc() -> clay.ClayArray(clay.RenderCommand) {
	context.temp_allocator = arena_ui_frame.allocator
	clay.BeginLayout()

	entities_at_cursor := derived_entities_at(state.client.cursor_pos, ignore_out_of_bounds = true)
	hover_entity, has_hover_entity := prism.maybe_any(
		^Entity,
		[]Maybe(^Entity){entities_at_cursor.obstacle, entities_at_cursor.ground},
	).?

	if !ui_tooltip_latch && state.t - state.client.cursor_last_moved < 0.5 do return clay.EndLayout()

	if !has_hover_entity {
		ui_tooltip_latch = false
		return clay.EndLayout()
	}

	ui_tooltip_latch = true

	default_text_config := clay.TextConfig({textColor = COLOR_WHITE, fontSize = 16})

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
			backgroundColor = COLOR_PURPLE_800,
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
				_add_fmt_text("%s", hover_entity.meta_id, size = 16)
				if .IsFast in hover_entity.meta.flags {
					clay.Text(
						"Fast",
						clay.TextConfig({textColor = COLOR_LIGHT_YELLOW, fontSize = 16}),
					)
				}
				if .IsSlow in hover_entity.meta.flags {
					clay.Text(
						"Slow",
						clay.TextConfig({textColor = COLOR_LIGHT_GREEN, fontSize = 16}),
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
					_add_fmt_text("AP: %d", hover_entity.action_points)
					_add_fmt_text("%v", hover_entity.cmd)
					_add_fmt_text("%v", hover_entity.meta.flags)
				}
			}
		}
	}
	return clay.EndLayout()
}

_vertical_spacer :: proc(size: f32 = 8) {
	if clay.UI()({layout = {sizing = {height = clay.SizingFixed(size)}}}) {}

}

_add_fmt_text :: proc(fmtstr: string, args: ..any, color: [4]f32 = COLOR_WHITE, size: u16 = 16) {
	text := fmt.tprintf(fmtstr, ..args)
	clay.TextDynamic(text, clay.TextConfig({textColor = color, fontSize = size}))
}
