
util.AddNetworkString('pac_submit_acknowledged')
util.AddNetworkString('pac_update_wearfilter')
util.AddNetworkString('pac_update_outfitfilter')

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

pace.PCallNetReceive(net.Receive, "pac_update_wearfilter", function(len, ply)
	if ply.pac_wearfilter_cooldown and ply.pac_wearfilter_cooldown > CurTime() then
		if ply.pac_wearfilter_log_cooldown and ply.pac_wearfilter_log_cooldown < CurTime() then
			pac.Message("Player ", ply, " tried to submit wear filters too quickly, dropping.")
			ply.pac_wearfilter_log_cooldown = CurTime() + 1
		end

		return
	end

	ply.pac_wearfilter_cooldown = CurTime() + 5

	local sizeof = net.ReadUInt(8)

	if sizeof > game.MaxPlayers() then
		pac.Message("Player ", ply, " tried to submit extraordinary wear filter size of ", sizeof, ", dropping.")
		return
	end

	local ids = {}

	for i = 1, sizeof do
		table.insert(ids, net.ReadString())
	end

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
end)

pace.PCallNetReceive(net.Receive, "pac_update_outfitfilter", function(len, ply)
	if ply.pac_outfitfilter_cooldown and ply.pac_outfitfilter_cooldown > CurTime() then
		if ply.pac_outfitfilter_log_cooldown and ply.pac_outfitfilter_log_cooldown < CurTime() then
			pac.Message("Player ", ply, " tried to submit outfit filters too quickly, dropping.")
			ply.pac_outfitfilter_log_cooldown = CurTime() + 1
		end

		return
	end

	ply.pac_outfitfilter_cooldown = CurTime() + 5

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

function pace.UpdateWearFilters()
	for _, ply in player.Iterator() do
		ply.pac_wearfilter_cooldown = nil
		ply.pac_outfitfilter_cooldown = nil
	end

	net.Start('pac_update_wearfilter')
	net.Broadcast()

	net.Start('pac_update_outfitfilter')
	net.Broadcast()
end
