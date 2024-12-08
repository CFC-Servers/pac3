local MUTATOR = {}

MUTATOR.ClassName = "blood_color"

function MUTATOR:WriteArguments(enum)
	if -1 > enum and enum > 6 then
		enum = 0
	end

	enum = enum + 1 -- Transfers -1
	net.WriteUInt(enum, 3)
end

function MUTATOR:ReadArguments()
	local int = net.ReadUInt(3)
	return int - 1
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