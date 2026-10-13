-- made by Morten and CapsAdmin

pac.webaudio = pac.webaudio or {}
local webaudio = pac.webaudio

webaudio.Streams = webaudio.Streams or {}

webaudio.FilterType =
{
	None     = 0,
	LowPass  = 1,
	HighPass = 2,
}

local listenerPosition, listenerAngle, listenerVelocity = Vector(), Angle(), Vector()
local lastListenerPosition, lastListenerPositionTime

pac.AddHook("RenderScene", "webaudio_3d", function(position, angle)
	listenerPosition         = position
	listenerAngle            = angle

	lastListenerPosition     = lastListenerPosition     or listenerPosition
	lastListenerPositionTime = lastListenerPositionTime or (CurTime() - FrameTime())

	listenerVelocity         = (listenerPosition - lastListenerPosition) / (CurTime() - lastListenerPositionTime)

	lastListenerPosition     = listenerPosition
	lastListenerPositionTime = CurTime()
end)

webaudio.Streams.STREAM = {}
local STREAM = webaudio.Streams.STREAM
STREAM.__index = STREAM

-- Identity
STREAM.Id                     = nil
STREAM.Url                    = "" -- ??

-- State
STREAM.Loaded                 = false

-- Audio
STREAM.SampleCount            = 0

-- Playback
STREAM.Paused                 = true
STREAM.SamplePosition         = 0
STREAM.MaxLoopCount           = nil

-- Playback speed
STREAM.PlaybackSpeed          = 1
STREAM.AdditivePitchModifier  = 0

-- Volume
STREAM.Panning                = 0
STREAM.Volume                 = 1
STREAM.AdditiveVolumeFraction = 0

-- 3d
STREAM.Use3d                  = nil
STREAM.UseDoppler             = true

STREAM.SourceEntity           = NULL
STREAM.SourcePosition         = nil
STREAM.LastSourcePosition     = nil
STREAM.LastSourcePositionTime = nil
STREAM.SourceVelocity         = nil
STREAM.SourceRadius           = 1000
STREAM.ListenerOutOfRadius    = false

local function DECLARE_PROPERTY(propertyName, javascriptSetterCode, defaultValue, filterFunction)
	STREAM[propertyName] = defaultValue

	STREAM["Set" .. propertyName] = function(self, value)
		if filterFunction then
			value = filterFunction(value, self)
		end

		self[propertyName] = value

		self:Call(javascriptSetterCode, value)
	end

	STREAM["Get" .. propertyName] = function(self, ...)
		return self[propertyName]
	end
end

-- Identity
function STREAM:GetId()
	return self.Id
end

function STREAM:SetId(id)
	self.Id = id
	return self
end

function STREAM:GetUrl()
	return self.Url
end

function STREAM:SetUrl(url)
	self.Url = url
	return self
end

-- State
function STREAM:IsLoaded()
	return self.Loaded
end

function STREAM:IsValid()
	return true
end

function STREAM:Remove()
	self.IsValid = function() return false end
end

-- Browser
-- only numbers and booleans may be formatted into browser JavaScript;
-- never interpolate raw values into the panel script
local function format_js_args(...)
	local args = {}

	for i = 1, select("#", ...) do
		local value = select(i, ...)

		if isnumber(value) then
			args[i] = value
		elseif isbool(value) then
			args[i] = value and "true" or "false"
		else
			return nil
		end
	end

	return args
end

local function format_js_code(self, fmt, ...)
	local args = format_js_args(...)

	if not args then
		webaudio.DebugPrint("refusing to format a non-number/boolean argument into browser JavaScript")
		return nil
	end

	return string.format("try { streams[%d]%s } catch(e) { lua.print(e.toString()) }", self:GetId(), string.format(fmt, unpack(args)))
end

function STREAM:Call(fmt, ...)
	if not self.Loaded then return end

	local code = format_js_code(self, fmt, ...)

	if code then
		webaudio.Browser.QueueJavascript(code)
	end
end

function STREAM:CallNow(fmt, ...)
	if not self.Loaded then return end

	local code = format_js_code(self, fmt, ...)

	if code then
		webaudio.Browser.RunJavascript(code)
	end
end

function STREAM:HandleBrowserMessage(messageType, ...)
	if messageType == "call" then
		self:HandleCallBrowserMessage(...)
	elseif messageType == "fft" then
		self:HandleFFTBrowserMessage(...)
	elseif messageType == "stop" then
		self.Paused = true
	elseif messageType == "return" then
		self.ReturnedValues = {...}
	elseif messageType == "loaded" then
		self:HandleLoadedBrowserMessage(...)
	elseif t == "position" then
		self:HandlePositionBrowserMessage(...)
	end
end

-- Playback
function STREAM:GetMaxLoopCount()
	return self.MaxLoopCount
end

