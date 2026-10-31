--// Services \\--

local UserInputService = game:GetService("UserInputService")

--// Setup \\--

local Client = require(script.Parent.Parent)
local Movement = require(script.Parent.Parent.Movement)

local TAP_WINDOW = 0.2
local LastTapTime = 0
local Active = false
local ReleaseConnection: RBXScriptConnection? = nil

--// Sprint Input (double-tap W) \\--

local SprintInput = {}

SprintInput.InputBegan = function(Input: InputObject?, _Client: any)
	local now = os.clock()
	if LastTapTime == 0 or now - LastTapTime > TAP_WINDOW then
		LastTapTime = now
		return
	end

	LastTapTime = 0

	local Character: Model? = Client.Character
	local Humanoid: Humanoid? = Client.Humanoid
	if not Character or not Humanoid or Humanoid.Health <= 0 then
		return
	end

	Active = true
	Movement.SetSprint(true)

	if ReleaseConnection then
		ReleaseConnection:Disconnect()
		ReleaseConnection = nil
	end

	ReleaseConnection = UserInputService.InputEnded:Connect(function(EndedInput: InputObject)
		if Input and EndedInput.KeyCode ~= Input.KeyCode then
			return
		end

		if ReleaseConnection then
			ReleaseConnection:Disconnect()
			ReleaseConnection = nil
		end

		if Active then
			Active = false
			Movement.SetSprint(false)
		end
	end)
end

SprintInput.InputEnded = function(_Input: InputObject?, _Client: any)
	-- The release connection above covers the key-up after the activating tap.
end

SprintInput.InputChanged = function(_Input: InputObject?, _Client: any)
end

return SprintInput
