local SysTime = SysTime
local Color = Color
local tostring = tostring
local cam_Start2D = cam.Start2D
local cam_IgnoreZ = cam.IgnoreZ
local Vector = Vector
local math_Clamp = math.Clamp
local EyePos = EyePos
local surface_SetFont = surface.SetFont
local surface_GetTextSize = surface.GetTextSize
local draw_DrawText = draw.DrawText
local string_format = string.format
local input_GetCursorPos = input.GetCursorPos
local vgui_CursorVisible = vgui.CursorVisible
local ScrW = ScrW
local ScrH = ScrH
local input_LookupBinding = input.LookupBinding
local LocalPlayer = LocalPlayer
local input_IsMouseDown = input.IsMouseDown
local cam_End2D = cam.End2D
local FrameNumber = FrameNumber
local table_insert = table.insert
local table_remove = table.remove

local pac_max_render_time = CreateClientConVar("pac_max_render_time", 0)

function pac.IsRenderTimeExceeded(ent)
	return ent.pac_render_time_exceeded
end

function pac.RecordRenderTime(ent, type, start)
	local took = SysTime() - start

	local max_render_time = pac_max_render_time:GetFloat()
	if max_render_time <= 0 then return end

	local entTbl = ent:GetTable()
	if not entTbl.pac_rendertimes then
		entTbl.pac_rendertimes = {}
		entTbl.pac_lastframe = 0
	end

	if entTbl.pac_lastframe ~= FrameNumber() then
		table_insert(entTbl.pac_rendertimes, 1, took)
		entTbl.pac_lastframe = FrameNumber()
	else
		entTbl.pac_rendertimes[1] = entTbl.pac_rendertimes[1] + took
	end

	if #entTbl.pac_rendertimes > 10 then
		table_remove(entTbl.pac_rendertimes)
	end

	local avg = 0
	local timesCount = #entTbl.pac_rendertimes
	for i = 1, timesCount do
		avg = avg + entTbl.pac_rendertimes[i]
	end
	avg = avg / timesCount

	local exceededAvg = avg * 1000 > max_render_time
	if exceededAvg then
		pac.Message(Color(255, 50, 50), tostring(ent) .. ": max render time exceeded (" .. type .. " took " .. took * 1000 .. "ms, avg " .. avg * 1000 .. "ms, max " .. max_render_time .. "ms)")
		if exceededAvg then
			ent.pac_render_time_exceeded = avg * 1000
		end
		pac.HideEntityParts(ent)
	end
end

function pac.DrawRenderTimeExceeded(ent)
	cam_Start2D()
	cam_IgnoreZ(true)
		local pos_3d = ent:NearestPoint(ent:EyePos() + ent:GetUp()) + Vector(0,0,5)
		local alpha = math_Clamp(pos_3d:Distance(EyePos()) * -1 + 500, 0, 500) / 500
		if alpha > 0 then
			local pos_2d = pos_3d:ToScreen()
			surface_SetFont("ChatFont")
			local _, h = surface_GetTextSize("|")

			draw_DrawText(
				string_format(
					"pac3 outfit took %.2f/%i ms to render",
					ent.pac_render_time_exceeded,
					pac_max_render_time:GetFloat()
				),
				"ChatFont",
				pos_2d.x,
				pos_2d.y,
				Color(255,255,255,alpha * 255),
				1
			)
			local x, y = pos_2d.x, pos_2d.y + h

			local mx, my = input_GetCursorPos()
			if not vgui_CursorVisible() then
				mx = ScrW() / 2
				my = ScrH() / 2
			end
			local dist = 200
			local hovering = mx > x - dist and mx < x + dist and my > y - dist and my < y + dist

			local button = vgui_CursorVisible() and "click" or ("press " .. (input_LookupBinding("+use") or "USE"))
			draw_DrawText(button .. " here to try again", "ChatFont", x, y, Color(255,255,255,alpha * (hovering and 255 or 100) ), 1)

			if hovering and LocalPlayer():KeyDown(IN_USE) or (vgui_CursorVisible() and input_IsMouseDown(MOUSE_LEFT)) then
				ent.pac_render_time_exceeded = nil
			end
		end

	cam_IgnoreZ(false)
	cam_End2D()
end