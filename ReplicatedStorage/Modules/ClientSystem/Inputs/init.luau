local Inputs = {}; local Client = require(script.Parent);
Inputs.__index = Inputs;
local self = setmetatable({}, Inputs)

export type InputProps = {
	Name: string,
	KeyCode: (Enum.KeyCode | Enum.UserInputType)?,
	SubCategory: string?,
	Callbacks: {
		InputBegan: (InputObject: InputObject, Client: any) -> (...any),
		InputEnded: (InputObject: InputObject, Client: any) -> (...any),
		InputChanged: (InputObject: InputObject, Client: any) -> (...any)
	}
}

Inputs.InputModules = {};

local function ContextAction(ActionName, InputState, InputObject)
	local Index = table.find(Client.CurrentInput, ActionName)
	local InputFunction

	if InputState == Enum.UserInputState.Begin then
		InputFunction = self.InputModules[ActionName].InputBegan;
		if not Index then table.insert(Client.CurrentInput, ActionName) end;
	elseif InputState == Enum.UserInputState.End then
		InputFunction = self.InputModules[ActionName].InputEnded;
		if Index then table.remove(Client.CurrentInput, Index) end;
	elseif InputState == Enum.UserInputState.Change then
		InputFunction = self.InputModules[ActionName].InputChanged;
	end

	if InputFunction then
		InputFunction(InputObject, Client);
	end

	return Enum.ContextActionResult.Pass;
end

function Inputs.BindInput(self, props: InputProps)
	local keyCode = if props.KeyCode then props.KeyCode
		elseif props.SubCategory and Client.Settings.KeyBinds[props.SubCategory][props.Name] then Client.Settings.KeyBinds[props.SubCategory][props.Name]
		else Client.Settings.KeyBinds[props.Name]

	if self.InputModules[props.Name] then
		return
	end

	self.InputModules[tostring(props.Name)] = {}

	for index, callback in props.Callbacks do
		self.InputModules[tostring(props.Name)][index] = callback
	end

	if not keyCode then
		return
	end

	Client.Service["ContextActionService"]:BindAction(props.Name, ContextAction, false, keyCode)
end

for _, Module in script:GetChildren() do
	if not Module:IsA("ModuleScript") then
		continue
	end

	self:BindInput({
		Name = Module.Name,
		Callbacks = require(Module)
	})
end

return Inputs