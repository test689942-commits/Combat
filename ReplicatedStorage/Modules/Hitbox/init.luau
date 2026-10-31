--[[
	by SalvatoreScripts
	Last Updated: March 31st, 2026
	DevForum: https://devforum.roblox.com/t/hitbox-module-by-salvatore/3913281
	
	
	
	Settings:
	
	LatencyCompensation: Distance compensation for lag so client hitboxes are instant.
	MaxLatencyCompensation: Max distance compensation for so, uping this value risks exploiting.
	Storage: Where new parts created with .Part() are stored.
	Whitelist: Whitelists where characters can be found.
	Debugging: Enabled/Distables debugging capability for all hitboxes.
]]

local Settings = {
	LatencyCompensation = 20,
	MaxLatencyCompensation = 50,
	Storage = workspace,
	Whitelist = workspace,
	Debugging = false
}







--

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Signal = require(script:WaitForChild("Signal"))
type Signal<T...> = Signal.Signal<T...>

local Event, Function = nil, nil
if RunService:IsServer() then
	Event = Instance.new("RemoteEvent")
	Event.Parent = script
	Function = Instance.new("RemoteFunction")
	Function.Parent = script
elseif RunService:IsClient() then
	Event = script:FindFirstChildOfClass("RemoteEvent") or script:WaitForChild("RemoteEvent")
	Function = script:FindFirstChildOfClass("RemoteFunction") or script:WaitForChild("RemoteFunction")
end
Event = Event :: RemoteEvent
Function = Function :: RemoteFunction

export type hitbox = {
	Started: Signal<>,
	Stopped: Signal<>,
	Hit: Signal<({Model}, ...any)>,
	TouchBegan: Signal<Model>,
	TouchEnded: Signal<Model>,
	Destroying: Signal<>,

	Start: (self: any, Timer: number?, Debounce: number?, ...any) -> nil,
	Stop: (self: any) -> nil,
	Clear: (self: any) -> nil,
	Once: (self: any, ...any) -> {Model},
	Weld: (self: any, Part: BasePart, Offset: CFrame?) -> Weld,
	AssignNetwork: (self: any) -> nil,
	IsActive: (self: any) -> boolean,
	IsTouching: (self: any, Character: Model) -> boolean,
	GetHitCharacters: (self: any) -> {Model?},
	HitCharacters: (self: any, Characters: Model | {Model}) -> nil,
	Destroy: (self: any) -> nil,
}

export type Hitbox = {
	Part: (
		Size: Vector3 | number, 
		WeldTo: BasePart?, 
		Offset: CFrame?
	) -> Part,
	New: (
		Focus: BasePart, 
		Parameters: OverlapParams?, 
		Client: Player?,
		Debug: boolean?
	) -> hitbox
}

local Hitbox = {}
Hitbox.__index = Hitbox

local Hitboxes = {}
local Clients = {}

Players.PlayerRemoving:Connect(function(Client: Player)
	Clients[Client] = nil
end)

function Hitbox.Part(Size: Vector3 | number, WeldTo: BasePart?, Offset: CFrame?)
	local part = Instance.new("Part") 
	part.CanCollide = false
	part.Transparency = 1
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.Shape = if typeof(Size) == "Vector3" then Enum.PartType.Block else Enum.PartType.Ball
	part.Size = if typeof(Size) == "Vector3" then Size else Vector3.new(Size, Size, Size)
	part.Anchored = if WeldTo == nil then true else false
	part.Massless = true
	
	local model = Instance.new("Model")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	
	part.Parent = model
	model.Parent = Settings.Storage
	
	if WeldTo then
		local weld = Instance.new("Weld")
		weld.Enabled = true
		weld.Name = "__HitboxWeld"
		weld.Parent = part
		weld.Part0 = part
		weld.Part1 = WeldTo
		weld.C1 = if Offset then Offset else CFrame.new()
	end
	
	return part
end