function STREAM:SetMaxLoopCount(maxLoopCount)
	self:Call(".max_loop = %i", maxLoopCount == true and -1 or maxLoopCount == false and 1 or tonumber(maxLoopCount) or 1)
	self.MaxLoopCount = maxLoopCount
end

STREAM.SetLooping = STREAM.SetMaxLoopCount

function STREAM:GetSampleCount()
	return self.SampleCount
end

function STREAM:Pause()
	self.Paused = true
	self:CallNow(".play(false)")
end

function STREAM:Resume()
	self.Paused = false

	self:UpdatePlaybackSpeed()
	self:UpdateVolume()

	self:CallNow(".play(true)")
end

function STREAM:Start()
	self.Paused = false

	self:UpdatePlaybackSpeed()
	self:UpdateVolume()

	self:CallNow(".play(true, 0)")
end
STREAM.Play = STREAM.Start

function STREAM:Stop()
	self.Paused = true
	self:CallNow(".play(false, 0)")
end

function STREAM:Restart()
	self:SetSamplePosition(0)
end

function STREAM:SetPosition(positionFraction)
	self:SetSamplePosition((positionFraction % 1) * self:GetSampleCount())
end

DECLARE_PROPERTY("SamplePosition", ".position = %f", 0)

-- Playback speed
function STREAM:GetPlaybackSpeed()
	return self.PlaybackSpeed
end

function STREAM:GetAdditivePitchModifier()
	return self.AdditivePitchModifier
end

function STREAM:SetPlaybackSpeed(playbackSpeedMultiplier)
	if self.PlaybackSpeed == playbackSpeedMultiplier then return self end

	self.PlaybackSpeed = playbackSpeedMultiplier

	self:UpdatePlaybackSpeed()

	return self
end

function STREAM:SetAdditivePitchModifier(additivePitchModifier)
	if self.AdditivePitchModifier == additivePitchModifier then return self end

	self.AdditivePitchModifier = additivePitchModifier

	self:UpdatePlaybackSpeed()

	return self
end

function STREAM:UpdatePlaybackSpeed()
	self:Call(".speed = %f", self.PlaybackSpeed + self.AdditivePitchModifier)
end

-- Volume
function STREAM:GetPanning()
	return self.Panning
end

function STREAM:GetVolume()
	return self.Volume
end

function STREAM:GetAdditiveVolumeModifier()
	return self.AdditiveVolumeModifier
end

function STREAM:SetPanning(panning)
	if self.Panning == panning then return self end

	self.Panning = panning

	self:UpdateVolume()

	return self
end

function STREAM:SetVolume(volumeFraction)
	if self.Volume == volumeFraction then return self end

	self.Volume = volumeFraction

	self:UpdateVolume()

	return self
end

function STREAM:SetAdditiveVolumeModifier (additiveVolumeFraction)
	if self.AdditiveVolumeFraction == additiveVolumeFraction then return self end

	self.AdditiveVolumeFraction = additiveVolumeFraction

	self:UpdateVolume()

	return self
end

function STREAM:UpdateSourcePosition()
	if not self.SourceEntity:IsValid() then return end

	self.SourcePosition = self.SourceEntity:GetPos()
end

function STREAM:UpdateVolume()
	if self.Use3d then
		self:UpdateVolume3d()
	else
		self:UpdateVolumeFlat()
	end
end

function STREAM:UpdateVolumeFlat()
	self:Call(".vol_right = %f", (math.Clamp(1 + self.Panning, 0, 1) * self.Volume) + self.AdditiveVolumeFraction)
	self:Call(".vol_left  = %f", (math.Clamp(1 - self.Panning, 0, 1) * self.Volume) + self.AdditiveVolumeFraction)
end

function STREAM:UpdateVolume3d()
	self:UpdateSourcePosition()

	self.SourcePosition         = self.SourcePosition or Vector()

	self.LastSourcePosition     = self.LastSourcePosition     or self.SourcePosition
	self.LastSourcePositionTime = self.LastSourcePositionTime or (CurTime() - FrameTime())

	self.SourceVelocity         = (self.SourcePosition - self.LastSourcePosition) / (CurTime() - self.LastSourcePositionTime)

	self.LastSourcePosition     = self.SourcePosition
	self.LastSourcePositionTime = CurTime()

	local relativeSourcePosition = self.SourcePosition - listenerPosition
	local distanceToSource       = relativeSourcePosition:Length()

	if distanceToSource < self.SourceRadius then
		local pan = relativeSourcePosition:GetNormalized():Dot(listenerAngle:Right())
		local volumeFraction = math.Clamp(1 - distanceToSource / self.SourceRadius, 0, 1) ^ 1.5
		volumeFraction = volumeFraction * 0.75 * self.Volume

		self:Call(".vol_right = %f", (math.Clamp(1 + pan, 0, 1) * volumeFraction) + self.AdditiveVolumeFraction)
		self:Call(".vol_left  = %f", (math.Clamp(1 - pan, 0, 1) * volumeFraction) + self.AdditiveVolumeFraction)

		if self.UseDoppler then
			local relativeSourcePosition = self.SourcePosition - listenerPosition
			local relativeSourceVelocity = self.SourceVelocity - listenerVelocity
			local relativeSourceSpeed    = relativeSourcePosition:GetNormalized():Dot(-relativeSourceVelocity) * 0.0254

			self:Call(".speed = %f", (self.PlaybackSpeed + (relativeSourceSpeed / webaudio.SpeedOfSound)) + self.AdditivePitchModifier)
		end

		self.ListenerOutOfRadius = false
	else
		if not self.ListenerOutOfRadius then
			self:Call(".vol_right = 0")
			self:Call(".vol_left  = 0")
			self.ListenerOutOfRadius = true
		end
	end
