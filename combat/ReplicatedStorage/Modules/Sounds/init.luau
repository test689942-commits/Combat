local Sounds = {}
Sounds.__index = Sounds;
local self = setmetatable({}, Sounds);

local RunService = game:GetService("RunService")
local ContentPA  = game:GetService("ContentProvider")

Sounds.Cache = {};
Sounds.Temp  = {};

local function CollectForPreload(Node)
	for Name, Value in next, Node do
		if type(Value) == "table" and Value.Id then
			local EntrySound   = Instance.new("Sound");
			EntrySound.Name    = tostring(Name);
			EntrySound.SoundId = Value.Id;

			self.Temp[#self.Temp + 1] = EntrySound;
		elseif type(Value) == "table" and Value.Pool == nil then
			CollectForPreload(Value);
		elseif type(Value) == "string" then
			local Sound   = Instance.new("Sound");
			Sound.Name 	  = tostring(Name);
			Sound.SoundId = Value;

			self.Temp[#self.Temp + 1] = Sound;
		end
	end
end

task.spawn(function()
	for _, Module in next, script:GetChildren() do
		if Module:IsA("ModuleScript") then
			self.Cache[Module.Name] = require(Module);
			CollectForPreload(self.Cache[Module.Name]);
		end
	end

	local Start = os.clock();
	ContentPA:PreloadAsync(self.Temp);
	warn(("Sound Preloader Complete; %.2f seconds"):format(os.clock() - Start))
	for _, v in next, self.Temp	do
		v:Destroy();
	end

	self.Temp = nil;
end)

local function ResolveNode(Root: string, Category: string?)
	local Node = self.Cache[Root];

	if Category then
		for _, Key in ipairs(string.split(Category, ".")) do
			Node = Node and Node[Key];
		end
	end

	return Node;
end

local function PickFromPool(Root: string, PoolPath: string)
	local Pool = ResolveNode(Root, PoolPath);

	if type(Pool) ~= "table" or #Pool == 0 then
		warn(("Sound pool is missing or empty : %s | %s"):format(Root, PoolPath));
		return nil;
	end

	return Pool[math.random(#Pool)];
end

local function ReadEntry(Entry, Root: string?)
	if type(Entry) ~= "table" then
		return Entry, {};
	end

	local Properties = {};
	local SoundId = Entry.Id;

	if Entry.Pool and Root then
		local Picked = PickFromPool(Root, Entry.Pool);

		if type(Picked) == "table" then
			SoundId = Picked.Id;

			for Property, Value in next, Picked do
				if Property ~= "Id" then
					Properties[Property] = Value;
				end
			end
		else
			SoundId = Picked;
		end
	end

	for Property, Value in next, Entry do
		if Property ~= "Id" and Property ~= "Pool" then
			Properties[Property] = Value;
		end
	end

	return SoundId, Properties;
end

Sounds.GetSound = function(Root: string, Sub: string, Category: string?) : (Sound | nil)
	if not Root or not Sub then return nil end;

	local Node = ResolveNode(Root, Category);

	if Node and Node[Sub] then
		local Sound = Instance.new("Sound");
		Sound.Name = Sub;
		Sound.RollOffMaxDistance = 150;
		local SoundId, Properties = ReadEntry(Node[Sub], Root);

		if not SoundId then
			Sound:Destroy();
			return nil;
		end

		Sound.SoundId = SoundId;

		for Property, Value in next, Properties do
			Sound[Property] = Value;
		end

		return Sound;
	else
		warn(("Tried To Index Nil Root And Sub : %s | %s%s"):format(Root, Sub, Category and (" (Category: " .. Category .. ")") or ""));
		return nil
	end
end

Sounds.GetSoundId = function(Root: string, Sub: string, Category: string?) : (string | nil)
	if not Root or not Sub then return nil end;

	local Node = ResolveNode(Root, Category);
	
	if Node and Node[Sub] then
		return (ReadEntry(Node[Sub], Root))
	else
		warn(("Tried To Index Nil Root And Sub : %s | %s%s"):format(Root, Sub, Category and (" (Category: " .. Category .. ")") or ""));
		return nil
	end
end

Sounds.GetSoundTree = function(Root: string) : (string | nil)
	if not Root then return nil end;
	
	if self.Cache[Root] then 
		return self.Cache[Root] 
	else
		warn(("Tried To Index Nil Root : %s"):format(Root));
		return nil;
	end;
end


Sounds.DetectSound = function(Sub: string)
	if not Sub then return false end
	
	for _, Module in pairs(self.Cache) do
		if Module[Sub] then return true end
	end
	
	return false 
end

Sounds.DetectSpecificSound = function(Root: string, Sub: string)	
	if not Root or not self.Cache[Root] then return end
	
	
	if self.Cache[Root][Sub] then 
		return true
	end
	
	return false
end

return Sounds
