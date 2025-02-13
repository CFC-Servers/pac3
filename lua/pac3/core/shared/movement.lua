local movementConvar = CreateConVar("pac_free_movement", -1, CLIENT and {FCVAR_REPLICATED} or {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "allow players to modify movement. -1 apply only allow when noclip is allowed, 1 allow for all gamemodes, 0 to disable")

local default = {
	JumpHeight = 200,
	StickToGround = true,
	GroundFriction = 0.12,
	AirFriction = 0.01,
	Gravity = Vector(0,0,-600),
	Noclip = false,
	MaxGroundSpeed = 750,
	MaxAirSpeed = 1,
	AllowZVelocity = false,
	ReversePitch = false,
	UnlockPitch = false,
	VelocityToViewAngles = 0,
	RollAmount = 0,

	SprintSpeed = 750,
	RunSpeed = 300,
	WalkSpeed = 100,
	DuckSpeed = 25,

	FinEfficiency = 0,
	FinLiftMode = "normal",
	FinCline = false
}

if SERVER then
	util.AddNetworkString("pac_modify_movement")

	net.Receive("pac_modify_movement", function(len, ply)
		local cvar = movementConvar:GetInt()
		if cvar == 0 or (cvar == -1 and hook.Run("PlayerNoClip", ply, true)==false) then return end

		local str = net.ReadString()
		if str == "disable" then
			ply.pac_movement = nil
		else
			if default[str] ~= nil then
				local val = net.ReadType()
				if type(val) == type(default[str]) then
					ply.pac_movement = ply.pac_movement or table.Copy(default)
					ply.pac_movement[str] = val
				end
			end
		end
	end)
end

if CLIENT then
	local sensitivityConvar = GetConVar("sensitivity")
	pac.AddHook("InputMouseApply", "custom_movement", function(cmd, x,y, ang)
		local ply = pac.LocalPlayer
		local self = ply.pac_movement
		if not self then return end

		if ply:GetMoveType() == MOVETYPE_NOCLIP then
			if ply.pac_movement_viewang then
				ang.r = 0
				cmd:SetViewAngles(ang)
				ply.pac_movement_viewang = nil
			end
			return
		end

		if self.UnlockPitch then
			ply.pac_movement_viewang = ply.pac_movement_viewang or ang
			ang = ply.pac_movement_viewang

			local sens = sensitivityConvar:GetFloat() * 20
			x = x / sens
			y = y / sens

			if ang.p > 89 or ang.p < -89 then
				x = -x
			end

			ang.p = math.NormalizeAngle(ang.p + y)
			ang.y = math.NormalizeAngle(ang.y + -x)
		end

		if self.ReversePitch then
			ang.p = -ang.p
		end

		local vel = ply:GetVelocity()

		local roll = math.Clamp(vel:Dot(-ang:Right()) * self.RollAmount, -89, 89)
		if not vel:IsZero() then
			if vel:Dot(ang:Forward()) < 0 then
				vel = -vel
			end
			ang = LerpAngle(self.VelocityToViewAngles, ang, vel:Angle())
		end
		ang.r = roll

		cmd:SetViewAngles(ang)

		if self.UnlockPitch then
			return true
		end
	end)
end

local function badMovetype(ply)
	local mvtype = ply:GetMoveType()

	return mvtype == MOVETYPE_OBSERVER
		or mvtype == MOVETYPE_NOCLIP
		or mvtype == MOVETYPE_LADDER
		or mvtype == MOVETYPE_CUSTOM
		or mvtype == MOVETYPE_ISOMETRIC
end

local frictionConvar = GetConVar("sv_friction")
pac.AddHook("Move", "custom_movement", function(ply, mv)
	local plyTbl = ply:GetTable()
	local plyPacMove = plyTbl.pac_movement

	if not plyPacMove then
		if not plyTbl.pac_custom_movement_reset then
			if not badMovetype(ply) then
				ply:SetGravity(1)
				ply:SetMoveType(MOVETYPE_WALK)

				if plyTbl.pac_custom_movement_jump_height then
					ply:SetJumpPower(plyTbl.pac_custom_movement_jump_height)
					plyTbl.pac_custom_movement_jump_height = nil
				end
			end

			plyTbl.pac_custom_movement_reset = true
		end

		return
	end

	plyTbl.pac_custom_movement_reset = nil
	plyTbl.pac_custom_movement_jump_height = plyTbl.pac_custom_movement_jump_height or ply:GetJumpPower()

	if badMovetype(ply) then return end

	mv:SetForwardSpeed(0)
	mv:SetSideSpeed(0)
	mv:SetUpSpeed(0)

	ply:SetJumpPower(plyPacMove.JumpHeight)

	if plyPacMove.Noclip then
		ply:SetMoveType(MOVETYPE_NONE)
	else
		ply:SetMoveType(MOVETYPE_WALK)
	end

	ply:SetGravity(0.00000000000000001)

	local on_ground = ply:IsOnGround()

	if not plyPacMove.StickToGround then
		ply:SetGroundEntity(NULL)
	end

	local speed = plyPacMove.RunSpeed

	if mv:KeyDown(IN_SPEED) then
		speed = plyPacMove.SprintSpeed
	end

	if mv:KeyDown(IN_WALK) then
		speed = plyPacMove.WalkSpeed
	end

	if mv:KeyDown(IN_DUCK) then
		speed = plyPacMove.DuckSpeed
	end

--	speed = speed * FrameTime()

	local ang = mv:GetAngles()
	local vel = Vector()

	if on_ground and plyPacMove.StickToGround then
		ang.p = 0
	end

	if mv:KeyDown(IN_FORWARD) then
		vel = vel + ang:Forward()
	elseif mv:KeyDown(IN_BACK) then
		vel = vel - ang:Forward()
	end

	if mv:KeyDown(IN_MOVERIGHT) then
		vel = vel + ang:Right()
	elseif mv:KeyDown(IN_MOVELEFT) then
		vel = vel - ang:Right()
	end

	vel = vel:GetNormalized() * speed

	if plyPacMove.AllowZVelocity then
		if mv:KeyDown(IN_JUMP) then
			vel = vel + ang:Up() * speed
		elseif mv:KeyDown(IN_DUCK) then
			vel = vel - ang:Up() * speed
		end
	end

	if not plyPacMove.AllowZVelocity then
		vel.z = 0
	end

	local speed = vel

	local vel = mv:GetVelocity()

	if on_ground and not plyPacMove.Noclip and plyPacMove.StickToGround then -- work against ground friction
		local sv_friction = frictionConvar:GetInt()

		if sv_friction > 0 then
			sv_friction = 1 - (sv_friction * 15) / 1000
			vel = vel / sv_friction
		end
	end

	vel = vel + plyPacMove.Gravity * 0

	-- todo: don't allow adding more velocity to existing velocity if it exceeds
	-- but allow decreasing
	if not on_ground then
		local friction = plyPacMove.AirFriction
		friction = -(friction) + 1

		vel = vel * friction

		vel = vel + plyPacMove.Gravity * 0.015
		speed = speed:GetNormalized() * math.Clamp(speed:Length(), 0, plyPacMove.MaxAirSpeed)
		vel = vel + (speed * FrameTime()*(66.666*(-friction+1)))
	else
		local friction = plyPacMove.GroundFriction
		friction = -(friction) + 1

		vel = vel * friction

		speed = speed:GetNormalized() * math.min(speed:Length(), plyPacMove.MaxGroundSpeed)
		vel = vel + (speed * FrameTime()*(75.77*(-friction+1)))
		vel = vel + plyPacMove.Gravity * 0.015
	end

	if plyPacMove.FinEfficiency > 0 then -- fin
		local curvel = vel
		local curup = ang:Forward()

		local vec1 = curvel
		local vec2 = curup
		vec1 = vec1 - 2*(vec1:Dot(vec2))*vec2
		local sped = vec1:Length()

		local finalvec = curvel
		local modf = math.abs(curup:Dot(curvel:GetNormalized()))
		local nvec = (curup:Dot(curvel:GetNormalized()))

		if (plyPacMove.pln == 1) then

			if nvec > 0 then
				vec1 = vec1 + (curup * 10)
			else
				vec1 = vec1 + (curup * -10)
			end

			finalvec = vec1:GetNormalized() * (math.pow(sped, modf) - 1)
			finalvec = finalvec:GetNormalized()
			finalvec = (finalvec * plyPacMove.FinEfficiency) + curvel
		end

		if (plyPacMove.FinLiftMode ~= "none") then
			if (plyPacMove.FinLiftMode == "normal") then
				local liftmul = 1 - math.abs(nvec)
				finalvec = finalvec + (curup * liftmul * curvel:Length() * plyPacMove.FinEfficiency) / 700
			else
				local liftmul = (nvec / math.abs(nvec)) - nvec
				finalvec = finalvec + (curup * curvel:Length() * plyPacMove.FinEfficiency * liftmul) / 700
			end
		end

		finalvec = finalvec:GetNormalized()
		finalvec = finalvec * curvel:Length()

		if plyPacMove.FinCline then
			local trace = {
				start = mv:GetOrigin(),
				endpos = mv:GetOrigin() + Vector(0, 0, -1000000),
				mask = 131083
			}
			local trc = util.TraceLine(trace)

			local MatType = trc.MatType

			if (MatType == 67 or MatType == 77) then
				local heatvec = Vector(0, 0, 100)
				local cline = ((2 * (heatvec:Dot(curup)) * curup - heatvec)) * (math.abs(heatvec:Dot(curup)) / 1000)
				finalvec = finalvec + (cline * (plyPacMove.FinEfficiency / 50))
			end
		end

		vel = finalvec
	end

	mv:SetVelocity(vel)

	if plyPacMove.Noclip then
		mv:SetOrigin(mv:GetOrigin() + vel * 0.01)
	end

	return false
end)
