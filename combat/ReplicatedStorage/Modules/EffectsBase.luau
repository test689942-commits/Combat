local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Base = {}

local Client = require(game:GetService("ReplicatedStorage").Modules.ClientSystem)

local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude
Params.FilterDescendantsInstances = {workspace.Effects}

local function IsOverGrass(part: BasePart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {workspace:FindFirstChild("World"),workspace.Terrain}

	local origin = part.Position
	local direction = Vector3.new(0, -5, 0)
	local result = workspace:Raycast(origin, direction, params)

	return result and result.Material == Enum.Material.Grass
end

local function GroundOnly(object: Instance)
	if not object then return false end

	local position
	if object:IsA("Attachment") then
		position = object.WorldPosition
	elseif object:IsA("BasePart") then
		position = object.Position
	else
		warn("GroundOnly: Unsupported instance type - must be BasePart or Attachment.")
		return false
	end

	local minHeight = 3
	local origin = position + Vector3.new(0, minHeight, 0)
	local direction = Vector3.new(0, -10, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {workspace:FindFirstChild("World"), workspace.Terrain}

	local result = workspace:Raycast(origin, direction, params)

	if result and result.Material ~= Enum.Material.Air then
		return result
	end

	return nil
end


function Base.Emit(Object: Instance?, Descendants: boolean)
	local DebrisTimer = 0

	local Table = Descendants and Object:GetDescendants() or Object:GetChildren()

	for _, Emitter in pairs(Table) do
		if Emitter:IsA("ParticleEmitter") then
			if Emitter:GetAttribute("GroundOnly") then
				if not GroundOnly(Emitter.Parent) then
					continue
				end
			end

			if (Emitter:FindFirstChild("GrassOnly") or Emitter.Name == "Grass" or Emitter:GetAttribute("GrassOnly") or Emitter.Name == "GrassOnly") 
				and not IsOverGrass(Emitter.Parent) then
				Emitter:Destroy()
				continue
			end

			if Emitter.Lifetime.Max > DebrisTimer then
				DebrisTimer = Emitter.Lifetime.Max
			end

			task.delay(Emitter:GetAttribute("EmitDelay") or 0, function()
				if Object:GetAttribute("NoDebris") then
					Client.Utilities.Debris:AddItem(Object, DebrisTimer)
				end

				if Emitter:GetAttribute("EmitDuration") and Emitter:GetAttribute("EmitDuration") > 0 then
					Emitter.Enabled = true
					task.wait(Emitter:GetAttribute("EmitDuration"))
					Emitter.Enabled = false
				else
					Emitter:Emit(Emitter:GetAttribute("EmitCount") or 1)
				end
			end)
		end
	end

	if not Object:GetAttribute("NoDebris") then
		Client.Utilities.Debris:AddItem(Object, DebrisTimer)
	end

	return DebrisTimer
end


function Base.Enable(Object: Instance?, Descendants: boolean, Duration: number, Enabled: boolean)
	local function enableParticle(p)
		if (p:FindFirstChild("GrassOnly") or p.Name == "Grass" or p.Name == "GrassOnly") and not IsOverGrass(p.Parent) then
			p.Enabled = false
			return
		end

		if Enabled ~= nil then
			p.Enabled = Enabled
		else
			p.Enabled = true
			task.delay(Duration, function()
				p.Enabled = false
			end)
		end
	end

	local function process(obj)
		if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
			enableParticle(obj)
		end
	end

	if Descendants then
		for _, v in pairs(Object:GetDescendants()) do
			process(v)
		end
	else
		process(Object)
		if Object:IsA("Attachment") then
			for _, v in pairs(Object:GetChildren()) do
				process(v)
			end
		end
	end
end


--// Merged Helpers \\--

local MergedNumberHelper = (function()
local NumberHelper = {}

-- Returns a random number between min and max (Default: .8 - 1.2)
function NumberHelper.Random(min:number,max:number):number
    return Random.new():NextNumber(min or .8,max or 1.2)
end

-- Returns either 1 or -1 randomly
function NumberHelper.RandomReverseMutlipler():number
    return (math.random(0,1) == 1 and 1 or -1)
end

-- Returns a random rotation from -360 to 360 in radians
function NumberHelper.RandomRotation():number
	local fullRot = 2*math.pi
	return NumberHelper.Random(-fullRot,fullRot)
end

function NumberHelper.Round(number,decimalPlaces)
	decimalPlaces = (decimalPlaces or 0)
	local newNum = math.round(number * 10^decimalPlaces) * 10^-decimalPlaces

	newNum=tonumber(string.format("%." .. (decimalPlaces) .. "f", newNum))
	return newNum
end

function NumberHelper.NumberToVector3(num) -- Returns a Vector3 with the given number in every value
	return Vector3.new(num,num,num)
end

function NumberHelper.ScaleValue(baseValue,scaleValue,currentValue) 
	local getBasedValueFuncs = {}

	local function multiplyScaleValue(value)
		return (currentValue*value)/baseValue
	end
	function getBasedValueFuncs.NumberSequence()
		local basedKeypoints = {}
		for i,keypoint in pairs(scaleValue.Keypoints) do
			basedKeypoints[i] = NumberSequenceKeypoint.new(keypoint.Time,multiplyScaleValue(keypoint.Value),multiplyScaleValue(keypoint.Envelope)) 
		end
		return NumberSequence.new(basedKeypoints)
	end

	function getBasedValueFuncs.NumberRange()
		return NumberRange.new(
			multiplyScaleValue(scaleValue.Min),
			multiplyScaleValue(scaleValue.Max)
		)
	end

	function getBasedValueFuncs.Default()
		return multiplyScaleValue(scaleValue)
	end

	return (getBasedValueFuncs[typeof(scaleValue)] or getBasedValueFuncs.Default)()
end

function NumberHelper.GetRootScaleValues(rootSize)
	return Vector3.new(2,2,1).Magnitude,rootSize.Magnitude
end

function NumberHelper.GetLargestAxis(vector3:Vector3):(number,string)
	local largestVector = {size=vector3.X,name = 'X'}
	local function checkLargest(axis:string)
		local newSize:number = vector3[axis]
		if largestVector.size <= newSize then
			largestVector.size = newSize
			largestVector.name = axis
		end
	end
	checkLargest("Y")
	checkLargest("Z")
	return largestVector.size,largestVector.name
end

function NumberHelper.SineBetween(t:number,maxNumber:number,minNumber:number, frequency:number,phase:number)
	return ((maxNumber-minNumber)*math.sin(t*frequency +  phase) + maxNumber + minNumber)/2
end
return NumberHelper
end)()

local MergedGeneralUse = (function()
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Instances
local modules = ReplicatedStorage.Modules

local GeneralUse = {}

-- Returns a value using the given ratio.
function GeneralUse.basedValue(baseValue,scaleValue,currentValue) 
	--	print(z,y,x)
	local getBasedValueFuncs = {}

	local function multiplyScaleValue(value)
		return (currentValue*value)/baseValue
	end
	function getBasedValueFuncs.NumberSequence()
		local basedKeypoints = {}
		for i,keypoint in pairs(scaleValue.Keypoints) do
			basedKeypoints[i] = NumberSequenceKeypoint.new(keypoint.Time,multiplyScaleValue(keypoint.Value),multiplyScaleValue(keypoint.Envelope)) 
		end
		return NumberSequence.new(basedKeypoints)
	end

	function getBasedValueFuncs.NumberRange()
		return NumberRange.new(
			multiplyScaleValue(scaleValue.Min),
			multiplyScaleValue(scaleValue.Max)
		)
	end

	function getBasedValueFuncs.Default()
		return multiplyScaleValue(scaleValue)
	end

	return (getBasedValueFuncs[typeof(scaleValue)] or getBasedValueFuncs.Default)()
end

function GeneralUse.Round(number,decimalPlaces)
	local decimalPlaces = (decimalPlaces or 0)
	local newNum = math.round(number * 10^decimalPlaces) * 10^-decimalPlaces

	newNum=tonumber(string.format("%." .. (decimalPlaces) .. "f", newNum))
	return newNum
end

function GeneralUse.CalcWeldC0(cf0,cf1)
	return cf0:ToObjectSpace(cf1)
end

local function joinParts(name,p0,p1,c0,c1,parent)
	local joinObject = Instance.new(name)
	joinObject.Part0 = p0
	joinObject.Part1 = p1
	if name~="WeldConstraint" then
	
		joinObject.C0 = c0 or GeneralUse.CalcWeldC0(p0.CFrame,p1.CFrame)
		if c1 then
			joinObject.C1 = c1
		end
	end
	joinObject.Parent = parent or p0
	return joinObject
end

function GeneralUse.AddMotor6D(...):Motor6D
	return joinParts("Motor6D",...)
end

function GeneralUse.Weld(...):Weld
	return joinParts("Weld",...)
end

function GeneralUse.AddWeldConstraint(...):WeldConstraint
	return joinParts("WeldConstraint",...)
end
function GeneralUse.GetTargetFromHit(hit)
	local target
	if hit.Parent:FindFirstChild("Humanoid") then
		target = hit.Parent

	elseif hit.Parent.Parent:FindFirstChild("Humanoid") then
		target = hit.Parent.Parent
	end
	return target
end
function GeneralUse.GetFirstCollidable(startPos,angle,ignoreList,includeChars,debugMode):RaycastResult	 -- Raycasts from the startPos using the given angle (or Vector3.new(0,-100,0) if left nil) using the given ignore list. Returns the first collidable hit or nil if it hits nothing. If includeChars is true then it will include parts that are parented to characters
	angle = angle or Vector3.new(0,-1000,0)
	ignoreList = ignoreList or {}
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = ignoreList
	--raycastParams.IgnoreWater = true
	local firstCollide
	while true do
		raycastParams.FilterDescendantsInstances = ignoreList
		local result = workspace:Raycast(startPos,angle, raycastParams)
		if debugMode then
			--print(result)
		end
		if result then
			local hit = result.Instance
			local canContinue = true

			local target = GeneralUse.GetTargetFromHit(hit)
			if target then
				if not includeChars then			
					canContinue = false
					table.insert(ignoreList,1,target)
				end
			else
				if not hit.CanCollide then
					canContinue = false
				end
			end


			if canContinue then
				firstCollide = result
				break
			else
				table.insert(ignoreList,1,hit)
			end
		else
			break
		end
	end
	return firstCollide,ignoreList
end

function GeneralUse.ScaleParticle(baseNum,particle,givenNum,categories,baseParticle)
	categories = categories or {
		"Size";
		"Speed";
		"Acceleration";
	}

	for _,category in pairs(categories) do
		particle[category] = GeneralUse.basedValue(baseNum,(baseParticle or particle)[category],givenNum)
	end
	return particle
end
function GeneralUse:GetShakeOffset(shakeStrength:number,shakeTime:number?,fadeOut:TweenInfo,doShakeFunc,optSettings)
	optSettings=optSettings or {}
	local shakeWait = optSettings.shakeWait or .04
	local fadeIn = optSettings.fadeIn

	local stopShake = false
	local shakeValue = Instance.new("NumberValue")
	shakeValue.Value = shakeStrength


	local shakeMut = Instance.new("NumberValue")
	shakeMut.Value = fadeIn and 0 or 1

	if fadeIn then
		TweenService:Create(shakeMut,fadeIn,{Value = 1}):Play()
	end
	task.spawn(function()
		repeat
			doShakeFunc(function(basePosition,epicenter,shakeDist,noRandomize)
				local strength = shakeValue.Value
				local newStrength

				if basePosition and epicenter and shakeDist then
					local distFromCenter = (basePosition - epicenter).Magnitude
					newStrength = math.clamp((shakeDist*strength)/distFromCenter,0,strength)
				else
					newStrength = strength
				end
				if not noRandomize then
					local randomObject = Random.new()
					newStrength = randomObject:NextNumber(-newStrength,newStrength)
				end
				return newStrength*shakeMut.Value
			end,shakeWait)
			task.wait(shakeWait)
		until stopShake
	end)

	task.wait(shakeTime)

	TweenService:Create(shakeValue,fadeOut,{Value = 0}):Play()
	task.wait(fadeOut.Time)
	stopShake = true
end

return GeneralUse
end)()

local MergedTM = (function()
local TS = game:GetService("TweenService")
local rp = game:GetService("ReplicatedStorage")
local RS = game:GetService('RunService')

-- modules
local module = {}

function module.Clasic_tween(part, data)
	local size = data.size or nil
	local scale = data.scale or nil
	local tim = data.tim or 1
	local pos = data.pos or nil
	local trans = data.trans or nil
	local cf = data.cf or nil
	local colr = data.colr or nil
	local EasingStyle = data.EasingStyle 
	local EasingDirection = data.EasingDirection 
	local redo = data.redo or false
	local dely = data.dely 
	
	if size ~= nil then
		local startSize = data.startSize or part.Size
		part.Size = startSize
		
		local sizeTim = data.sizeTim 
		local sizeDel = data.sizeDel 
		
		local Info = TweenInfo.new(
			sizeTim or tim,
			EasingStyle or Enum.EasingStyle.Linear,
			EasingDirection or Enum.EasingDirection.Out,
			0,
			redo,
			sizeDel or dely or 0
		)
		local new = {}
		new.Size = size
		local twee = TS:Create(part, Info, new)
		twee:Play()
		twee:Destroy()
	end
	
	if scale ~= nil then
		local startScale = data.startScale or part.Scale
		part.Scale = startScale

		local sizeTim = data.sizeTim 
		local sizeDel = data.sizeDel 

		local Info = TweenInfo.new(
			sizeTim or tim,
			EasingStyle or Enum.EasingStyle.Linear,
			EasingDirection or Enum.EasingDirection.Out,
			0,
			redo,
			sizeDel or dely or 0
		)
		local new = {}
		new.Scale = size
		local twee = TS:Create(part, Info, new)
		twee:Play()
		twee:Destroy()
	end
	
	if trans ~= nil then
		local startTrans = data.startTrans or part.Transparency
		part.Transparency = startTrans
		
		local transTim = data.transTim 
		local transDel = data.transDel 
		
		local Info = TweenInfo.new(
			transTim or tim ,
			EasingStyle or Enum.EasingStyle.Linear,
			EasingDirection or Enum.EasingDirection.Out,
			0,
			redo,
			transDel or dely or 0
		)
		local new = {}
		new.Transparency = trans
		local twee = TS:Create(part, Info, new)
		twee:Play()
		twee:Destroy()
	end
	
	if cf ~= nil then
		local startcf = data.startcf or part.CFrame
		part.CFrame = startcf
		
		local cfTim = data.cfTim 
		local cfDel = data.cfDel 
		
		local Info = TweenInfo.new(
			cfTim or tim,
			EasingStyle or Enum.EasingStyle.Linear,
			EasingDirection or Enum.EasingDirection.Out,
			0,
			redo,
			cfDel or dely or 0
		)
		local new = {}
		new.CFrame = cf or startcf
		local twee = TS:Create(part, Info, new)
		twee:Play()
		twee:Destroy()
	end
	
	-- pos
	if pos ~= nil then
		local posTim = data.posTim 
		local posDely = data.posDely 

		local Info = TweenInfo.new(
			posTim or tim,
			EasingStyle or Enum.EasingStyle.Linear,
			EasingDirection or Enum.EasingDirection.Out,
			0,
			redo,
			posDely or dely or 0
		)
		local new = {}
		new.Position = pos
		local twee = TS:Create(part, Info, new)
		twee:Play()
		twee:Destroy()
	end
	
	-- colr
	if colr ~= nil then
		local colrTim = data.colrTim 
		local colrDel = data.colrDel 
		
		if part:IsA('FileMesh') then
			local startColr = data.startColr 
			part.VertexColor = part.VertexColor
			if startColr then 	part.VertexColor =  Vector3.new(startColr.Color) end
			
			
			local Info = TweenInfo.new(
				colrTim or tim,
				EasingStyle or Enum.EasingStyle.Linear,
				EasingDirection or Enum.EasingDirection.Out,
				0,
				redo,
				colrDel or 0
			)
			local new = {}
			new.VertexColor =  Vector3.new( colr.Color)
			local twee = TS:Create(part, Info, new)
			twee:Play()
			twee:Destroy()
		else
			local startColr = data.startColr or part.BrickColor

			part.Color = startColr.Color
			local Info = TweenInfo.new(
				colrTim or tim,
				EasingStyle or Enum.EasingStyle.Linear,
				EasingDirection or Enum.EasingDirection.Out,
				0,
				redo,
				colrDel or dely or 0
			)
			local new = {}
			new.Color = colr.Color
			local twee = TS:Create(part, Info, new)
			twee:Play()
			twee:Destroy()
			
		end
		
	end
end

module.extend = function(part, data)
	local hroot = data.hroot 
	local request = data.request
	local cf_start_point = data.cf_start_point or hroot.CFrame * CFrame.new(0,0,-2.5)
	
	local lenth = data.lenth or 100
	local tim = data.tim or 1
	local redo = data.redo or false
	local EasingStyle = data.EasingStyle or Enum.EasingStyle.Quad
	local invese = data.invese or nil
	
	if request == "Y" then
		if invese then
			module.Clasic_tween(part, {cf = cf_start_point * CFrame.new(0,lenth/2,0), size = part.Size + Vector3.new(0,lenth,0), EasingStyle = EasingStyle, redo = redo, tim = tim })
		else
			module.Clasic_tween(part, {cf = cf_start_point * CFrame.new(0,-lenth/2,0), size = part.Size + Vector3.new(0,lenth,0), EasingStyle = EasingStyle, redo = redo, tim = tim })
		end
		
	elseif request == "X" then
		if invese then
			module.Clasic_tween(part, {cf = cf_start_point * CFrame.new(lenth/2,0,0), size = part.Size + Vector3.new(lenth,0,0), EasingStyle, redo = redo, tim = tim})
		else
			module.Clasic_tween(part, {cf = cf_start_point * CFrame.new(-lenth/2,0,0), size = part.Size + Vector3.new(lenth,0,0), EasingStyle, redo = redo, tim = tim})
		end
		
	elseif request == "Z" then
		if invese then
			module.Clasic_tween(part, {cf = cf_start_point * CFrame.new(0,0,lenth/2), size = part.Size + Vector3.new(0,0,lenth), EasingStyle , redo = redo, tim = tim})
		else
			module.Clasic_tween(part, {cf = cf_start_point * CFrame.new(0,0,-lenth/2), size = part.Size + Vector3.new(0,0,lenth), EasingStyle , redo = redo, tim = tim})
		end
		
	end
	
end

--cf2
function module.cf2(part, dur, cf, times)
	task.delay(dur,function()
		local Info = TweenInfo.new(
			times or 1,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out,
			0,
			false,
			0
		)
		local new = {}
		new.CFrame = cf
		local twee = TS:Create(part, Info, new)
		twee:Play()
		
	
		
		return twee
	end)
	
end

--invisable
function module.invisable(model, wai, durI, durO)
	coroutine.wrap(function()
		-- script
		for i, v in pairs(model:GetDescendants()) do 
			if v:IsA("BasePart") or v:IsA("MeshPart") then
				if v.Name ~= "HumanoidRootPart"  then
					if not v:FindFirstChild("Invisible Part") then
						--		print(v.Name)
						local Tween = TS:Create(v,TweenInfo.new(durI),{Transparency = 1})
						Tween:Play()
					end


				end	
			end
		end
		task.delay(wai, function()
			for i, v in pairs(model:GetDescendants()) do 
				if v:IsA("BasePart") or v:IsA("MeshPart") then
					if v.Name ~= "HumanoidRootPart" then
						if not v:FindFirstChild("Invisible Part") then
							--						print(v.Name)
							local Tween = TS:Create(v,TweenInfo.new(durO),{Transparency = 0})
							Tween:Play()
						end

					end	
				end
			end
		end)
	end)()

	
end

--invisable
function module.Total_Invisable_Char(model, data)
	coroutine.wrap(function()
		
		local PlrData = data.PlrData
		local tween = data.tween or false
		local durI = data.durationIn or .2
		local wai = data.WaiT or .5
		local durO = data.durationOut or durI
		
		local function AttributeCheck(v)
			task.delay(durO+.1, function()
				if v:GetAttribute("NormalTransparency") then
					v.Transparency = v:GetAttribute("NormalTransparency")
				end
			end)
			
		end
		
		local function CheckEquipUnequip(v, bool)
			if v:IsA("BasePart") then
				task.delay(durO+.1,function()

					-- 
					if PlrData and  model:FindFirstChild(PlrData.Weapon) then
						local weapon =  model:FindFirstChild(PlrData.Weapon)
						if weapon['Equipped'].Value == bool then
							v.Transparency = 1
						else
							v.Transparency = 0
							if v:FindFirstChild("Transperancy") then
								v.Transparency = v:FindFirstChild("Transperancy").Value
							end
						end
					end

				end)
			end
		end
		
		local WeaponCheck = function(v)
			if v.Name ==  'WeaponParts' then
				coroutine.wrap(function()
					for i, v in pairs(v:GetChildren()) do
						
						CheckEquipUnequip(v,false)
					end
				end)()
				
			end
			
			if v.Name == "InCaseWeapon" then
				coroutine.wrap(function()
					for i, v in pairs(v:GetChildren()) do
						CheckEquipUnequip(v,true)
						
					end
				end)()
			end
			
		end
		
		
		-- script
		for i, v in pairs(model:GetDescendants()) do 
			if v:IsA("BasePart") or v:IsA("MeshPart")  or v:IsA("Decal") then
				if v.Name ~= "HumanoidRootPart" and v.Name ~= "Handle" and v.Name ~= "RightGrip" and v.Name ~= "LeftGrip" then
					coroutine.wrap(function()
						if tween == true then
							local Tween = TS:Create(v,TweenInfo.new(durI),{Transparency = 1})
							Tween:Play()
						else
							v.Transparency = 1

						end
					end)()
					
				end	
			end
		end
		task.wait(wai)
		
		for i, v in pairs(model:GetDescendants()) do 
			
			if v:IsA("BasePart") or v:IsA("MeshPart") or v:IsA("Decal") then
				if v.Name ~= "HumanoidRootPart" and v.Name ~= "Handle" and v.Name ~= "RightGrip" and v.Name ~= "LeftGrip" then
					local Tween = TS:Create(v,TweenInfo.new(durO ),{Transparency = 0})
					Tween:Play()
					
					coroutine.wrap(function()
						AttributeCheck(v)
					end)()
					
					
				end	
			end
			
			if v:IsA("Folder") then
				
				coroutine.wrap(function()
					WeaponCheck(v)
				end)()
			
				
			end
		end
	end)()


end
--//spin
function module.spin(part, data)
	local speed = data.speed or .5
	local ans = data.ans or "Y"
	local inverse = data.inverse or nil
	local EasingStyle = data.EasingStyle or Enum.EasingStyle.Sine
	
	if ans == "Y" then
		task.spawn(function()
			if inverse ~= nil then
				
				RS.RenderStepped:Connect(function()
					part.CFrame = part.CFrame*CFrame.Angles(0,math. rad(-speed),0)
				end)
				
			else
				RS.RenderStepped:Connect(function()
					part.CFrame = part.CFrame*CFrame.Angles(0,math. rad(speed),0)
				end)
			end
			
		end)
	end
	
	if ans == "X" then
		task.spawn(function()
			if inverse ~= nil then
				RS.RenderStepped:Connect(function()
					part.CFrame = part.CFrame*CFrame.Angles(math.rad(-speed),math. rad(0),math. rad(0))
				end)
			else
				RS.RenderStepped:Connect(function()
					part.CFrame = part.CFrame*CFrame.Angles(math.rad(speed),math. rad(0),math. rad(0))
				end)
			end
			
		end)
		
	end
	
	if ans == "Z" then
		task.spawn(function()
			if inverse ~= nil then
				RS.RenderStepped:Connect(function()
					part.CFrame = part.CFrame*CFrame.Angles(math.rad(0),math. rad(0),math. rad(-speed))
				end)
			else
				RS.RenderStepped:Connect(function()
					part.CFrame = part.CFrame*CFrame.Angles(math.rad(0),math. rad(0),math. rad(speed))
				end)
			end
			
		end)
		
	end
end

--//invert-spin
function module.invert_spin(part, speed, ans)
	if ans == "Y" then
		task.spawn(function()
			local	info = TweenInfo.new(speed or 1,Enum.EasingStyle.Linear)

			local	Spin1 = TS:Create(part,info,{CFrame = part.CFrame * CFrame.Angles(0,math.rad(-120),0)})
			local	Spin2 = TS:Create(part,info,{CFrame = part.CFrame * CFrame.Angles(0,math.rad(-240),0)})
			local	Spin3 = TS:Create(part,info,{CFrame = part.CFrame * CFrame.Angles(0,math.rad(-360),0)})

			-- loopin
			Spin1:Play()
			Spin1.Completed:Connect(function()Spin2:Play() end)
			Spin2.Completed:Connect(function()Spin3:Play() end)
			Spin3.Completed:Connect(function()Spin1:Play() end)
		end)

	end

	if ans == "X" then
		task.spawn(function()
			local	info = TweenInfo.new(speed or 1,Enum.EasingStyle.Linear)

			local	Spin1 = TS:Create(part,info,{CFrame = part.CFrame * CFrame.Angles(math.rad(-120),0,0)})
			local	Spin2 = TS:Create(part,info,{CFrame = part.CFrame * CFrame.Angles(math.rad(-240),0,0)})
			local	Spin3 = TS:Create(part,info,{CFrame = part.CFrame * CFrame.Angles(math.rad(-360),0,0)})

			-- loopin
			Spin1:Play()
			Spin1.Completed:Connect(function()Spin2:Play() end)
			Spin2.Completed:Connect(function()Spin3:Play() end)
			Spin3.Completed:Connect(function()Spin1:Play() end)
		end)

	end

	if ans == "Z" then
		task.spawn(function()
			local	info = TweenInfo.new(speed or 1,Enum.EasingStyle.Linear)

			local	Spin1 = TS:Create(part,info,{CFrame = part.CFrame * CFrame.Angles(0,0,math.rad(-120))})
			local	Spin2 = TS:Create(part,info,{CFrame = part.CFrame * CFrame.Angles(0,0,math.rad(-240))})
			local	Spin3 = TS:Create(part,info,{CFrame = part.CFrame * CFrame.Angles(0,0,math.rad(-360))})

			-- loopin
			Spin1:Play()
			Spin1.Completed:Connect(function()Spin2:Play() end)
			Spin2.Completed:Connect(function()Spin3:Play() end)
			Spin3.Completed:Connect(function()Spin1:Play() end)
		end)

	end
end

function module.stween2(part, maxSize, trans, times)
	local Info = TweenInfo.new(
		times or 1,
		Enum.EasingStyle.Exponential,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local new = {}
	new.Size = maxSize
	new.Transparency = trans
	local twee = TS:Create(part, Info, new)
	twee:Play()
	return twee
end


function module.stween(part,maxSize, trans, times)
	local Info = TweenInfo.new(
		times or 1,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local new = {}
	new.Size = maxSize
	new.Transparency = trans
	local twee = TS:Create(part, Info, new)
	twee:Play()
	return twee
end

function module.transtween(part, trans, times, dur)
	task.delay(dur,  function() 
		local Info = TweenInfo.new(
			times or 1,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out,
			0,
			false,
			0
		)
		local new = {}
		new.Transparency = trans
		local twee = TS:Create(part, Info, new)
		twee:Play()
		return twee
	end)
end

function module.trans_tween(part, data)
	local dur = data.dur
	local times = data.tim
	local trans = data.tran
	local EasingStyle = data.EasingStyle
	local tweendestry = data.bool or true
	
	--
	task.delay(dur or 0,  function() 
		local Info = TweenInfo.new(
			times or 1,
			EasingStyle or Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out,
			0,
			false,
			0
		)
		local new = {}
		new.Transparency = trans
		local twee = TS:Create(part, Info, new)
		twee:Play()
		
		if tweendestry == true then
			twee.Completed:Connect(function()
				twee:Destroy()
			end)
		end
		return twee
	end)
end

--size
function module.size_tween(part, data)
	local times = data.tim
	local maxSize = data.size
	local EasingStyle = data.EasingStyle
	local tweendestry = data.bool or true
	
	--
	local Info = TweenInfo.new(
		times or 1,
		EasingStyle or Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local new = {}
	new.Size = maxSize
	local twee = TS:Create(part, Info, new)
	twee:Play()
	
	if tweendestry == true then
		twee.Completed:Connect(function()
			twee:Destroy()
		end)
	end
	
	return twee
end


function module.color_tween(part, data)
	local colr = data.colr or part.BrickColor
	local tim = data.tim or 1
	
	local Info = TweenInfo.new(
		tim ,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local new = {}
	new.Color = colr.Color
	local twee = TS:Create(part, Info, new)
	twee:Play()
	
	return twee
end

-- colr 
function module.colortween(part, color, times)
	local Info = TweenInfo.new(
		times or 1,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local new = {}
	new.Color = color
	local twee = TS:Create(part, Info, new)
	twee:Play()
	return twee
end

-- colr + return
function module.colortweenreturn(part, color, times)
	local Info = TweenInfo.new(
		times or 1,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out,
		0,
		true,
		0
	)
	local new = {}
	new.Color = color
	local twee = TS:Create(part, Info, new)
	twee:Play()
	return twee
end

--cframe
function module.cframetween(part, cf, times, EasingStyle)
	local Info = TweenInfo.new(
		times or 1,
		EasingStyle or Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local new = {}
	new.CFrame = cf
	local twee = TS:Create(part, Info, new)
	twee:Play()
	

	return twee
end


--modelCframe
function module.cframetweenModel(model, cf, times)
	local Info = TweenInfo.new(
		times or 1,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local new = {}
	new.CFrame = cf
	local twee = TS:Create(model, Info, new)
	twee:Play()
	return twee
end

--size
function module.sizetween(part, maxSize, times)
	local Info = TweenInfo.new(
		times or 1,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local new = {}
	new.Size = maxSize
	local twee = TS:Create(part, Info, new)
	twee:Play()
	return twee
end

--everything
function module.ctween(part,style, direction, maxSize, trans, times, color, cf)
	local Info = TweenInfo.new(
		times or 1,
		style,
		direction,
		0,
		false,
		0
	)
	local new = {}
	new.Size = maxSize
	new.Transparency = trans
	new.Color = color
	new.CFrame = cf
	local twee = TS:Create(part, Info, new)
	twee:Play()
	return twee
end

function module.ctween2(part,style, direction, maxSize, trans, times)
	local Info = TweenInfo.new(
		times or 1,
		style,
		direction,
		0,
		false,
		0
	)
	local new = {}
	new.Size = maxSize
	new.Transparency = trans
	local twee = TS:Create(part, Info, new)
	twee:Play()
	return twee
end

function module.btween(part, maxSize, trans, times, color, cf)
	local Info = TweenInfo.new(
		times or 1,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)
	local new = {}
	new.Size = maxSize
	new.Transparency = trans
	new.Color = color
	new.CFrame = cf
	local twee = TS:Create(part, Info, new)
	twee:Play()
	return twee
end

return module
end)()

local MergedEmitModule = (function()
-- Services
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService('Debris')
-- Instances
local modules = game.ReplicatedStorage.Modules
local DebrisFolder = workspace.Debris

-- Modules
local GeneralUse = MergedGeneralUse
local NumberHelper = MergedNumberHelper

local Module = {}

-- disables particles/trails and then deletes the part after all the paritcles dissappear
function Module.RemoveVFX(part,optSettings):number
	optSettings = optSettings or {}
	local noDisable=optSettings.noDisable
	local removeDelay=optSettings.removeDelay
	local ignoreBeams = optSettings.ignoreBeams
	if removeDelay then
		task.wait(removeDelay)
	end

	local highestTime = 0
	local function updateHighestLifetime(newTime)
		if newTime >= highestTime then
			highestTime=newTime
		end
	end
	if typeof(part) == 'Instance' then
		for _,object:(ParticleEmitter|Trail) in part:GetDescendants() do
			if object:IsA("ParticleEmitter")  then
				local maxLifetime = object.Lifetime.Max + (object:GetAttribute('EmitDelay') or 0) * (1/object.TimeScale)
				updateHighestLifetime(maxLifetime)
			elseif object:IsA('Trail') then
				updateHighestLifetime(object.Lifetime)
			end
		end
		if not noDisable then
			Module.DisableVFX(part,ignoreBeams)
		end
		Debris:AddItem(part,highestTime)
	else
		-- if the "part" variable is a table then we want to loop through the particles and remove them indivudally
		for _,object in part do
			if not noDisable then
				object.Enabled = false
			end
			local lifetime = object.Lifetime.Max
			updateHighestLifetime(lifetime)
			Debris:AddItem(object,lifetime)
		end
	end
	return highestTime
end

function Module.EmitFromModel(model,ignoreLight)
	local particleTab
	if type(model) == 'table' then
		particleTab=model
	else
		particleTab=model:GetDescendants()
	end
	for _,object in particleTab do
		if object:IsA("ParticleEmitter")  then
			local amount = object:GetAttribute("EmitCount") or object:GetAttribute("Amount")
			if amount then
				task.delay(object:GetAttribute('EmitDelay') or 0,function()
					object:Emit(amount)
				end)
			end
		--elseif object:IsA("PointLight") and not ignoreLight then
		--	local goal = {}
		--	goal.Brightness = object.Brightness
		--	goal.Range = object.Range
		--	if object:FindFirstChild("ChangeBrightness") then
		--		goal.Brightness = object.ChangeBrightness.Value
		--	end
		--	local tweeninfo = TweenInfo.new(object.Timer.Value,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,0)
		--	local tween = TweenService:Create(object,tweeninfo,goal)
		--	tween:Play()
		end
	end
end

function Module.SetSmokeColor(particlePart,optSettings)
	optSettings = optSettings or {}
	local raycastResult = optSettings.raycastResult
	local smokeBaseNames = optSettings.smokeBaseNames or {'Smoke'}
	local smokeParticles = {}

	for _,object in particlePart:GetDescendants() do
		if not object:IsA('ParticleEmitter') then
			continue
		end
		local isSmoke
		for _,baseName in smokeBaseNames do
			if not string.find(object.Name,baseName) then
				continue
			end

			isSmoke=true
			break
		end
		if not isSmoke then
			continue
		end
		table.insert(smokeParticles,object)
	end

	if #smokeParticles == 0 then
		return
	end

	if not raycastResult then
		raycastResult=GeneralUse.GetFirstCollidable(particlePart.Position,particlePart.CFrame.UpVector * -25)
	end
	
	if not raycastResult then
		return
	end

	for _,smokeParticle:ParticleEmitter in smokeParticles do
		smokeParticle.Color = ColorSequence.new(raycastResult.Instance.Color)
	end
	return raycastResult
end


function Module.ScaleParticle(baseNum,particle,givenNum,categories,baseParticle)
	categories = categories or {
		"Size";
		"Speed";
		"Acceleration";
	}

	for _,category in pairs(categories) do
		particle[category] = NumberHelper.ScaleValue(baseNum,(baseParticle or particle)[category],givenNum)
	end
	return particle
end

-- Scales the particle part and all the particles in it
function Module.ScaleParticlePart(particlePart:BasePart,scaleMut:number)
	if scaleMut == 1 then
		return
	end
	local function scalePart(part)
		part.Size*=scaleMut
	end
	local function scaleParticle(particle)
		Module.ScaleParticle(1,particle,scaleMut)
	end

	local scaleObjects = particlePart:GetDescendants()
	table.insert(scaleObjects,particlePart)
	for _,object in scaleObjects do
		if object:IsA('ParticleEmitter') then
			scaleParticle(object)
		elseif object:IsA('BasePart') then
			scalePart(object)
		end
	end
end

-- Emits particles and deletes them and the object part
function Module.EmitAndRemove(basePart:Instance|{ParticleEmitter},cf:CFrame?,optSettings:{}?)
	optSettings=optSettings or {}
	local dontClone = optSettings.dontClone
	local noAutoSmoke=optSettings.noAutoSmoke
	local maxFloorDist = optSettings.maxFloorDist
	local scaleMut = optSettings.scaleMut
	local raycastResult = optSettings.raycastResult
	if maxFloorDist then
		raycastResult = raycastResult or GeneralUse.GetFirstCollidable(cf.p+Vector3.new(0,.1,0),Vector3.new(0,-maxFloorDist,0))
		if not raycastResult then
			return
		end
		cf = cf and (cf - cf.p + raycastResult.Position)
	end
	
	local part
	if typeof(basePart) == 'Instance' then
		if dontClone then
			part=basePart
		else
			part=basePart:Clone()
		end
		if cf then
			part.CFrame = cf
			part.Parent =  DebrisFolder
		end
		if not noAutoSmoke then
			raycastResult = Module.SetSmokeColor(part,{raycastResult=raycastResult})
		end	
	else
		part=basePart
	end
	if scaleMut then
		Module.ScaleParticlePart(part,scaleMut)
	end
	Module.EmitFromModel(part,true)
	Module.RemoveVFX(part,{noDisable=true})
	return part,raycastResult
end

-- Adds particles to a character's body parts
function Module.AddParticlesToBody(target:Model,baseParticle:ParticleEmitter|{ParticleEmitter},stayLength:number?,validBodyParts:{string}?)
	local allParticles = {}
	for _,bodyPart in target:GetChildren() do
		if not bodyPart:IsA('BasePart') or bodyPart == target.PrimaryPart then
			continue
		end
		if validBodyParts and not table.find(validBodyParts,bodyPart.Name) then
			continue
		end

		local function addParticle(particle)
			local cloneParticle = particle:Clone()
			cloneParticle.Parent = bodyPart
			
			
			table.insert(allParticles,cloneParticle)
		end

		-- incase they send a folder of a particles instead of just 1
		if type(baseParticle) == "table" then
			for _,particle in baseParticle do
				addParticle(particle)
			end
		else
			addParticle(baseParticle)
		end
	end

	local function removeParticles()
		Module.RemoveVFX(allParticles,{removeDelay=stayLength})
	end
	if stayLength then
		removeParticles()
	else
		return removeParticles,allParticles
	end
end

function Module.ToggleVFX(part:BasePart,bool,ignoreBeams:boolean)
	for _,object in pairs(part:GetDescendants()) do
		if object:IsA("ParticleEmitter") or object:IsA('Trail') or (object:IsA('Beam') and not ignoreBeams) then
			object.Enabled = bool
		end
	end
end

function Module.EnableVFX(part:BasePart,ignoreBeams:boolean)
	Module.ToggleVFX(part,true,ignoreBeams)
end
function Module.DisableVFX(part:BasePart,ignoreBeams:boolean)
	Module.ToggleVFX(part,false,ignoreBeams)
end

function Module.CreateParticleScaler(particleParts:{BasePart})
	local particleScaler = {}
	local scaleParticles = {}
	
	for _,part in particleParts do
		for _, particle:ParticleEmitter in part:GetDescendants() do
			if not particle:IsA('ParticleEmitter') then
				continue
			end

			scaleParticles[particle] = particle:Clone()
		end
	end

	function particleScaler:Scale(alpha)
		for particle:ParticleEmitter,scaleParticle:ParticleEmitter in scaleParticles do
			Module.ScaleParticle(1,particle,alpha,nil,scaleParticle)
		end
	end
	return particleScaler
end

function Module.CreateBeamScaler(beamParts:{BasePart})
	local beamScaler = {}
	local scaleBeams = {}
	
	for _,part in beamParts do
		for _, beam:Beam in part:GetDescendants() do
			if not beam:IsA('Beam') then
				continue
			end

			scaleBeams[beam] = {
				CurveSize0 = beam.CurveSize0;
				CurveSize1 = beam.CurveSize1;
				Width0 = beam.Width0;
				Width1 = beam.Width1;
			}
		end
	end

	function beamScaler:Scale(alpha:number)
		for beam:Beam,scaleValues in scaleBeams do
			for valueName:string,value:number in scaleValues do
				beam[valueName] = alpha * value
			end
		end
	end
	
	return beamScaler
end
function Module.FlashScreen(flashSequence:{{settings:string|any; stayTime:number?}})
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Parent = Lighting
	task.spawn(function()
		for _:number,valueTab in flashSequence do
			for index,value in valueTab.settings do
				flash[index] = value
			end

			task.wait(valueTab.stayTime or .07)
		end

		flash:Destroy()
	end)
end

return Module

end)()

Base.NumberHelper = MergedNumberHelper
Base.GeneralUse = MergedGeneralUse
Base.TM = MergedTM
Base.EmitModule = MergedEmitModule

return Base