function Hitbox.New(Focus: BasePart, Parameters: OverlapParams?, Client: Player?, Debug: boolean?)
	if Hitboxes[Focus] then return Hitboxes[Focus] end
	Focus.Locked = true
	
	if RunService:IsServer() 
		and Focus.Anchored == false
	then Focus:SetNetworkOwner(nil) end
	
	assert(typeof(Focus) == "Instance" and Focus:IsA("BasePart"), "Hitbox 'Focus' must be an BasePart Instance.")
	assert(Focus:IsDescendantOf(workspace), "Hitbox 'Focus' must be a descendant of workspace.")
	
	local self = setmetatable({}, Hitbox)
	
	self.Focus = Focus
	self.Parameters = Parameters or OverlapParams.new()
	self.Client = if typeof(Client) == "Instance" and Client:IsA("Player") then Client else nil
	self.Offset = Focus:FindFirstChild("__HitboxWeld", true)
	self.Debug = Debug
	self.Started = Signal.new()
	self.Stopped = Signal.new()
	self.Hit = Signal.new()
	self.TouchBegan = Signal.new()
	self.TouchEnded = Signal.new()
	self.Destroying = Signal.new()
	
	self._Timer = nil
	self._Debounce = nil
	self._Trying = {}
	self._Touching = {}
	self._Characters = {}
	self._Args = {}
	
	self.__Timestamp = nil
	self.__Connection = nil
	self.__Debounce = nil
	self.__Destroying = Focus.Destroying:Once(function()
		self:Destroy()
	end)
	
	if self.Debug and Settings.Debugging then
		local clone = self.Focus:Clone()
		clone:ClearAllChildren()
		clone.Massless = true
		clone.CanCollide = false
		clone.Anchored = true
		clone.Color = Color3.fromRGB(255, 0, 0)
		clone.Transparency = 1
		clone.Name = "_Debug"
		clone.Parent = nil
		
		clone:GetPropertyChangedSignal("Parent"):Connect(function()
			if clone.Parent == nil then
				clone.Transparency = 1
			elseif clone.Parent == workspace then
				local conn = nil
				conn = RunService.Heartbeat:Connect(function()
					if not clone or clone.Parent == nil then conn:Disconnect() return end
					
					clone.CFrame = self.Focus.CFrame
					clone.Size = self.Focus.Size
					clone.Transparency = if self.Focus.Transparency == 1 then .75 else 1
				end)
			end
		end)
		
		self.__Debug = clone
	end
	
	if RunService:IsServer() and self.Client then
		repeat task.wait() until Clients[Client]
		task.wait()
		
		local params = {}
		if Parameters then
			params.FilterDescendantsInstances = self.Parameters.FilterDescendantsInstances
			params.FilterType = self.Parameters.FilterType
			params.RespectCanCollide = self.Parameters.RespectCanCollide
			params.MaxParts = self.Parameters.MaxParts
			params.Tolerance = self.Parameters.Tolerance
			params.CollisionGroup = self.Parameters.CollisionGroup
			params.BruteForceAllSlow = self.Parameters.BruteForceAllSlow
		end
		
		local timestamp = os.clock()
		local success, result = false, false
		repeat 
			success, result = pcall(function()
				self.Client:RequestStreamAroundAsync(self.Focus.Position, 10)
				return Function:InvokeClient(self.Client, "New", self.Focus, self.Focus.Position, params, self.Debug)
			end)
			
			task.wait()
		until success == true and result == true
			or self.Focus == nil
			or os.clock() - timestamp > 60
		
		if success == false
			or result == false
		then 
			warn("Hitbox failed to offload to "..self.Client.Name.."'s client. Focus: ", self.Focus) return 
		elseif success == true and result == true then
			self:AssignNetwork()
		end
	end
	
	Hitboxes[Focus] = self
	return self
end

function Hitbox:AssignNetwork()
	if RunService:IsServer()
		and self.Offset 
		and self.Offset.Part1:IsDescendantOf(self.Client.Character) 
	then

		if self.Focus.Anchored == false then
			self.Focus:SetNetworkOwner(self.Client)
		end

		if self.Offset.Part1:IsDescendantOf(self.Client.Character) 
			and self.Offset.Part1.Anchored == false
		then
			self.Offset.part1:SetNetworkOwner(self.Client)
		end
	end
end

function Hitbox:Weld(Part: BasePart, Offset: CFrame?)
	self.Focus.Massless = true
	
	if self.Offset ~= nil then
		self.Offset.Part1 = Part
		self.Offset.C1 = if Offset then Offset else CFrame.new()
		
		self:AssignNetwork()
		return self.Offset
	end
	
	for i,weld in pairs(self.Focus:GetChildren()) do
		if weld:IsA("Weld") then weld:Destroy() end
	end

	local weld = Instance.new("Weld")
	weld.Parent = self.Focus
	weld.Part0 = self.Focus
	weld.Part1 = Part
	weld.C1 = if Offset then Offset else CFrame.new()
	
	self:AssignNetwork()
	return weld
end

function Hitbox:IsActive()
	return self.__Timestamp ~= nil
end

function Hitbox:IsTouching(Character: Model)
	if self.Offset ~= nil then
		local radius = self.Offset.C1.Position.Magnitude + 1
		if (self.Offset.Part1.Position - self.Offset.Part0.Position).Magnitude > radius then
		return false end
	end
	
	if typeof(Character) ~= "Instance" 
		or not Character:IsA("Model")
		or not Character.PrimaryPart
	then return false end
	
	local multiplier = .01
	local player = Players:GetPlayerFromCharacter(Character) :: Player?
	local ping = if player then player:GetNetworkPing() else 0
	local distance = Settings.LatencyCompensation
	distance = distance + (multiplier * ping * Settings.LatencyCompensation)
	distance = distance + (multiplier * Character.PrimaryPart.AssemblyLinearVelocity.Magnitude * Settings.LatencyCompensation)
	distance = math.clamp(distance, Settings.LatencyCompensation, Settings.MaxLatencyCompensation)
	local magnitude = (Character.PrimaryPart.Position - self.Focus:GetClosestPointOnSurface(Character.PrimaryPart.Position)).Magnitude
	
	return magnitude <= distance
