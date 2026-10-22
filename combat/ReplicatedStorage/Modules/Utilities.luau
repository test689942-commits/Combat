local module = {}
module.__index = module
local self = setmetatable({}, module)

module.Debris = {};

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TempCallbacks = {}

local Items = {}
local Types = {
	["Instance"] = "Destroy",
	["Table"] = "Remove",
	["RBXScriptConnection"] = "Disconnect",
}

local function MoreAccurateWait(Value)
	Value = Value or 1/60
	local Start = os.clock()
	while os.clock() - Start < Value do
		RunService.Stepped:Wait()
	end
end

local function RemoveItem(Part)
	local Info = Items[Part]

	if Info[4] == "Instance" then		
		if Info[5] then
			local Tween = TweenService:Create(Part, Info[5].Tweeninfo, Info[5].Goals)
			Tween:Play()
			coroutine.resume(coroutine.create(function()
				MoreAccurateWait(Info[5].Duration)
				Part:Destroy()
			end))
		else
			Part:Destroy()
		end
	elseif Info[4] == "RBXScriptConnection" then
		Info[1]:Disconnect()
	else
		table.clear(Part[1])
	end

	Items[Part] = nil
end

local function AddItem(Part, Lifetime, Info) --  Info is like this {Duration = 1, Tweeninfo = TweenInfo.new(Duration,EasingStyle, EasingDirecton), Goals = {CFrame = CFrame.new(0,-5,0)}
	local Type = typeof(Part) --                                                 Case sensitive

	assert(Types[Type])
	assert(typeof(Lifetime) == "number")
	Info = Info or false
	Items[Part] = {Part, Lifetime, os.clock(), Type, Info}
end

(if RunService:IsServer() then RunService.Heartbeat else RunService.RenderStepped):Connect(function(Delta)
	local CallbackValue
	for _, CallbackData in pairs(TempCallbacks) do
		CallbackValue = CallbackData.Callback(Delta)

		if CallbackData.Warning ~= nil then
			if not CallbackData.Warning and os.clock() - CallbackData.Init > 60 then
				CallbackData.Warning = true
				warn("Temp Callback Not Disconnected", CallbackData.Trace)
			end
		end

		if CallbackValue then
			table.remove(TempCallbacks, table.find(TempCallbacks, CallbackData))
		end
	end

	for Inst, Info in Items do
		if os.clock() - (Info[3] + Info[2]) > 0 then RemoveItem(Inst) end;
	end
end)

function module:AddToTempLoop(callback, Warn: boolean)
	local DoWarn = false
	if Warn then DoWarn = true end;
	local Info

	if DoWarn then
		Info = {
			Callback = callback;
			Init = os.clock();
			Warning = false;
			Trace = debug.traceback()
		}
	else
		Info = {Callback = callback}
	end
	table.insert(TempCallbacks, Info)
end

function module.Debris:AddItem(Part, Lifetime, Info)
	AddItem(Part, Lifetime, Info)
end

function module.Debris:AddItems(Parts, Lifetimes, Info)
	for i, Item in ipairs(Parts) do
		AddItem(Item, Lifetimes[i], Info)
	end
end

function module.Debris:CancelItem(Item)
	if Items[Item] then
		Items[Item] = nil
	end
end

function module.Debris:GetAllDebris()
	return Items
end

function module.Debris:GetDebris(Item)
	return Items[Item]
end

return module
