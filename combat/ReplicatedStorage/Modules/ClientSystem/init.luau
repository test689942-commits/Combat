local System = {}
System.Service = setmetatable({}, {
	__index = function(self, Name)
		local Service = game:GetService(Name)
		self[Name] = Service
		return Service
	end,
})

System.Service.Players			 = game:GetService("Players");
System.Service.RunService 		 = game:GetService("RunService");
System.Service.HttpsService      = game:GetService("HttpService");
System.Service.TweenService 	 = game:GetService("TweenService");
System.Service.PhysicsService 	 = game:GetService("PhysicsService")
System.Service.TextChatService   = game:GetService("TextChatService");
System.Service.UserInputService  = game:GetService("UserInputService");
System.Service.CollectionService = game:GetService("CollectionService");
System.Service.ReplicatedStorage = game:GetService("ReplicatedStorage");
System.Service.Lighting 		 = game:GetService("Lighting")
System.Service.ContextActionService = game:GetService("ContextActionService")

System.Utilities  = require(script.Parent:WaitForChild("Utilities"));
System.Library 	  = require(script.Parent:WaitForChild("Library"));
System.Animations = require(script.Parent:WaitForChild("Animations"));

System.Sounds     = require(script.Parent:WaitForChild("Sounds"));
System.Moves      = require(script.Parent:WaitForChild("Moves"));


System.Assets = System.Service.ReplicatedStorage:WaitForChild("Assets");
System.Effects = System.Assets.Effects





System.Player = System.Service.Players.LocalPlayer;
System.Mouse = System.Player:GetMouse();

System.Modules = {};

System.CameraEffectInfo = {
	Offset = Vector3.new(0, 0, 0),
};

System.Character = nil;
System.Humanoid  = nil;
System.Animator  = nil;
System.Root 	 = nil;

System.BaseSpeed = 12;
System.SprintSpeed = 24;
System.FastSprintSpeed = 28;
System.BaseJump  = 40;
System.SlideSoundId = "rbxassetid://6429226498";
System.Sliding = false;

System.CurrentInput = {};
System.Speeds   = {};
System.Status   = {};
System.Stuns	= {};
System.Actions  = {};
System.Frames   = {};

System.RunAnim  = nil;

System.Running  = false;
System.InAir    = false;
System.Dashing  = false;

System.FallHeight = 0;
System.Landed  = false;
System.Climbing = false;
System.Buffer   = false;


System.Settings = {

	KeyBinds = {},
	DefaultBinds = {
		Dash    = System.Moves.Dash.Key;
		Sprint  = Enum.KeyCode.W;
		Slide   = Enum.KeyCode.LeftControl;
		Jump    = Enum.KeyCode.Space;
	};
};

System.ResetBinds = function()
	System.Settings.KeyBinds = table.clone(System.Settings.DefaultBinds)
end

System.isKeydown = function(...: {string}): boolean	
	local down = true
	for i, v in { ... } do
		local success, pressed = pcall(function()
			if Enum.KeyCode[v] then
				return System.Service.UserInputService:IsKeyDown(Enum.KeyCode[v])				
			end

			if Enum.UserInputType[v] then
				return System.Service.UserInputService:IsMouseButtonPressed(Enum.UserInputType[v])
			end; return false 
		end)

		if not success or not pressed then 
			down = false; break 
		end
	end; return down
end


System.ResetBinds()

return System