end

function Hitbox:GetHitCharacters()
	return self._Characters or {}
end

function Hitbox:HitCharacters(Characters: Model | {Model})
	if typeof(Characters) ~= "table" then Characters = {Characters} end
	if #Characters == 0 then return end
	
	local characters = {}

	for i,character in Characters :: {Model} do
		if not table.find(self._Characters, character) then
			table.insert(self._Characters, character)
			table.insert(characters, character)
		end
	end

	if #characters > 0 then
		self.Hit:Fire(self._Touching, table.unpack(self._Args))
	end
end

function Hitbox:Once(...)
	local characters = {}
	
	local parts = workspace:GetPartsInPart(self.Focus, self.Parameters)
	for _,part in pairs(parts) do
		if part.Parent:FindFirstChildOfClass("Humanoid") 
			and part.Parent:IsDescendantOf(Settings.Whitelist) 
			and not table.find(characters, part.Parent)
		then
			table.insert(characters, part.Parent)
		end
	end
	
	if self.__Connection then
		for i,character in pairs(self._Touching) do
			if not table.find(characters, character) then
				table.remove(self._Touching, i)
				self.TouchEnded:Fire(character)
			end
		end

		for i,character in pairs(characters) do
			if not table.find(self._Touching, character) then						
				table.insert(self._Touching, character)
				self.TouchBegan:Fire(character)
			end
		end
	end
	
	if Settings.Debugging and self.__Debug and RunService:IsStudio() then
		task.spawn(function()
			local timestamp = os.clock()
			self.__Debugging = timestamp

			self.__Debug.Parent = workspace

			task.wait(.1)

			if self.__Debugging == timestamp then
				self.__Debugging = nil
				self.__Debug.Parent = nil
			end
		end)
	end
	
	if RunService:IsServer() 
		and not self.__Connection 
	then
		self:HitCharacters(characters)
	end

	return characters
end 

function Hitbox:Start(Timer: number?, Debounce: number?, ...)
	self._Args = {...}
	
	self.Started:Fire()
	
	self._Timer = Timer
	self._Debounce = Debounce
	
	local timestamp = os.clock()
	self.__Timestamp = timestamp
	
	if Timer then
		task.delay(Timer, function()
			if self.__Timestamp == timestamp then
				self:Stop()
			end
		end)
	end
	
	if Settings.Debugging and self.__Debug and RunService:IsStudio() 
		and (RunService:IsClient() or not self.Client)
	then
		task.spawn(function()
			local _timestamp = os.clock()
			self.__Debugging = _timestamp

			self.__Debug.Parent = workspace
		end)
	end
	
	if RunService:IsServer() and self.Client then
		Event:FireClient(self.Client, "Start", self.Focus)
		
		if Debounce then
			task.spawn(function()
				while self.__Timestamp == timestamp do
					if #self._Touching > 0 then
						self:HitCharacters(self._Touching)
					end

					task.wait(Debounce)
				end
			end)
		end
	end
	
	if self.__Connection then self:Stop() end

	self.__Connection = RunService.Heartbeat:Connect(function()
		self:HitCharacters(self:Once())
	end)
	
	if Debounce then
		task.spawn(function()
			while self and self.__Timestamp == timestamp do task.wait(Debounce)
				self:Clear()
			end
		end)
	end
end

function Hitbox:Stop()
	
	if self.__Timestamp then
		self.__Timestamp = nil
		self._Trying = {}
		self._Touching = {}
		self.Stopped:Fire()
	end
	
	self._Timer = nil
	self._Debounce = nil
	
	if Settings.Debugging and self.__Debug and RunService:IsStudio() then
		task.spawn(function()
			local timestamp = os.clock()
			self.__Debugging = timestamp

			self.__Debug.Parent = nil
		end)
	end
	
	if RunService:IsServer() and self.Client then
		Event:FireClient(self.Client, "Stop", self.Focus)
	end
	
	if not self.__Connection then return end
	
	self.__Connection:Disconnect()
	self.__Connection = nil
end

function Hitbox:Clear()
	self._Characters = {}
end

function Hitbox:Destroy()
	Hitboxes[self.Focus] = nil
	
	if self.__Connection then self.__Connection:Disconnect() end
	if self.__Listen then self.__Listen:Disconnect() end
	if self.__Destroying then self.__Destroying:Disconnect() end
	if self.__Debug then self.__Debug:Destroy() end
	
	self.Destroying:Fire()
