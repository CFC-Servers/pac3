local function add_expensive_submenu_load(pnl, callback)
	local old = pnl.OnCursorEntered
	pnl.OnCursorEntered = function(...)
		callback()
		pnl.OnCursorEntered = old
		return old(...)
	end
end

local function populate_pac(menu)
	do
		local menu, icon = menu:AddSubMenu("save", function() pace.SaveParts() end)
		menu:SetDeleteSelf(false)
		icon:SetImage(pace.MiscIcons.save)
		add_expensive_submenu_load(icon, function() pace.AddSaveMenuToMenu(menu) end)
	end

	do
		local menu, icon = menu:AddSubMenu("load", function() pace.LoadParts(nil, true) end)
		menu:SetDeleteSelf(false)
		icon:SetImage(pace.MiscIcons.load)
		add_expensive_submenu_load(icon, function() pace.AddSavedPartsToMenu(menu, true) end)
	end

	do
		local menu, icon = menu:AddSubMenu("wear", function() pace.WearParts() end)
		menu:SetDeleteSelf(false)
		icon:SetImage(pace.MiscIcons.wear)

		pace.PopulateWearMenu(menu)
	end

	do
		menu:AddOption("request", function() RunConsoleCommand("pac_request_outfits") pac.Message('Requesting outfits.') end):SetImage(pace.MiscIcons.replace)
	end

	do
		local menu, icon = menu:AddSubMenu("clear", function() end)
		icon:SetImage(pace.MiscIcons.clear)
		menu.GetDeleteSelf = function() return false end
		menu:AddOption("OK", function() pace.ClearParts() end):SetImage(pace.MiscIcons.clear)
	end

	menu:AddSpacer()

	do
		local help, help_pnl = menu:AddSubMenu("help", function() pace.ShowWiki() end)
		help.GetDeleteSelf = function() return false end
		help_pnl:SetImage(pace.MiscIcons.help)

		help:AddOption(
			"Getting Started",
			function() pace.ShowWiki("tutorial/editor") end
		):SetImage(pace.MiscIcons.info)
	end

	do
		menu:AddOption("exit", function() pace.CloseEditor() end):SetImage(pace.MiscIcons.exit)
	end
end

local function populate_view(menu)
	menu:AddOption("hide editor",
		function() pace.Call("ToggleFocus") chat.AddText("[PAC3] \"ctrl + e\" to get the editor back")
	end):SetImage("icon16/application_delete.png")

	menu:AddCVar("camera follow: "..GetConVar("pac_camera_follow_entity"):GetInt(), "pac_camera_follow_entity", "1", "0"):SetImage("icon16/camera_go.png")
	menu:AddCVar("enable editor camera: "..GetConVar("pac_enable_editor_view"):GetInt(), "pac_enable_editor_view", "1", "0"):SetImage("icon16/camera.png")
	menu:AddOption("reset view position", function() pace.ResetView() end):SetImage("icon16/camera_link.png")
	menu:AddOption("reset zoom", function() pace.ResetZoom() end):SetImage("icon16/magnifier.png")
end

local function populate_options(menu)
	menu:AddOption("settings", function() pace.OpenSettings() end)
	menu:AddCVar("inverse collapse/expand controls", "pac_reverse_collapse", "1", "0")
	menu:AddCVar("enable shift+move/rotate clone", "pac_grab_clone", "1", "0")
	menu:AddCVar("remember editor position", "pac_editor_remember_position", "1", "0")
	menu:AddCVar("show parts IDs", "pac_show_uniqueid", "1", "0")
	menu:AddSpacer()
	menu:AddOption("position grid size", function()
		Derma_StringRequest("position grid size", "size in units:", GetConVarNumber("pac_grid_pos_size"), function(val)
			RunConsoleCommand("pac_grid_pos_size", val)
		end)
	end)
	menu:AddOption("angles grid size", function()
		Derma_StringRequest("angles grid size", "size in degrees:", GetConVarNumber("pac_grid_ang_size"), function(val)
			RunConsoleCommand("pac_grid_ang_size", val)
		end)
	end)
	menu:AddCVar("render attachments as bones", "pac_render_attachments", "1", "0").DoClick = function() pace.ToggleRenderAttachments() end
	menu:AddSpacer()

	menu:AddCVar("automatic property size", "pac_auto_size_properties", "1", "0")
	menu:AddCVar("enable language identifier in text fields", "pac_editor_languageid", "1", "0")
	pace.AddFontsToMenu(menu)

	menu:AddSpacer()

	local rendering, pnl = menu:AddSubMenu("rendering", function() end)
		rendering.GetDeleteSelf = function() return false end
		pnl:SetImage("icon16/camera_edit.png")
		rendering:AddCVar("no outfit reflections", "pac_optimization_render_once_per_frame", "1", "0")
end

local function populate_player(menu)
	local pnl = menu:AddOption("t pose", function() pace.SetTPose(not pace.GetTPose()) end):SetImage("icon16/user_go.png")
	menu:AddOption("reset eye angles", function() pace.ResetEyeAngles() end):SetImage("icon16/user_delete.png")
	menu:AddOption("reset zoom", function() pace.ResetZoom() end):SetImage("icon16/magnifier.png")

	-- this should be in pacx but it's kinda stupid to add a hook just to populate the player menu
	-- make it more generic
	if pacx and pacx.GetServerModifiers then
		local mods, pnl = menu:AddSubMenu("modifiers", function() end)
		pnl:SetImage("icon16/user_edit.png")
		mods.GetDeleteSelf = function() return false end
		for name in pairs(pacx.GetServerModifiers()) do
			mods:AddCVar(name, "pac_modifier_" .. name, "1", "0")
		end
	end
end

function pace.OnMenuBarPopulate(bar)
	for k,v in pairs(bar.Menus) do
		v:Remove()
	end

	populate_pac(bar:AddMenu("pac"))
	populate_view(bar:AddMenu("view"))
	populate_options(bar:AddMenu("options"))
	populate_player(bar:AddMenu("player"))
	pace.AddToolsToMenu(bar:AddMenu("tools"))

	bar:RequestFocus(true)
end

function pace.OnOpenMenu()
	local menu = DermaMenu()
	menu:SetPos(input.GetCursorPos())

	populate_player(menu) menu:AddSpacer()
	populate_view(menu) menu:AddSpacer()
	populate_options(menu) menu:AddSpacer()
	populate_pac(menu) menu:AddSpacer()

	local menu, pnl = menu:AddSubMenu("tools")
	pnl:SetImage("icon16/plugin.png")
	pace.AddToolsToMenu(menu)

	menu:MakePopup()
end
