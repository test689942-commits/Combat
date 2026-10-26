local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AfterImages = {}

local ActiveInstances = {}

local StripClasses = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	Humanoid = true,
	Animator = true,
	Sound = true,
	SoundGroup = true,
	BillboardGui = true,
	ScreenGui = true,
	SurfaceGui = true,
	Trail = true,
	Beam = true,
	ParticleEmitter = true,
	SurfaceAppearance = true,
}

local function BuildTemplate(Rig)
	Rig.Archivable = true
	local Template = Rig:Clone()
	local HRP = Template:FindFirstChild("HumanoidRootPart")
	if HRP then HRP:Destroy() end

	for _, Obj in ipairs(Template:GetDescendants()) do
		if not Obj.Parent then continue end
		if StripClasses[Obj.ClassName] then
			Obj:Destroy()
		elseif Obj:IsA("BasePart") then
			Obj.Anchored = true
			Obj.CanCollide = false
			Obj.CanTouch = false
			Obj.CanQuery = false
			Obj.CastShadow = false
		end
	end

	return Template
end

local function SpawnGhost(Rig, Template, GhostColor, FillTransparency, FadeTime, StartTransparency)
	local FadeInfo = TweenInfo.new(FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local Ghost = Template:Clone()

	for _, Part in ipairs(Ghost:GetDescendants()) do
		if not Part:IsA("BasePart") then continue end
		local Live = Rig:FindFirstChild(Part.Name, true)
		if Live and Live:IsA("BasePart") then
			Part.CFrame = Live.CFrame
		end
		local tintAmount = math.clamp(1 - FillTransparency, 0, 1)
		Part.Color = Color3.new(1, 1, 1):Lerp(GhostColor, tintAmount)
		Part.Transparency = StartTransparency
		TweenService:Create(Part, FadeInfo, {Transparency = 1}):Play()
	end

	Ghost.Parent = workspace.Effects or workspace --I know you don't have a workspace.Effects folder you lazy bums
	Debris:AddItem(Ghost, FadeTime + 0.1)
end

function AfterImages.Play(Data)
	local Model = Data.Model
	if not Model then return end

	if Data.Stop then
		local Active = ActiveInstances[Model]
		if Active then
			Active.Running = false
			if Active.Template and Active.Template.Parent then
				Active.Template:Destroy()
			end
			ActiveInstances[Model] = nil
		end
		return
	end

	local Existing = ActiveInstances[Model]
	if Existing then
		Existing.Running = false
		if Existing.Template and Existing.Template.Parent then
			Existing.Template:Destroy()
		end
	end

	local GhostColor = Data.GhostColor or Color3.fromRGB(170, 0, 255)
	local FadeTime = Data.FadeTime or 0.3
	local Interval = Data.Interval or 0.05
	local FillTransparency = Data.FillTransparency or 0.6
	local StartTransparency = Data.StartTransparency or 0
	local Duration = Data.Duration

	local Template = BuildTemplate(Model)
	local State = {Running = true, Template = Template}
	ActiveInstances[Model] = State

	task.spawn(function()
		while State.Running and Model.Parent do
			SpawnGhost(Model, Template, GhostColor, FillTransparency, FadeTime, StartTransparency)
			task.wait(Interval)
		end
	end)

	if Duration then
		task.delay(Duration, function()
			if not State.Running then return end
			State.Running = false
			if State.Template and State.Template.Parent then
				State.Template:Destroy()
			end
			ActiveInstances[Model] = nil
		end)
	end
end

return AfterImages