end

local connection = nil
if RunService:IsServer() then
	connection = Event.OnServerEvent:Connect(function(Player: Player, Key: string, ...)
		if typeof(Key) == "string" then
			if Key == "Loaded" then
				Clients[Player] = true
			elseif Key == "Hit" then
				local args = {...}
				local Focus = args[1]
				local Characters = args[2]
				
				if typeof(Focus) == "Instance" and Focus:IsA("BasePart") and typeof(Characters) == "table" then
					local hitbox = Hitboxes[Focus]

					if hitbox
						and Player == hitbox.Client 
						and hitbox.__Timestamp
					then
						local characters = {}

						for i,character in pairs(hitbox._Touching) do
							if not table.find(Characters, character) then
								hitbox._Trying[character] = nil

								table.remove(hitbox._Touching, i)
								hitbox.TouchEnded:Fire(character)
							end
						end

						for i,character in pairs(Characters) do
							if typeof(character) == "Instance" and character:IsA("Model") 
								and character:FindFirstChildOfClass("Humanoid") and character.PrimaryPart
								and not hitbox._Trying[character]
							then
								hitbox._Trying[character] = true

								local function check()

									if not table.find(hitbox._Touching, character) 
										and hitbox:IsTouching(character)
									then
										hitbox._Trying[character] = nil

										table.insert(hitbox._Touching, character)
										hitbox.TouchBegan:Fire(character)

										return true
									end

									return false
								end

								local function hit()
									if not hitbox._Debounce
										and not table.find(hitbox._Characters, character) 
									then
										table.insert(hitbox._Characters, character)

										return true
									end

									return false
								end

								if check() then 
									if hit() then
										table.insert(characters, character)
									end
								else
									task.spawn(function()
										while hitbox.__Timestamp
											and hitbox._Trying[character] 
										do
											if check() then
												if hit() then
													hitbox.Hit:Fire({character}, table.unpack(hitbox._Args))
												end
											end

											task.wait()
										end
									end)
								end
							end
						end

						if #characters > 0 then
							hitbox.Hit:Fire(characters, table.unpack(hitbox._Args))
						end
					end
				end
			end
		end
	end)
elseif RunService:IsClient() then
	
	local function waitForTagged(tag: string, maxWait: number?)
		maxWait = maxWait or 10
		local startTime = tick()
		local part

		repeat
			part = game:GetService("CollectionService"):GetTagged(tag)[1]

			task.wait()
		until part or tick() - startTime > maxWait
		return part
	end
	
	Function.OnClientInvoke = (function(Key: string, Focus: BasePart, ...)
		if Focus == nil then return false end
		
		if Key == "New" then
			local args = {...}
			
			local position = args[1]
			local parameters = args[2]
			local debug = args[3]

			local params = OverlapParams.new()
			params.FilterDescendantsInstances = parameters.FilterDescendantsInstances or {}
			params.FilterType = parameters.FilterType or Enum.RaycastFilterType.Exclude
			params.RespectCanCollide = parameters.RespectCanCollide or false
			params.MaxParts = parameters.MaxParts or 0
			params.Tolerance = parameters.Tolerance or 0
			params.CollisionGroup = parameters.CollisionGroup or "Default"
			params.BruteForceAllSlow = parameters.BruteForceAllSlow or false

			local hitbox = Hitbox.New(Focus, params, nil, debug)
			if hitbox == nil then return false end

			local began = hitbox.TouchBegan:Connect(function()
				Event:FireServer("Hit", hitbox.Focus, hitbox._Touching)
			end)

			local ended = hitbox.TouchEnded:Connect(function()
				Event:FireServer("Hit", hitbox.Focus, hitbox._Touching)
			end)

			hitbox.Destroying:Once(function()
				began:Disconnect()
				ended:Disconnect()
			end)
			
			return true
		end
		
		return false
	end)
		
	connection = Event.OnClientEvent:Connect(function(Key: string, Focus: BasePart?, ...)
		if Focus == nil then return end
		
		if typeof(Key) == "string" and typeof(Focus) == "Instance" and Focus:IsA("BasePart") then			
			if Key == "Start" 
				and Hitboxes[Focus]
			then
				local hitbox = Hitboxes[Focus]
				hitbox:Start()
			elseif Key == "Stop" 
				and Hitboxes[Focus]
			then
				local hitbox = Hitboxes[Focus]
				hitbox:Stop()
			end
		end
	end)
end

if RunService:IsServer() then
	repeat task.wait() until connection
	task.wait()
	script:AddTag("__loaded")
elseif RunService:IsClient() then
	repeat task.wait() until connection and script:HasTag("__loaded")
	task.wait()
	Event:FireServer("Loaded")
end

return Hitbox :: Hitbox