end

-- Filtering
DECLARE_PROPERTY("FilterType",     ".filter_type = %i")
DECLARE_PROPERTY("FilterFraction", ".filter_fraction = %f", 0, function(num) return math.Clamp(num, 0, 1) end)

DECLARE_PROPERTY("Echo",         ".useEcho(%s)", false)
DECLARE_PROPERTY("EchoDelay",    ".setEchoDelay(Math.ceil(audio.sampleRate * %f))", 1, function(num) return math.max(num, 0) end)
DECLARE_PROPERTY("EchoFeedback", ".echo_feedback = %f", 0.75)

-- 3D
function STREAM:Enable3D(b)
	self.Use3d = b
end

function STREAM:EnableDoppler(b)
	self.UseDoppler = b
end

function STREAM:GetSourceEntity()
	return self.SourceEntity
end

function STREAM:SetSourceEntity(sourceEntity, doNotRemove)
	self.SourceEntity = sourceEntity

	if not doNotRemove then
		sourceEntity:CallOnRemove("webaudio_remove_stream_" .. tostring(self), function()
			if self:IsValid() then
				self:Remove()
			end
		end)
	end
end

function STREAM:GetSourcePosition()
	return self.SourcePosition
end

function STREAM:SetSourcePosition(vec)
	self.SourcePosition = vec
end

function STREAM:GetSourceVelocity()
	return self.SourceVelocity
end

function STREAM:SetSourceVelocity(vec)
	self.SourceVelocity = vec
end

function STREAM:GetSourceRadius()
	return self.SourceRadius
end

function STREAM:SetSourceRadius(sourceRadius)
	self.SourceRadius = sourceRadius
end

function STREAM:Think()
	if self.Paused then return end

	if self.Use3d then
		self:UpdateVolume3d() -- updates source position internally
	else
		self:UpdateSourcePosition()
	end
end

function STREAM:__newindex(key, val)
	if key == "OnFFT" then
		if isfunction(val) then
			self:Call(".usefft(true)")
		else
			self:Call(".usefft(false)")
		end
	end

	rawset(self, key, val)
end

function STREAM:__tostring()
	return string.format("stream[%p][%d][%s]", self, self:GetId(), self:GetUrl())
end

-- Internal browser message handlers
-- only whitelisted methods may be invoked from browser JavaScript;
-- the panel JS only ever calls the error callback
local browser_callable_methods = {OnError = true}

function STREAM:HandleCallBrowserMessage(methodName, ...)
	local method = browser_callable_methods[methodName] and self[methodName]

	if not isfunction(method) then return end

	method(self, ...)
end

function STREAM:HandleFFTBrowserMessage(serializeFFTData)
	-- the fft message carries an array of numbers: parse and validate it
	-- (the JS side should send plain comma separated numbers)
	local fftArray = {}

	for number in tostring(serializeFFTData):gmatch("[^,%s;]+") do
		number = tonumber(number)

		if not isnumber(number) or number ~= number or math.abs(number) == math.huge then
			webaudio.DebugPrint("invalid fft data received, dropping")
			return
		end

		fftArray[#fftArray + 1] = number

		if #fftArray > 1024 then
			webaudio.DebugPrint("too much fft data received, dropping")
			return
		end
	end

	if #fftArray == 0 then return end

	if isfunction(self.OnFFT) then
		self.OnFFT(fftArray)
	end
end

function STREAM:HandleLoadedBrowserMessage(sampleCount)
	self.Loaded = true

	self.SampleCount = sampleCount
	self:SetFilterType(0)

	if not self.Paused then
		-- self:Play()
	end

	self:SetMaxLoopCount(self:GetMaxLoopCount())
	self:SetEcho        (self:GetEcho        ())
	self:SetEchoFeedback(self:GetEchoFeedback())
	self:SetEchoDelay   (self:GetEchoDelay   ())

	if self.OnLoad then
		self:OnLoad()
	end
end

function STREAM:HandlePositionBrowserMessage(samplePosition)
	self.SamplePosition = samplePosition
end