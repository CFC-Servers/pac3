local MUTATOR = {}

MUTATOR.ClassName = "model"
MUTATOR.UpdateRate = 0.25

local CL_MODEL_ONLY = CreateConVar('pac_cl_mdls', '0', CLIENT and {FCVAR_REPLICATED} or {FCVAR_ARCHIVE, FCVAR_REPLICATED}, 'Use CL models instead of serverside models.')

local function fixLP( ent )
	if not CL_MODEL_ONLY:GetBool() then return end
	if not CLIENT then return end
	if ent ~= LocalPlayer() then return end
	local original = ent:GetPredictable()
	ent:SetPredictable( not original )
	ent:SetPredictable( original )
end

function MUTATOR:WriteArguments(path)
	assert(isstring(path), "path must be a string")

	net.WriteString(path)
	net.WriteString(self.Entity:GetModel())
end

function MUTATOR:ReadArguments()
	return net.ReadString(), net.ReadString()
end

function MUTATOR:Update(val)
	if CL_MODEL_ONLY:GetBool() and SERVER then return end
	if not self.actual_model or not IsValid(self.Entity) then return end

	if self.Entity:GetModel():lower() ~= self.actual_model:lower() then
		self.Entity:SetModel(self.actual_model)
		fixLP(self.Entity)
	end
end

function MUTATOR:StoreState()
	return self.Entity:GetModel()
end

function MUTATOR:Mutate(path, svmodel)
	self.Entity.pac_sv_model = svmodel
	if path:find("^http") then
		if SERVER and pac.debug then
			if self.Owner:IsPlayer() then
				pac.Message(self.Owner, " wants to use ", path, " as model on ", ent)
			end
		end

		local ent_str = tostring(self.Entity)

		pac.DownloadMDL(path, function(mdl_path)
			if not self.Entity:IsValid() then
				pac.Message("cannot set model ", mdl_path, " on ", ent_str ,': entity became invalid')
				return
			end

			if SERVER and pac.debug then
				pac.Message(mdl_path, " downloaded for ", ent, ': ', path)
			end

			if CL_MODEL_ONLY:GetBool() then
				if self.Entity:IsPlayer() then
					if SERVER then
						util.PrecacheModel(mdl_path)
					end

					if CLIENT then
						self.Entity:SetModel(mdl_path)
						fixLP(self.Entity)
					end
				else
					self.Entity:SetModel(mdl_path)
				end
			else
				self.Entity:SetModel(mdl_path)
			end

			self.Entity.pac_modified_model = mdl_path
			self.actual_model = mdl_path

		end, function(err)
			pac.Message(err)
		end, self.Owner)
	else
		if path:EndsWith(".mdl") then
			self.Entity:SetModel(path)
			fixLP(self.Entity)
			self.Entity.pac_modified_model = nil

			if self.Owner:IsPlayer() and path:lower() ~= self.Entity:GetModel():lower() then
				self.Owner:ChatPrint('[PAC3] ERROR: ' .. path .. " is not a valid model on the server.")
			else
				self.actual_model = path
			end
		else
			local translated = player_manager.TranslatePlayerModel(path)
			self.Entity:SetModel(translated)
			fixLP(self.Entity)
			self.actual_model = translated
			self.Entity.pac_modified_model = nil
		end
	end
end

if CLIENT then
	local function forceModel( rag )
		local mdl = rag:GetModel()
		if not mdl then return end
		rag:InvalidateBoneCache()
		rag:SetModel( mdl )
		rag:InvalidateBoneCache()
	end

	local ragModels = {}
	local function renderRagdoll(rag)
		if rag.pac_modified_model then
			rag:SetModel(rag.pac_modified_model)

			if ragModels[rag] then
				rag:InvalidateBoneCache()
			end
		end

		rag:DrawModel()
	end

	hook.Add( "NetworkEntityCreated", "Pac_ModelMutatorCL", function( rag )
		if not CL_MODEL_ONLY:GetBool() then return end

		local class = rag:GetClass()
		if not string.find( class, "HL2MPRagdoll" ) then return end

		local ply = rag:GetRagdollOwner()
		if not IsValid( ply ) or not ply:IsPlayer() then return end
		if not ply.pac_modified_model then return end

		local model = ply.pac_modified_model
		if not model then return end

		rag.pac_modified_model = model
		forceModel( rag )
		ragModels[rag] = 50

		rag.RenderOverride = renderRagdoll
	end )

	local function retryModelFix()
		for rag, retry in pairs(ragModels) do
			if rag:IsValid() and retry > 0 then
				ragModels[rag] = retry - 1

				forceModel(rag)
			elseif ragModels[rag] then
				ragModels[rag] = nil
			end
		end
	end
	hook.Add("Think", "Pacific_ModelMutator", retryModelFix)

	hook.Add( "NotifyShouldTransmit", "PAC_ModelMutator", function( ent, shouldtransmit )
		if not shouldtransmit then return end
		if not CL_MODEL_ONLY:GetBool() then return end
		if not IsValid( ent ) then return end
		if not ent:IsPlayer() then return end

		if ent.pac_modified_model then
			ent:SetModel( ent.pac_modified_model )
			forceModel(ent)
		end
	end )
end

pac.emut.Register(MUTATOR)
