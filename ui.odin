package main
import clay "clay-odin"
import "core:math"

// Define some colors.
COLOR_LIGHT :: clay.Color{224, 215, 210, 255}
COLOR_RED :: clay.Color{168, 66, 28, 255}
COLOR_ORANGE :: clay.Color{225, 138, 50, 255}
COLOR_BLACK :: clay.Color{0, 0, 0, 255}

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

// An example function to create your layout tree
ui_create_layout :: proc() -> clay.ClayArray(clay.RenderCommand) {
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
		backgroundColor = {250, 250, 255, 255},
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
					chars := make([]u8, count)
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
		) {}
	}

	// Returns a list of render commands
	return clay.EndLayout()
} // An example function to create your layout tree
create_layout :: proc() -> clay.ClayArray(clay.RenderCommand) {
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
		backgroundColor = {250, 250, 255, 255},
	},
	) {
		if clay.UI()(
		{
			id = clay.ID("SideBar"),
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {width = clay.SizingFixed(300), height = clay.SizingGrow({})},
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
					sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(600)},
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

				clay.Text(
					"Clay - a UI Library with some really long text",
					clay.TextConfig({textColor = COLOR_BLACK, fontSize = 16}),
				)
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
		) {}
	}

	// Returns a list of render commands
	return clay.EndLayout()
}
