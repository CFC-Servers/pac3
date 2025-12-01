
util.AddNetworkString("pac_proxy")
util.AddNetworkString("pac_event")

-- event
concommand.Add("pac_event", function(ply, _, args)
	if not args[1] then return end

	local event = args[1]
	local extra = tonumber(args[2]) or 0

	if extra == 2 or args[2] == "toggle" then
		ply.pac_event_toggles = ply.pac_event_toggles or {}
		ply.pac_event_toggles[event] = not ply.pac_event_toggles[event]

		extra = ply.pac_event_toggles[event] and 1 or 0
	end

	net.Start("pac_event", true)
		net.WriteEntity(ply)
		net.WriteString(event)
		net.WriteInt(extra, 8)
	net.Broadcast()
end)

concommand.Add("+pac_event", function(ply, _, args)
	if not args[1] then return end

	if args[2] == "2" or args[2] == "toggle" then
		local event = args[1]
		ply.pac_event_toggles = ply.pac_event_toggles or {}
		ply.pac_event_toggles[event] = true

		net.Start("pac_event", true)
			net.WriteEntity(ply)
			net.WriteString(event)
			net.WriteInt(1, 8)
		net.Broadcast()
	else
		net.Start("pac_event", true)
			net.WriteEntity(ply)
			net.WriteString(args[1] .. "_on")
		net.Broadcast()
	end
end)

concommand.Add("-pac_event", function(ply, _, args)
	if not args[1] then return end

	if args[2] == "2" or args[2] == "toggle" then
		local event = args[1]
		ply.pac_event_toggles = ply.pac_event_toggles or {}
		ply.pac_event_toggles[event] = false
		net.Start("pac_event", true)
			net.WriteEntity(ply)
			net.WriteString(event)
			net.WriteInt(0, 8)
		net.Broadcast()
	else
		net.Start("pac_event", true)
			net.WriteEntity(ply)
			net.WriteString(args[1] .. "_off")
		net.Broadcast()
	end
end)

-- proxy
concommand.Add("pac_proxy", function(ply, _, args)
	str = args[1]
	if args[1] == nil then
		ply:PrintMessage(HUD_PRINTCONSOLE, "\npac_proxy needs at least two arguments.\nname\nnumber, or a series of numbers for a vector. increment notation is available, such as ++1 or --1.\ne.g. pac_proxy myvector 1 2 3\ne.g. pac_proxy value ++5")
		return
	end

	if ply:IsValid() then
		ply.pac_proxy_events = ply.pac_proxy_events or {}
	end
	local x
	local y
	local z
	if ply.pac_proxy_events[str] ~= nil then
		if args[2] then
			if string.sub(args[2],1,2) == "++" or string.sub(args[2],1,2) == "--" then
				x = ply.pac_proxy_events[str].x + tonumber(string.sub(args[2],2,#args[2]))
			else x = tonumber(args[2]) or ply.pac_proxy_events[str].x or 0 end
		end

		if args[3] then
			if string.sub(args[3],1,2) == "++" or string.sub(args[3],1,2) == "--" then
				y = ply.pac_proxy_events[str].y + tonumber(string.sub(args[3],2,#args[3]))
			else y = tonumber(args[3]) or ply.pac_proxy_events[str].y or 0 end
		end
		if not args[3] then y = 0 end

		if args[4] then
			if string.sub(args[4],1,2) == "++" or string.sub(args[4],1,2) == "--" then
				z = ply.pac_proxy_events[str].z + tonumber(string.sub(args[4],2,#args[4]))
			else z = tonumber(args[4]) or ply.pac_proxy_events[str].z or 0 end
		end
		if not args[4] then z = 0 end
	else
		x = tonumber(args[2]) or 0
		y = tonumber(args[3]) or 0
		z = tonumber(args[4]) or 0
	end
	ply.pac_proxy_events[str] = {name = str, x = x, y = y, z = z}

	net.Start("pac_proxy", true)
		net.WriteEntity(ply)
		net.WriteString(args[1])

		net.WriteFloat(x or 0)
		net.WriteFloat(y or 0)
		net.WriteFloat(z or 0)
	net.Broadcast()
end, nil,
[[pac_proxy sets the number of a command function in a proxy. it is typically accessed as command(\"value\") needs at least two arguments.
name: any name, preferably without spaces
numbers: a number, or a series of numbers for a vector. increment notation is available, such as ++1 and --1.
e.g. pac_proxy myvector 1 2 3
e.g. pac_proxy value ++5]])