-- {{{ Requires
-- Standard lib
local gears 		= require "gears"
local awful 		= require "awful"
			  require "awful.autofocus"

-- Widget lib
local wibox 		= require "wibox"

-- Theme lib
local beautiful		= require "beautiful"

-- Notification lib
local naughty 		= require "naughty"
local menubar 		= require "menubar"
local hotkeys_popup	= require("awful.hotkeys_popup").widget

-- Enable hotkeys help widget for vim and other things
			  require "awful.hotkeys_popup.keys"

-- Custom things
local system 		= require "system"
local layout		= require "layout"
-- }}}

-- {{{ Error handling from default rc.lua

-- Check for startup errors
if awesome.startup_errors then
	naughty.notify({ preset = naughty.config.presets.critical,
			 title  = "Errors during startup",
			 text   = awesome.startup_errors })
end

-- Handle runtime errors
do
	local in_error = false
	awesome.connect_signal("debug::error",
		function(err)
			-- Make sure function doesnt call itself
			if in_error then return end
			in_error = true

			naughty.notify({ preset = naughty.config.presets.critical,
					 title  = "Error Occured",
					 text   = tostring(err) })
		end)
end

-- }}}

-- {{{ Themes and defaults

-- Use custom theme
beautiful.init("~/.config/awesome/theme.lua")
local icon_path = "/home/corey/.config/awesome/icons/"

-- Set Wallpaper
for s = 1, screen.count() do
	gears.wallpaper.maximized(beautiful.wallpaper, s, true)
end

-- Set default terminal and editor
terminal   = "urxvt"
editor     = os.getenv("EDITOR") or "nano"
editor_cmd = terminal .. " -e " .. editor

-- Set modkey to Win
modkey = "Mod4"

-- Layouts for window tiling
awful.layout.layouts = {
	layout,
}

-- function for adjusting gaps
local auto_change_gaps = false
local gap_sizes = {20, 10, 5, 0}
local current_gap_index = #gap_sizes
local function change_gaps(delta)
	current_gap_index = math.min(math.max(current_gap_index - delta, 1), #gap_sizes)
	beautiful.useless_gap = gap_sizes[current_gap_index]
	
	--[[
	-- show notification of new gap size
	naughty.notify{
		position = "top_middle",
		text = "Gap Size: "..beautiful.useless_gap,
		timeout = 1,
	}
	]]

	-- update clients
	for _, c in ipairs(client.get()) do
		c:emit_signal("property::window") -- fixes corners
		c:emit_signal("list")		  -- resizes windows
	end
end
beautiful.useless_gap = gap_sizes[current_gap_index]

-- }}}

-- {{{ Status Bar
menubar.utils.terminal = terminal
menubar.show_categories = false
-- create a wibox for each screen
local tags = {"1","2","3","4"}

awful.screen.connect_for_each_screen(function(s)
	local spacer = wibox.widget.textbox("  ")

	-- text clock
	s.clock = wibox.widget.textclock()


	-- Graph for RAM usage
	local ramgraph = wibox.widget.graph()
	ramgraph.forced_width = 36
	ramgraph.step_width = 6
	local ramclock = awful.widget.watch("echo :)", 10, function(_, stdout)
		local ram_info = system.memory.get_info()
		ramgraph.max_value = ram_info.total
		ramgraph:add_value( ram_info.used )
	end)
	local ram_icon = gears.color.recolor_image(icon_path .. "ram.png", beautiful.bg_focus)
	
	s.ram = wibox.widget{
		layout = wibox.layout.align.horizontal,
		{widget = wibox.widget.imagebox(ram_icon)	},
		{widget = ramgraph				},
		{widget = ramclock				}
	}

	-- Wifi Icon and Network Name
	local wifi_good_icon = icon_path .. "wifi.svg"
	local wifi_bad_icon = icon_path .. "wifi-off.svg"
	local wifi_icon_widget = wibox.widget.imagebox()
	s.wifi = wibox.widget {
		layout = wibox.layout.align.horizontal,
		{widget = wifi_icon_widget		},
		{	
			widget = awful.widget.watch("iwgetid -r", 60, function(widget, stdout)
				if stdout ~= "" then
					widget:set_text(" " .. stdout)
					wifi_icon_widget:set_image(
						gears.color.recolor_image(wifi_good_icon, beautiful.bg_focus)
					)
				else
					widget:set_text(" " ..  "Not Connected")
					wifi_icon_widget:set_image(gears.color.recolor_image(wifi_bad_icon, beautiful.bg_focus))
				end
			end),
		}
	}

	-- if a battery is present make an indicator for it
	local battery_percent = system.battery.get_percent() --or .12
	local update_battery_percent
	if battery_percent then
		local battery_text = wibox.widget.textbox("")
		local battery_bar  = wibox.widget.progressbar()
		local battery_icon = wibox.widget.imagebox(gears.color.recolor_image(icon_path .. "battery.svg", beautiful.bg_focus))
		function update_battery_percent()
			local battery_percent = system.battery.get_percent() -- or math.random()
			battery_bar.value = battery_percent
			battery_text.text = ("%.0f%%"):format(battery_percent*100)
		end

		s.batteryindicator = wibox.widget{
			layout = wibox.layout.align.horizontal,
			battery_icon, wibox.widget.textbox(" "),
			wibox.widget {
				layout = wibox.layout.stack,
				{ -- Progress Bar
					widget 		= battery_bar,
					max_value 	= 1,
					value		= battery_percent,
					paddings	= 1,
					border_width	= 1,
					border_color	= beautiful.border_color,
					shape		= function(cr, w, h)
								gears.shape.rounded_rect(cr, w, 5)
							  end,
					forced_width	= 25,
				},
				{ -- Percent Text
					widget 		= battery_text,
					text 		= ("%.0f%%"):format(battery_percent*100),
				},
				{ -- Watch to update text
					widget 		= awful.widget.watch("echo :)", 60, update_battery_percent)
				}
			}
		}
	end
	
	-- each screens tag layout
	awful.tag(tags, s, awful.layout.layouts[1])	
	-- tags	
	s.mytaglist = awful.widget.taglist(
		s, -- screen
		awful.widget.taglist.filter.all --filter
	)
	-- setup the bar
	s.statusbar = awful.wibar{ position = "top", screen = s }
	s.statusbar:setup {
		layout = wibox.layout.align.horizontal,
		{ -- Left Widgets
			layout = wibox.layout.fixed.horizontal,
			s.clock,
		},
		{ -- Center
			layout = wibox.layout.fixed.horizontal,
			wibox.widget.textbox(""),
		},
		{ -- Right Widgets
			layout = wibox.layout.fixed.horizontal,
			s.ram, spacer,
			s.wifi, 
			s.batteryindicator or wibox.widget.textbox(" "), 
			s.batteryindicator and spacer or wibox.widget.textbox(" "),
			s.mytaglist,
		},
	}
end)
-- }}}

-- {{{ Key Bindings 
--
-- Aliases for convenience 
local m 	= modkey
local crtl 	= "Control" 
local shft 	= "Shift" 
local alt 	= "Mod1"

globalkeys = gears.table.join(
--	awful.key(KEYS			FUNCTION			DESCRIPTION)
	awful.key({m},"s", 		hotkeys_popup.show_help, 	{description="show help", 
									 group="awesome"					}),
	
	awful.key({m,shft},"h",		awful.tag.viewprev, 		{description="view previous", 
									 group="tag"						}),

	awful.key({m,shft},"l", 	awful.tag.viewnext, 		{description="view next", 
									 group="tag"						}),
	
	awful.key({m},"k", 		function() 
						awful.client.focus.byidx(-1) 
					end, 				{description="focus previous by index", 
									 group="client"						}),
	
	awful.key({m},"j", 		function() 
						awful.client.focus.byidx(1) 
					end, 				{description="focus next by index", 
									 group="client"						}),
	-- Layouts
	awful.key({m,shft},"j",		function() 
						awful.client.swap.byidx(1)
					end,				{description	="swap with next client by index", 
									 group		="client"				}),
	awful.key({m,shft},"k",		function()
						awful.client.swap.byidx(-1)
					end,				{description	="swap with previous client by index", 
									 group		="client"				}),
	awful.key({m,crtl},"j", 	function()
						awful.screen.focus_relative(1)
					end,				{description	="focus the next screen",
									 group		="screen"				}),
	awful.key({m,crtl},"k", 	function()
						awful.screen.focus_relative(-1)
					end,				{description	="focus the previous screen",
									 group		="screen"				}),
	awful.key({m},"Return",		function()
						awful.spawn(terminal)
					end,				{description	="open a terminal",
									 group		="launcher"				}),
	
	awful.key({m,shft},"Return",	function()
						awful.spawn(terminal, {
							floating = true,
							tag = mouse.screen.selected_tag,
							placement = awful.placement.under_mouse
						})
					end,				{description	="open a floating terminal",
									 group		="launcher"				}),
	awful.key({m},"space",		function()
						awful.layout.inc(1)
					end,				{description	="Toggle tiling method",
									 group		="client"				}),

	awful.key({m,crtl},"r", 	awesome.restart,		{description	="restart awesome",
									 group		="awesome"				}),

	awful.key({m,shft},"q", 	awesome.quit,			{description	="quit awesome",
									 group		="awesome"				}),

	awful.key({m},"l", 		function()
						awful.tag.incmwfact(0.05)
					end,				{description	="increase width",
									 group		="layout"				}),

	awful.key({m},"h", 		function()
						awful.tag.incmwfact(-0.05)
					end,				{description	="decrease width",
									 group		="layout"				}),

	awful.key({m},"r", 		function()
						menubar.show()
					end,				{description	="run prompt",
									 group		="launcher"				}),
	awful.key({m},"g",		function() 
						change_gaps(1)
					end,				{description	="increase gaps",
									 group		="layout"				}),

	awful.key({m,shft},"g",		function() 
						change_gaps(-1)
					end,				{description	="decrease gaps",
									 group		="layout"				}),

	awful.key({m,alt},"g",		function()
						auto_change_gaps = not auto_change_gaps
					end, 				{description	="toggle auto gap size changes",
									 group		="layout"				})
)

clientkeys = gears.table.join(
	
	awful.key({m}, "f", 		function(c)
						c.fullscreen = not c.fullscreen
						c:raise()
					end,				{description	="toggle fullscreen",
									 group		="client"}),
	awful.key({m,shft},"c",		function(c) c:kill() end,	{description	="close",
									 group		="client"}),

	awful.key({m,crtl},"space", 	function(c) 
						awful.client.floating.toggle(c)
						c:emit_signal("request::titlebars")
						if c.floating then c:raise() else c:lower() end
					end,				{description	="toggle floating",
									 group		="client"}),
	
	awful.key({m,crtl},"Return",	function(c) 
						c:swap(awful.client.getmaster()) 
					end, 				{description	="swap with master",
									 group		="client"})
)


for i = 1, #tags do
	globalkeys = gears.table.join(
		globalkeys,
		awful.key({"Mod1"}, "#" .. i+9,
			function()
				local screen = awful.screen.focused()
				local tag    = screen.tags[i]
				if tag then
					tag:view_only()
				end
			end,
			{description = "view tag #"..i,
			 group	     = "tag"}
		),

		awful.key({m,shft}, "#" .. i+9,
			function()
				if client.focus then
					local tag = client.focus.screen.tags[i]
					if tag then
						client.focus:move_to_tag(tag)
					end
				end
			end,
			{description = "move focused client to tag #"..i,
			 group	     = "tag"}
		),

		awful.key({"Mod1",shft}, "#" .. i+9,
			function()
				local screen = awful.screen.focused()
				local tag    = screen.tags[i]
				if tag then
					awful.tag.viewtoggle(tag)
				end
			end,
			{description = "toggle tag #" .. i,
			 group	     = "tag"}
		),

		awful.key({m,crtl,shft}, "#" .. i+9,
			function()
				if client.focus then
					local tag = client.focus.screen.tags[i]
					if tag then
						client.focus:toggle_tag(tag)
					end
				end
			end,
			{description = "toggle focused client on tag #" .. i,
			 group	     = "tag"}
		)

	)
end

root.keys(globalkeys)

-- Floating window resizing with the mouse
clientbuttons = gears.table.join(
	awful.button({}, 1, function(c)
		c:emit_signal("request::activate", "mouse_click", {raise = true})
	end),
	awful.button({m}, 1, function(c)
		c:emit_signal("request::activate", "mouse_click", {raise = true})
		awful.mouse.client.move(c)
	end),
	awful.button({m}, 3, function(c)
		c:emit_signal("request::activate", "mouse_click", {raise = true})
		awful.mouse.client.resize(c)
	end)
)


-- }}}

-- {{{ Rules

awful.mouse.snap.edge_enabled = false

awful.rules.rules = {
	{rule = {},
	 properties = { border_width	= beautiful.border_width,
	 		border_color	= beautiful.border_normal,
			focus		= awful.client.focus.filter,
			raise		= true,
			keys		= clientkeys,
			buttons		= clientbuttons,
			screen		= awful.screen.preferred,
			honor_padding	= true,
			size_hints_honor= false,
			placement 	= awful.placement.no_offscreen }},

}
-- }}}

-- {{{ Signals

client.connect_signal("manage", 
	function(c)
		local client_amount = #client.get()
		if current_gap_index ~= client_amount and auto_change_gaps then
			change_gaps(current_gap_index - client_amount)
		end
		if awesome.startup and
		not c.size_hints.user_position then
			awful.placement.no_offscreen(c)
		end
		
		local buttons = gears.table.join(
			awful.button({}, 1, function()
				c:emit_signal("request::activate", "titlebar", {raise=true})
				awful.mouse.client.move(c)
			end),
			awful.button({}, 3, function()
				c:emit_signal("request::activate", "titlebar", {raise=true})
				awful.mouse.client.resize(c)
			end)
		)

		awful.titlebar(c):setup {
			{
				awful.titlebar.widget.iconwidget(c),
				layout = wibox.layout.fixed.horizontal,
			}, 
			{
				{
					align = "center",
					widget = awful.titlebar.widget.titlewidget(c),
				},
				buttons = buttons,
				layout = wibox.layout.flex.horizontal
			}, 
			{
				awful.titlebar.widget.closebutton(c),
				layout = wibox.layout.fixed.horizontal
			},
			layout = wibox.layout.align.horizontal
		}
		if not c.floating then
			c:lower()
			awful.titlebar.hide(c)
		end
	end
)

client.connect_signal("unmanage", function(c)
	local client_amount = #client.get()
	if current_gap_index ~= client_amount and auto_change_gaps then
		change_gaps(current_gap_index - client_amount)
	end
end)

client.connect_signal("property::window",
	function(c)
		if beautiful.useless_gap > 0 or c.floating then
			c.shape = function(cr, width, height)
				gears.shape.rounded_rect(cr, width, height, 10)
			end
		else
			c.shape = gears.shape.rect
		end
	end
)

-- Titlebar stuffs
client.connect_signal("request::titlebars", function(c)
	if c.floating then
		awful.titlebar.show(c)
	else
		awful.titlebar.hide(c)
	end
end)


-- Enable sloppy focus
client.connect_signal("mouse::enter",
	function(c)
		if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier and
		awful.client.focus.filter(c) then
			client.focus = c
		end
	end
)


-- Change border when focused
client.connect_signal("focus", 
	function(c)
		c.border_color = beautiful.border_focus
	end
)
client.connect_signal("unfocus",
	function(c)
		c.border_color = beautiful.border_normal
	end
)
-- }}}
