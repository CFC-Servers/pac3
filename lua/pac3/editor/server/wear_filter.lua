
util.AddNetworkString("pac_submit_acknowledged")
util.AddNetworkString("pac_update_wearfilter")
util.AddNetworkString("pac_update_wearfilter_singular_add")
util.AddNetworkString("pac_update_outfitfilter")
util.AddNetworkString("pac_update_outfitfilter_singular_add")

local function find_outfits(ply)
	for id, outfits in pairs(pace.Parts) do
		local owner = pac.ReverseHash(id, "Player")
		if owner:IsValid() then
			if owner == ply then
				return outfits
			end
		end
	end

	return {}
end

local function updateWearFilter(ply, ids)
	ply.pac_wearfilter_ids = ids

	for _, outfit in pairs(find_outfits(ply)) do
		if outfit.wear_filter then
			for _, id in ipairs(ids) do
				if not table.HasValue(outfit.wear_filter, id) then
					local ply = pac.ReverseHash(id, "Player")
					if ply:IsValid() then
						if ply.pac_requested_outfits and not ply.pac_gonna_receive_outfits then
							pace.SubmitPart(outfit, ply)
						end
					end
				end
			end
		end

		outfit.wear_filter = ids
	end
end

local function checkCooldown(ply, cooldownID, cooldownDisplay)
	local varNameCD = "pac_cooldown_" .. cooldownID
	local varNameLogCD = "pac_log_cooldown_" .. cooldownID
	local curCooldown = ply[varNameCD]

	if curCooldown and curCooldown > CurTime() then
		local logCooldown = ply[varNameLogCD]

		if logCooldown and logCooldown < CurTime() then
			pac.Message("Player ", ply, " tried to submit " .. cooldownDisplay .. " too quickly, dropping.")
			ply[varNameLogCD] = CurTime() + 1
		end

		return false
	end

	ply[varNameCD] = CurTime() + 5

	return true
end

local function clearCooldown(ply, cooldownID)
	ply["pac_cooldown_" .. cooldownID] = nil
end


pace.PCallNetReceive(net.Receive, "pac_update_wearfilter", function(len, ply)
	if not checkCooldown(ply, "wearfilter", "wear filters") then return end

	local sizeof = net.ReadUInt(8)

	if sizeof > game.MaxPlayers() then
		pac.Message("Player ", ply, " tried to submit extraordinary wear filter size of ", sizeof, ", dropping.")
		return
	end

	local ids = {}

	for i = 1, sizeof do
		table.insert(ids, net.ReadString())
	end

	updateWearFilter(ply, ids)
end)

pace.PCallNetReceive(net.Receive, "pac_update_wearfilter_singular_add", function(len, ply)
	if not checkCooldown(ply, "wearfilter_singular", "singular wear filters") then return end

	local ids = ply.pac_wearfilter_ids or {}
	local id = net.ReadString()
	if table.HasValue(ids, id) then return end

	table.insert(ids, id)
	ply.pac_wearfilter_ids = ids -- In case it was nil
	updateWearFilter(ply, ids)
end)

pace.PCallNetReceive(net.Receive, "pac_update_outfitfilter", function(len, ply)
	if not checkCooldown(ply, "outfitfilter", "outfit filters") then return end

	local sizeof = net.ReadUInt(8)

	if sizeof > game.MaxPlayers() then
		pac.Message("Player ", ply, " tried to submit extraordinary outfit filter size of ", sizeof, ", dropping.")
		return
	end

	local filter = {}

	for i = 1, sizeof do
		local p = player.GetBySteamID64(net.ReadString())

		if IsValid(p) then
			filter[p] = true
		end
	end

	ply.pac_outfit_ignore_lookup = filter
end)

pace.PCallNetReceive(net.Receive, "pac_update_outfitfilter_singular_add", function(len, ply)
	if not checkCooldown(ply, "outfitfilter_singular", "singular outfit filters") then return end

	local lookup = ply.pac_outfit_ignore_lookup or {}
	local p = player.GetBySteamID64(net.ReadString())
	if not IsValid(p) or lookup[p] then return end

	lookup[p] = true
	ply.pac_outfit_ignore_lookup = lookup -- In case it was nil
end)

function pace.UpdateWearFilters()
	for _, ply in player.Iterator() do
		clearCooldown(ply, "outfitfilter")
		clearCooldown(ply, "wearfilter")
	end

	net.Start("pac_update_outfitfilter")
	net.Broadcast()

	net.Start("pac_update_wearfilter")
	net.Broadcast()
end

-- For when a player joins the server.
function pace.UpdateWearFiltersSingular(ply)
	-- Technically could miss some messages due to cooldowns if 2+ players full load at the same time,
	-- but gmod load time variance should make this a non-issue.
	-- TODO: Needs thorough testing against map changes with high player count.
	for _, p in player.Iterator() do
		clearCooldown(p, "wearfilter_singular")
		clearCooldown(p, "outfitfilter_singular")
		clearCooldown(p, "outfitfilter")
		clearCooldown(p, "wearfilter")
	end

	local plys = player.GetHumans()
	table.RemoveByValue(plys, ply)

	net.Start("pac_update_wearfilter_singular_add")
	net.WriteString(pac.Hash(ply))
	net.Send(plys)

	net.Start("pac_update_outfitfilter_singular_add")
	net.WriteString(ply:SteamID())
	net.Send(plys)

	net.Start("pac_update_outfitfilter")
	net.Send(ply)

	net.Start("pac_update_wearfilter")
	net.Send(ply)
end
