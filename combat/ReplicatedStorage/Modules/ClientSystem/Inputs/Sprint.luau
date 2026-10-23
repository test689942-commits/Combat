--// Services \\--

local UserInputService = game:GetService("UserInputService")

--// Setup \\--

local Client = require(script.Parent.Parent)
local Movement = require(script.Parent.Parent.Movement)

local LastTapped = false
local Active = false

--// Sprint Input (Double-tap W) \\--

return function(Input: InputObject, Key: string)
	if Input.UserInputState ~= Enum.UserInputState.Begin then
		return
	end

	if not LastTapped then
		LastTapped = true
		task.delay(0.2, function()
			LastTapped = false
		end)
		return
	end

	local Character: Model = Client.Character
	local Humanoid: Humanoid = Client.Humanoid

	if not Character or not Humanoid or Humanoid.Health <= 0 then
		return
	end

	Active = true
	Movement.SetSprint(true)

	local Connection: RBXScriptConnection? = nil
	Connection = UserInputService.InputEnded:Connect(function(EndedInput: InputObject)
		if EndedInput.KeyCode ~= Input.KeyCode then
			return
		end

		if Connection then
			Connection:Disconnect()
			Connection = nil
		end

		if not Active then
			return
		end

		Active = false
		Movement.SetSprint(false)
	end)
end
