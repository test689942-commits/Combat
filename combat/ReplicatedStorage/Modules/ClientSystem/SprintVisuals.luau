--// SPRINT VISUALS (Arm Trails, FOV Tween & Camera Sway) \\--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local SprintVisuals = {}

local BASE_FOV = 70
local SPRINT_FOV = 76
local FOV_TWEEN_TIME = 0.22

function SprintVisuals.Start(Character: Model)
	local Humanoid = Character:WaitForChild("Humanoid", 5) :: Humanoid?
	local RootPart = Character:WaitForChild("HumanoidRootPart", 5) :: BasePart?

	if not Humanoid or not RootPart then
		return function() end
	end

	if Players:GetPlayerFromCharacter(Character) ~= LocalPlayer then
		return function() end
	end

	local sprintTrails = {}
	local sprintAttachments = {}
	local renderConnection: RBXScriptConnection? = nil
	local sprintConnection: RBXScriptConnection? = nil
	local charSprintConnection: RBXScriptConnection? = nil
	local fovTween: Tween? = nil
	local cameraOffset = CFrame.new()
	local swayClock = 0

	local function isSprinting(): boolean
		return Humanoid:GetAttribute("Sprint") == true or Character:GetAttribute("Sprint") == true
	end

	local function getLimb(...: string): BasePart?
		for _, name in ipairs({...}) do
			local limb = Character:FindFirstChild(name)
			if limb and limb:IsA("BasePart") then
				return limb
			end
		end

		return nil
	end

	local function createTrail(limb: BasePart?)
		if not limb then
			return
		end

		local a0 = Instance.new("Attachment")
		a0.Name = "SprintTrail_A0"
		a0.Position = Vector3.new(0, 0.12, 0)
		a0.Parent = limb

		local a1 = Instance.new("Attachment")
		a1.Name = "SprintTrail_A1"
		a1.Position = Vector3.new(0, -0.12, 0)
		a1.Parent = limb

		local trail = Instance.new("Trail")
		trail.Name = "SprintTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.14
		trail.MinLength = 0.05
		trail.LightEmission = 0.45
		trail.LightInfluence = 0
		trail.FaceCamera = false
		trail.Color = ColorSequence.new(Color3.fromRGB(235, 244, 255))
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.72),
			NumberSequenceKeypoint.new(0.45, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 0),
		})
		trail.Enabled = false
		trail.Parent = limb

		table.insert(sprintAttachments, a0)
		table.insert(sprintAttachments, a1)
		table.insert(sprintTrails, trail)
	end

	local function ensureTrails()
		if #sprintTrails > 0 then
			return
		end

		createTrail(getLimb("Left Arm", "LeftHand", "LeftLowerArm"))
		createTrail(getLimb("Right Arm", "RightHand", "RightLowerArm"))
	end

	local function setTrailsEnabled(enabled: boolean)
		for _, trail in ipairs(sprintTrails) do
			if trail.Parent then
				trail.Enabled = enabled
			end
		end
	end

	local function destroyTrails()
		for _, trail in ipairs(sprintTrails) do
			if trail.Parent then
				trail:Destroy()
			end
		end

		for _, attachment in ipairs(sprintAttachments) do
			if attachment.Parent then
				attachment:Destroy()
			end
		end

		table.clear(sprintTrails)
		table.clear(sprintAttachments)
	end

	local function removeCameraOffset()
		local camera = workspace.CurrentCamera
		if camera then
			camera.CFrame = camera.CFrame * cameraOffset:Inverse()
		end
		cameraOffset = CFrame.new()
	end

	local function tweenFov(targetFov: number)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		if fovTween then
			fovTween:Cancel()
		end

		fovTween = TweenService:Create(
			camera,
			TweenInfo.new(FOV_TWEEN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{FieldOfView = targetFov}
		)
		fovTween:Play()
	end

	local function startCameraMotion()
		if renderConnection then
			return
		end

		renderConnection = RunService.RenderStepped:Connect(function(dt)
			local camera = workspace.CurrentCamera
			if not camera or not RootPart.Parent then
				return
			end

			camera.CFrame = camera.CFrame * cameraOffset:Inverse()

			local horizontalVelocity = Vector3.new(RootPart.AssemblyLinearVelocity.X, 0, RootPart.AssemblyLinearVelocity.Z).Magnitude
			local sprinting = isSprinting()
			local intensity = sprinting and math.clamp((horizontalVelocity - 8) / 18, 0, 1) or 0

			swayClock += dt * (7.5 + horizontalVelocity * 0.08)
			local side = math.sin(swayClock) * 0.024 * intensity
			local lift = math.abs(math.cos(swayClock * 0.5)) * 0.018 * intensity
			local roll = math.rad(math.sin(swayClock) * 0.35 * intensity)

			cameraOffset = CFrame.new(side, lift, 0) * CFrame.Angles(0, 0, roll)
			camera.CFrame = camera.CFrame * cameraOffset
		end)
	end

	local function stopCameraMotion()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end

		removeCameraOffset()
	end

	local function onSprintChanged()
		if isSprinting() then
			ensureTrails()
			setTrailsEnabled(true)
			tweenFov(SPRINT_FOV)
			startCameraMotion()
		else
			setTrailsEnabled(false)
			tweenFov(BASE_FOV)
			stopCameraMotion()
		end
	end

	sprintConnection = Humanoid:GetAttributeChangedSignal("Sprint"):Connect(onSprintChanged)
	charSprintConnection = Character:GetAttributeChangedSignal("Sprint"):Connect(onSprintChanged)
	onSprintChanged()

	local function cleanup()
		if sprintConnection then
			sprintConnection:Disconnect()
			sprintConnection = nil
		end
		if charSprintConnection then
			charSprintConnection:Disconnect()
			charSprintConnection = nil
		end
		stopCameraMotion()
		destroyTrails()
	end

	Character.AncestryChanged:Connect(function()
		if not Character.Parent then
			cleanup()
		end
	end)

	return cleanup
end

return SprintVisuals
