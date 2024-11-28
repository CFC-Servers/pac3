local MUTATOR = {}

MUTATOR.ClassName = "blood_color"

function MUTATOR:WriteArguments(enum)
	assert(enum >= -1 and enum <= 6, "invalid blood color")
	net.WriteUInt(enum, 3)
end

function MUTATOR:ReadArguments()
	return net.ReadUInt(3)
end

if SERVER then
	function MUTATOR:StoreState()
		return self.Entity:GetBloodColor()
	end

	function MUTATOR:Mutate(enum)
		self.Entity:SetBloodColor(enum)
	end
end

pac.emut.Register(MUTATOR)