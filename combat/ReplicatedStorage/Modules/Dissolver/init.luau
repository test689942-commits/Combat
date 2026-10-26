--!native
--!nonstrict

local RunService = game:GetService("RunService")
if RunService:IsServer() then
	error("Dissolver does not run on the server!")
end

local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
	
-- Modules
local Types = require(script.Types)

-- Functions
local writeu8 = buffer.writeu8
local readu8 = buffer.readu8
local readu32 = buffer.readu32

-- Variables
local DefaultWorker = script.Actor
local CurrentWorker = 1
local Workers: {typeof(DefaultWorker)} = {}
local Processing: ProcessingImages = {}
local ImageCache: {[TextureGroup]: ImageCache} = {}

local EmptyEmissiveMask = Color3.fromRGB(0, 0, 0)

-- Module
local Dissolver = {}
Dissolver.__index = Dissolver

-- Types
export type DissolverObject = typeof(Dissolver.NewDissolver())
export type TextureGroup = typeof(Dissolver.NewTextureGroup())

type TextureMaps = {
	ColorMaps: {buffer},
	EmissiveMasks: {buffer}?,
	EmissiveMaskContent: Content?,
	MetalnessMapContent: Content?,
	NormalMapContent: Content?,
	RoughnessMapContent: Content?,
}

type ImageCache = {
	[Types.DissolverSetting]: TextureMaps
}

type ProcessingImages = {
	{
		TextureGroup: TextureGroup,
		Setting: Types.DissolverSetting
	}
}



----------// Global Settings //----------


local PrintMessages = false --For debug purposes
local FPS = 30
local InitialEmissiveStrength = 5
local NumberOfWorkers = 64
local PixelsPerWorker = 4096


----------// Private Functions //----------


-- Returns the next worker to use and the process id for that worker
function GetNextWorker(): (Actor, string)
	local Worker = Workers[CurrentWorker]
	
	CurrentWorker += 1
	if CurrentWorker > NumberOfWorkers then
		CurrentWorker = 1
	end

	return Worker, HttpService:GenerateGUID()
end

-- Returns whether the value matches the given types
function CheckTypeof(Value: any, ...: string): boolean
	for i, Type in ipairs{...} do
		if typeof(Value) == Type then
			return true
		end
	end
	return false
end

-- Returns the amount of workers to use and the amount of rows each worker will process given the resolution in pixels
function GetWorkersToUseAndRows(Resolution: number): (number, number)
	local Pixels = Resolution ^ 2
	local WorkersToUse = math.ceil(Pixels / PixelsPerWorker)
	local RowsPerWorker = math.ceil(Resolution / WorkersToUse)
	WorkersToUse = math.ceil(Resolution / RowsPerWorker)
	
	return WorkersToUse, RowsPerWorker
end

-- Returns the amount of workers to use, the amount of rows each worker will process, and the amount of images to generate
function GetDataFromSetting(Setting: Types.DissolverSetting): (number, number, number)
	local HalfResolution = math.ceil(Setting.Resolution / 2)
	
	local WorkersToUse, RowsPerWorker = GetWorkersToUseAndRows(HalfResolution)
	local ImagesToGenerate = math.ceil(Setting.Time * FPS)
	
	return WorkersToUse, RowsPerWorker, ImagesToGenerate
end

-- Draws an image on the given pixel buffer and its emissive buffer if provided
function DrawToPixelBuffer(PixelBuffer: buffer, EmissiveBuffer: buffer?, Setting: Types.DissolverSetting, Threshold: number, RowsPerWorker: number, WorkersToUse: number): (buffer, buffer?)
	local HalfResolution = math.ceil(Setting.Resolution / 2)
	local TotalPixels = Setting.Resolution ^ 2
	local EdgeColor = Setting.EdgeColor
	local R, G, B = EdgeColor.R * 255, EdgeColor.G * 255, EdgeColor.B * 255
	local CompletedWorkers = 0
	for Row = 0, HalfResolution - 1, RowsPerWorker do -- Only half the rows will be processed. The other half will be a reflection of the first half.
		local EndRow = math.clamp(Row + RowsPerWorker, 0, HalfResolution)
		local Worker, ProcessId = GetNextWorker()
		local Connection
		Connection = Worker.Finished.Event:Connect(function(Id: string, TransparentPixels: buffer, ColoredPixels: buffer, TransparenciesChanged: number, ColorsChanged: number)
			local Time = os.clock()
			if ProcessId ~= Id then
				return
			end
			
			Connection:Disconnect()
			for i = 1, TransparenciesChanged do
				local Offset = (i - 1) * 4
				local PixelPosition = readu32(TransparentPixels, Offset)
				
				local ReflectedPosition = TotalPixels - PixelPosition - 1
				
				writeu8(PixelBuffer, PixelPosition * 4 + 3, 0)
				writeu8(PixelBuffer, ReflectedPosition * 4 + 3, 0)
			end
			
			for i = 1, ColorsChanged do
				local Offset = (i - 1) * 4
				local PixelPosition = readu32(ColoredPixels, Offset)
				local PixelOffset = PixelPosition * 4

				local ReflectedPosition = TotalPixels - PixelPosition - 1
				local ReflectedOffset = ReflectedPosition * 4
				
				-- Color map buffer
				writeu8(PixelBuffer, PixelOffset + 0, R)
				writeu8(PixelBuffer, ReflectedOffset + 0, R)
				writeu8(PixelBuffer, PixelOffset + 1, G)
				writeu8(PixelBuffer, ReflectedOffset + 1, G)
				writeu8(PixelBuffer, PixelOffset + 2, B)
				writeu8(PixelBuffer, ReflectedOffset + 2, B)
				
				-- Emissive buffer
				if EmissiveBuffer then
					writeu8(EmissiveBuffer, PixelOffset + 0, 255)
					writeu8(EmissiveBuffer, ReflectedOffset + 0, 255)
				end
			end

			CompletedWorkers += 1
		end)
		
		Worker:SendMessage("ProcessImage", ProcessId, Setting, Threshold, Row, EndRow)
	end
	
	while CompletedWorkers ~= WorkersToUse do
		task.wait()
	end
	
	return PixelBuffer, EmissiveBuffer
end

-- Returns whether two tables contain the same values
function TableIsEqual(Table1: {any}, Table2: {any}): boolean
	if GetTableLength(Table1) ~= GetTableLength(Table2) then
		return false
	end
	
	for Key, Value in pairs(Table1) do
		if Table2[Key] ~= Value then
			return false
		end
	end
	return true
end

-- Finds and returns the images associated with the given TextureGroup and setting
function FindImages(TextureGroup: TextureGroup, Setting: Types.DissolverSetting): (TextureMaps?, TextureGroup?, Types.DissolverSetting?)
	local Images: ImageCache?
	local OriginalTextureGroup
	for Textures, ImageDict in pairs(ImageCache) do
		if TableIsEqual(TextureGroup, Textures) then
			OriginalTextureGroup = Textures
			Images = ImageDict
			break
		end
	end
	
	if not Images then
		return nil, nil, nil
	end

	for OriginalSetting, ImageTable in pairs(Images) do
		if TableIsEqual(Setting, OriginalSetting) then
			return ImageTable, OriginalTextureGroup, OriginalSetting
		end
	end
end

-- Returns whether the images for a given TextureGroup and setting are still being processed
function IsProcessing(TextureGroup: TextureGroup, Setting: Types.DissolverSetting): boolean
	for i, Table in ipairs(Processing) do
		if TableIsEqual(TextureGroup, Table.TextureGroup) and TableIsEqual(Setting, Table.Setting) then
			return true
		end
	end
	return false
end

-- Finds and returns the closest image to the given time
function FindImageAtTime(Images: {buffer}, Time: number): (buffer?, number)
	local Index = math.round(Time * FPS * ((#Images - 1) / #Images)) + 1
	return Images[Index], Index
end

-- Returns the number of elements in a table
function GetTableLength(Table: {[any]: any}): number
	local Length = 0
	for Key, Value in pairs(Table) do
		Length += 1
	end
	
	return Length
end

-- If the MeshPart has a texture, returns the texture. Else, returns the color of the MeshPart
function GetTextureUriOrColor(MeshPart: MeshPart): string | Color3
	if MeshPart.TextureContent.Uri == "" then
		return MeshPart.Color
	else
		return MeshPart.TextureID
	end
end

-- Creates a new editable image for the given source and size; or nil if no source is given. Can also error if the device runs out of EditableImage memory budget.
function CreateEditableImageFor(Source: string | Color3, Size: Vector2): EditableImage?
	if not Source then
		return nil
	end
	
	local EditableImage = AssetService:CreateEditableImage{Size = Size}
	if not EditableImage then
		error("Out of EditableImage memory budget")
	end
	
	if typeof(Source) == "string" then
		local SourceImage = AssetService:CreateEditableImageAsync(Content.fromUri(Source))
		if not SourceImage then
			error("Out of EditableImage memory budget")
		end
		
		local SizeRatio = Size / SourceImage.Size
		EditableImage:DrawImageTransformed(Size / 2, SizeRatio, 0, SourceImage, {CombineType = Enum.ImageCombineType.Overwrite})
		SourceImage:Destroy()
		
	else
		EditableImage:DrawRectangle(Vector2.zero, Size, Source, 0, Enum.ImageCombineType.Overwrite)
	end
	
	return EditableImage
end

-- Creates a new image buffer for the given source and size; or nil if no source is given. Can also error if the device runs out of EditableImage memory budget.
function CreateBufferFor(Source: string | Color3, Size: Vector2): buffer?
	local EditableImage = CreateEditableImageFor(Source, Size)
	if not EditableImage then
		return nil
	end
	
	return EditableImage:ReadPixelsBuffer(Vector2.zero, Size)
end

-- Draws a pixel buffer to an EditableImage
function DrawToImage(TargetImage: EditableImage, PixelBuffer: buffer)
	TargetImage:WritePixelsBuffer(Vector2.zero, TargetImage.Size, PixelBuffer)
end


----------// Library Functions //----------


--[[
Creates a new DissolverSetting from the given values. Leaving arguments nil will use the default values.

For the sake of performance and memory, a resolution of above 512 is strongly discouraged.

<strong>Time</strong> <em>(optional)</em>: How long the whole dissolve progress will take, in seconds. <em>Default: 1</em>
<strong>Resolution</strong> <em>(optional)</em>: The resolution of the texture, in pixels. <em>Default: 256</em>
<strong>NoiseZoomOut</strong> <em>(optional)</em>: Higher values result in a more zoomed-out noise. <em>Default: 20</em>
<strong>EdgeColor</strong> <em>(optional)</em>: The color of the colored edge. <em>Default: (255, 255, 255)</em>
<strong>EdgeSize</strong> <em>(optional)</em>: The size of the colored edge. Ranges from 0 to 1. <em>Default: 0.05</em>
<strong>EdgeGlowEnabled</strong> <em>(optional)</em>: Whether the colored edge will glow. If false, then no emissive masks for the edge will be generated, saving memory. <em>Default: true</em>
]]
function Dissolver.NewSetting(Time: number?, Resolution: number?, NoiseZoomOut: number?, EdgeColor: Color3?, EdgeSize: number?, EdgeGlowEnabled: boolean?): Types.DissolverSetting
	assert(CheckTypeof(Time, "number", "nil"), "Time must be a number")
	assert(CheckTypeof(Resolution, "number", "nil"), "Resolution must be a number")
	assert(CheckTypeof(NoiseZoomOut, "number", "nil"), "NoiseZoomOut must be a number")
	assert(CheckTypeof(EdgeColor, "Color3", "nil"), "EdgeColor must be a Color3")
	assert(CheckTypeof(EdgeSize, "number", "nil"), "EdgeSize must be a number")
	assert(CheckTypeof(EdgeGlowEnabled, "boolean", "nil"), "EdgeGlowEnabled must be a boolean")
	
	local NewSetting = {
		-- Default Values
		Time = Time or 1,
		NoiseZoomOut = NoiseZoomOut or 20,
		Resolution = math.round(Resolution or 256),
		EdgeColor = EdgeColor or Color3.fromRGB(255, 255, 255),
		EdgeSize = EdgeSize or 0.05,
		EdgeGlowEnabled = if EdgeGlowEnabled == nil then true else EdgeGlowEnabled,
	}
	
	assert(NewSetting.Time > 0, "Time cannot be below 0")
	assert(NewSetting.Resolution >= 1, "Resolution cannot be below 1")
	
	table.freeze(NewSetting)
	
	return NewSetting
end

--[[
Creates a new TextureGroup to be used for computing textures.

<strong>ColorMap</strong>: The ColorMap ContentID to be used. If it is instead a Color3, then the color map will be a solid color.
<strong>MetalnessMap</strong> <em>(optional)</em>: The MetalnessMap ContentID.
<strong>NormalMap</strong> <em>(optional)</em>: The NormalMap ContentID.
<strong>RoughnessMap</strong> <em>(optional)</em>: The RoughnessMap ContentID.
<strong>EmissiveMask</strong> <em>(optional)</em>: The EmissiveMask ContentID.
]]
function Dissolver.NewTextureGroup(ColorMap: string | Color3, MetalnessMap: string?, NormalMap: string?, RoughnessMap: string?, EmissiveMask: string?)
	assert(CheckTypeof(ColorMap, "string", "Color3"), "ColorMap must be a string or Color3")
	assert(CheckTypeof(MetalnessMap, "string", "nil"), "MetalnessMap must be a string")
	assert(CheckTypeof(NormalMap, "string", "nil"), "NormalMap must be a string")
	assert(CheckTypeof(RoughnessMap, "string", "nil"), "RoughnessMap must be a string")
	assert(CheckTypeof(EmissiveMask, "string", "nil"), "RoughnessMap must be a string")
	
	local NewTextureGroup = {
		ColorMap = ColorMap,
		MetalnessMap = MetalnessMap,
		NormalMap = NormalMap,
		RoughnessMap = RoughnessMap,
		EmissiveMask = EmissiveMask
	}
	
	table.freeze(NewTextureGroup)
	
	return NewTextureGroup
end

--[[
Creates a new TextureGroup based on the given MeshPart.

If the MeshPart has a SurfaceAppearance, then all of its maps will be used. Otherwise, if the MeshPart's TextureID is not empty, then it will be used as the ColorMap. Else, its Color will be used.

<strong>MeshPart</strong>: The MeshPart to get the TextureGroup from.
]]
function Dissolver.NewTextureGroupFromMesh(MeshPart: MeshPart): TextureGroup
	assert(CheckTypeof(MeshPart, "Instance") and MeshPart:IsA("MeshPart"), "MeshPart must be a MeshPart")
	
	local SurfaceAppearance = MeshPart:FindFirstChildWhichIsA("SurfaceAppearance")
	
	local NewTextureGroup = {
		ColorMap = if SurfaceAppearance then SurfaceAppearance.ColorMapContent.Uri elseif MeshPart.TextureID ~= "" then MeshPart.TextureID else MeshPart.Color,
		MetalnessMap = if SurfaceAppearance then SurfaceAppearance.MetalnessMapContent.Uri else nil,
		NormalMap = if SurfaceAppearance then SurfaceAppearance.NormalMapContent.Uri else nil,
		RoughnessMap = if SurfaceAppearance then SurfaceAppearance.RoughnessMapContent.Uri else nil,
		EmissiveMask = if SurfaceAppearance then SurfaceAppearance.EmissiveMaskContent.Uri else nil,
	}
	
	table.freeze(NewTextureGroup)

	return NewTextureGroup
end

--[[
Returns a single texture and optionally an emissive mask using the specified Setting, Threshold and Source. Useful for creating custom dissolvers.

<strong>NOTE:</strong> This function can yield.

<strong>Setting</strong>: A DissolverSetting object.
<strong>Threshold</strong>: Threshold ranging from 0 (no dissolve) to 1 (fully dissolved).
<strong>Source</strong>: The source of the computed texture. Can either be an <strong>ContentID</strong> or <strong>Color3</strong>.
<strong>EmissiveSource</strong> <em>(optional)</em>: The ContentID of the emissive mask. This is ignored if EdgeGlowEnabled is false.
]]
function Dissolver.ComputeSingleImage(Setting: Types.DissolverSetting, Threshold: number, Source: string | Color3, EmissiveSource: string?): (buffer?, buffer?)
	assert(CheckTypeof(Threshold, "number"), "Threshold must be a number")
	assert(CheckTypeof(Source, "string", "Color3"), "Source must be a string or Color3")
	assert(CheckTypeof(EmissiveSource, "string", "nil"), "EmissiveSource must be a string")
	
	local Size = Vector2.new(Setting.Resolution, Setting.Resolution)
	local WorkersToUse, RowsPerWorker, ImagesToGenerate = GetDataFromSetting(Setting)
	
	local ColorMapBuffer = CreateBufferFor(Source, Size)
	local EmissiveBuffer = if Setting.EdgeGlowEnabled then CreateBufferFor(EmissiveSource or EmptyEmissiveMask, Size) else nil
	
	return DrawToPixelBuffer(ColorMapBuffer, EmissiveBuffer, Setting, Threshold, RowsPerWorker, WorkersToUse)
end

--[[
<em>Not to be confused with <code>Dissolver.PrecomputeImages()</code></em>.

Returns an array of textures (and optionally emissive masks) ordered from least dissolved to most dissolved using the specified Setting and Source. Useful for creating custom dissolvers

<strong>NOTE</strong>: This function will yield for up to several seconds.

<strong>Setting</strong>: A DissolverSetting object.
<strong>Source</strong>: The source of the computed texture. Can either be an <strong>ContentID</strong> or <strong>Color3</strong>.
<strong>EmissiveSource</strong> <em>(optional)</em>: The ContentID of the emissive mask. This is ignored if EdgeGlowEnabled is false.
]]
function Dissolver.ComputeImages(Setting: Types.DissolverSetting, Source: string | Color3, EmissiveSource: string?): ({buffer}, {buffer}?)
	assert(CheckTypeof(Source, "string", "Color3"), "Source must be a string or Color3")
	assert(CheckTypeof(EmissiveSource, "string", "nil"), "EmissiveSource must be a string")
	
	local StartTime = os.clock()
	local ColorMaps = {}
	local EmissiveMasks = {}
	local Resolution = Setting.Resolution
	local TotalPixels = Resolution ^ 2
	local Size = Vector2.new(Resolution, Resolution)
	
	local OriginalColorBuffer = CreateBufferFor(Source, Size)
	local OriginalEmissiveBuffer = if Setting.EdgeGlowEnabled then CreateBufferFor(EmissiveSource or EmptyEmissiveMask, Size) else nil
	
	local WorkersToUse, RowsPerWorker, ImagesToGenerate = GetDataFromSetting(Setting)
	local CompletedImages = 0
	
	for i = 1, ImagesToGenerate do
		local Threshold = (i - 1) / (ImagesToGenerate - 1)
		
		local ColorMapBuffer = buffer.create(TotalPixels * 4)
		buffer.copy(ColorMapBuffer, 0, OriginalColorBuffer, 0)
		
		local EmissiveBuffer
		if OriginalEmissiveBuffer then 
			EmissiveBuffer = buffer.create(TotalPixels * 4)
			buffer.copy(EmissiveBuffer, 0, OriginalEmissiveBuffer, 0)
		end
		
		ColorMaps[i], EmissiveMasks[i] = DrawToPixelBuffer(ColorMapBuffer, EmissiveBuffer, Setting, Threshold, RowsPerWorker, WorkersToUse)
		if PrintMessages then
			print(`Completed image {i} of {ImagesToGenerate}`)
		end
		
		CompletedImages += 1
	end
	
	while CompletedImages ~= ImagesToGenerate do
		task.wait()
	end
	
	if PrintMessages then
		print(`Generated {ImagesToGenerate} images in {os.clock() - StartTime} seconds`)
	end
	
	return ColorMaps, if Setting.EdgeGlowEnabled then EmissiveMasks else nil
end

--[[
<em>Not to be confused with <code>Dissolver.ComputeImages()</code></em>.

Computes the textures from the given TextureGroup and Setting and caches them for later use. This function does nothing if the textures are already cached.

<strong>NOTE</strong>: Computing textures will yield for up to several seconds.

<strong>Setting</strong>: A DissolverSetting object.
<strong>TextureGroup</strong>: The textures used for the computed texture.
]]
function Dissolver.PrecomputeImages(TextureGroup: TextureGroup, Setting: Types.DissolverSetting): TextureMaps?
	assert(CheckTypeof(TextureGroup, "table"), "TextureGroup must be a TextureGroup")
	assert(CheckTypeof(Setting, "table"), "Setting must be a DissolverSetting")
	
	while IsProcessing(TextureGroup, Setting) do
		task.wait()
	end
	
	local ExistingImages = FindImages(TextureGroup, Setting)
	if ExistingImages then
		return ExistingImages
	end
	
	local Size = Vector2.new(Setting.Resolution, Setting.Resolution)
	local ProcessingData = {TextureGroup = TextureGroup, Setting = Setting}
	table.insert(Processing, ProcessingData)
	
	local ColorMaps, EmissiveMasks
	local EmissiveMaskContent
	local MetalnessMap
	local NormalMap
	local RoughnessMap
	
	local Success, Error = pcall(function() 
		ColorMaps, EmissiveMasks = Dissolver.ComputeImages(Setting, TextureGroup.ColorMap, TextureGroup.EmissiveMask)
		EmissiveMaskContent = if not Setting.EdgeGlowEnabled then CreateEditableImageFor(TextureGroup.EmissiveMask, Size) else nil
		MetalnessMap = CreateEditableImageFor(TextureGroup.MetalnessMap, Size)
		NormalMap = CreateEditableImageFor(TextureGroup.NormalMap, Size)
		RoughnessMap = CreateEditableImageFor(TextureGroup.RoughnessMap, Size)
	end)
	
	if not Success then
		table.remove(Processing, table.find(Processing, ProcessingData))
		error("Out of EditableImage memory budget during computation.")
		return nil
	end
	
	local Textures = {
		ColorMaps = ColorMaps, 
		EmissiveMasks = EmissiveMasks, -- Only if EdgeGlowEnabled is true
		EmissiveMaskContent = if EmissiveMaskContent then Content.fromObject(EmissiveMaskContent) else nil,  -- Only if EdgeGlowEnabled is false
		MetalnessMapContent = if MetalnessMap then Content.fromObject(MetalnessMap) else nil,
		NormalMapContent = if NormalMap then Content.fromObject(NormalMap) else nil,
		RoughnessMapContent = if RoughnessMap then Content.fromObject(RoughnessMap) else nil
	}
	
	local Cache = ImageCache[TextureGroup]
	if not Cache then
		Cache = {}
		ImageCache[TextureGroup] = Cache
	end
	
	Cache[Setting] = Textures
	
	table.remove(Processing, table.find(Processing, ProcessingData))
	
	return Textures
end

--[[
Removes and destroys the textures associated with the given TextureGroup and Setting from the cache, freeing memory.

<strong>TextureGroup</strong>: The TextureGroup used for computing the textures.
<strong>Setting</strong>: The DissolverSetting used for computing the textures.
]]
function Dissolver.RemoveFromCache(TextureGroup: TextureGroup, Setting: Types.DissolverSetting)
	assert(CheckTypeof(TextureGroup, "table"), "TextureGroup must be a string or TextureGroup")
	assert(CheckTypeof(Setting, "table"), "Setting must be a DissolverSetting")
	
	local Textures, OriginalTextureGroup, OriginalSetting = FindImages(TextureGroup, Setting)
	if not Textures then
		return
	end
	
	if not Setting.EdgeGlowEnabled and Textures.EmissiveMaskContent then 
		Textures.EmissiveMaskContent.Object:Destroy() 
	end
	
	if Textures.MetalnessMapContent then 
		Textures.MetalnessMapContent.Object:Destroy() 
	end
	
	if Textures.NormalMapContent then 
		Textures.NormalMapContent.Object:Destroy() 
	end
	
	if Textures.RoughnessMapContent then 
		Textures.RoughnessMapContent.Object:Destroy() 
	end
	
	ImageCache[OriginalTextureGroup][OriginalSetting] = nil
	if GetTableLength(ImageCache[OriginalTextureGroup]) == 0 then
		ImageCache[OriginalTextureGroup] = nil
	end
end

--[[
Creates a new DissolverObject.

If the source texture is not already cached, they will be automatically computed and cached using Dissolver.PrecomputeImages(); yielding for several seconds.

<strong>NOTE</strong>: You should not make multiple active DissolverObjects on one MeshPart. There should be at most one DissolverObject active on a MeshPart at any given time.

<strong>TextureGroup</strong>: The TextureGroup used for the textures.
<strong>Setting</strong>: The DissolverSetting used for the textures.
<strong>InitialMeshParts</strong> <em>(optional)</em>: The initial array of MeshParts to be added to this DissolverObject.
]]
function Dissolver.NewDissolver(TextureGroup: TextureGroup, Setting: Types.DissolverSetting, InitialMeshParts: {MeshPart}?)
	assert(CheckTypeof(TextureGroup, "table"), "TextureGroup must be a string or TextureGroup")
	assert(CheckTypeof(Setting, "table"), "Setting must be a DissolverSetting")
	assert(CheckTypeof(InitialMeshParts, "table", "nil"), "InitialMeshParts must be an array of MeshParts")
	
	InitialMeshParts = InitialMeshParts or {}
	for i, MeshPart in ipairs(InitialMeshParts) do
		assert(CheckTypeof(MeshPart, "Instance") and MeshPart:IsA("MeshPart"), "InitialMeshParts must be an array of MeshParts")
	end
	
	local Size = Vector2.new(Setting.Resolution, Setting.Resolution)
	local TextureMaps = Dissolver.PrecomputeImages(TextureGroup, Setting)
	
	local ColorMapImage = AssetService:CreateEditableImage{Size = Size}
	if not ColorMapImage then
		error("Out of EditableImage memory budget during DissolverObject creation")
		return nil
	end
	DrawToImage(ColorMapImage, TextureMaps.ColorMaps[1])
	
	local EmissiveMask
	if Setting.EdgeGlowEnabled then
		EmissiveMask = AssetService:CreateEditableImage{Size = Size}
		if not EmissiveMask then
			error("Out of EditableImage memory budget during DissolverObject creation")
			return nil
		end
		
		DrawToImage(EmissiveMask, TextureMaps.EmissiveMasks[1])
	end
	
	local FinishedEvent = Instance.new("BindableEvent")
	local self = setmetatable({}, Dissolver)
	self.TextureMaps = TextureMaps
	self.Time = 0
	self.EmissiveStrength = InitialEmissiveStrength
	self.TextureGroup = TextureGroup
	self.Setting = Setting
	self._ColorMap = ColorMapImage
	self._ColorMapContent = Content.fromObject(ColorMapImage)
	
	if Setting.EdgeGlowEnabled then
		self._EmissiveMask = EmissiveMask
		self._EmissiveMaskContent = Content.fromObject(EmissiveMask)
	end
	
	self.DissolveFinished = FinishedEvent.Event
	
	self._FinishedEvent = FinishedEvent
	self._CurrentImageIndex = 1
	self._DissolveConnection = nil
	self._MeshParts = {}
	
	for i, MeshPart in ipairs(InitialMeshParts) do
		self:AddMeshPart(MeshPart)
	end
	
	return self
end


----------// DissolverObject Methods //----------

--[[
Adds a MeshPart to the DissolverObject, creating a new SurfaceAppearance, and removing the old SurfaceAppearance if there was one.

<strong>MeshPart</strong>: The MeshPart to be added.
]]
function Dissolver:AddMeshPart(MeshPart: MeshPart)
	local self: DissolverObject = self
	assert(CheckTypeof(MeshPart, "Instance") and MeshPart:IsA("MeshPart"), "MeshPart must be a MeshPart")
	
	if self._MeshParts[MeshPart] then
		return
	end
	
	local OriginalSurface = MeshPart:FindFirstChildWhichIsA("SurfaceAppearance")
	local TextureMaps = self.TextureMaps
	local NewSurface = AssetService:CreateSurfaceAppearanceAsync{
		ColorMap = self._ColorMapContent,
		MetalnessMap = TextureMaps.MetalnessMapContent,
		NormalMap = TextureMaps.NormalMapContent,
		RoughnessMap = TextureMaps.RoughnessMapContent,
		EmissiveMask = if self.Setting.EdgeGlowEnabled then self._EmissiveMaskContent else TextureMaps.EmissiveMaskContent
	}
	
	if OriginalSurface then
		OriginalSurface.Parent = nil
	end
	NewSurface.AlphaMode = Enum.AlphaMode.Transparency
	NewSurface.EmissiveStrength = self.EmissiveStrength
	NewSurface.Parent = MeshPart
	
	self._MeshParts[MeshPart] = {
		OriginalSurface = OriginalSurface,
		NewSurface = NewSurface,
	}
end

--[[
Removes a MeshPart from the DissolverObject, destroying the new SurfaceAppearance, and restoring the old SurfaceAppearance if there was one.

<strong>MeshPart</strong>: The MeshPart to be removed.
]]
function Dissolver:RemoveMeshPart(MeshPart: MeshPart)
	local self: DissolverObject = self
	assert(CheckTypeof(MeshPart, "Instance") and MeshPart:IsA("MeshPart"), "MeshPart must be an Instance")

	local Data = self._MeshParts[MeshPart]
	if not Data then
		return
	end
	
	Data.NewSurface:Destroy()
	if Data.OriginalSurface then
		Data.OriginalSurface.Parent = MeshPart
	end
	
	self._MeshParts[MeshPart] = nil
end

--[[
Sets and updates the emissive strength of all MeshParts.

<strong>Strength</strong>: The new emissive strength.
]]
function Dissolver:SetEmissiveStrength(Strength: number)
	local self: DissolverObject = self
	assert(CheckTypeof(Strength, "number"), "Strength must be a number")
	
	self.EmissiveStrength = Strength
	
	for MeshParts, Data in pairs(self._MeshParts) do
		Data.NewSurface.EmissiveStrength = Strength
	end
end

--[[
Sets the current dissolve progress using true time.

<strong>TrueTime</strong>: The time to be set in seconds. Should be in the range from 0 to the maximum time specified in the settings.
]]
function Dissolver:SetTrueTime(TrueTime: number)
	local self: DissolverObject = self
	assert(CheckTypeof(TrueTime, "number"), "TrueTime must be a number")
	
	self.Time = math.clamp(TrueTime, 0, self.Setting.Time)
	local ColorMap, Index = FindImageAtTime(self.TextureMaps.ColorMaps, self.Time)
	
	if self._CurrentImageIndex == Index then
		return
	end
	
	self._CurrentImageIndex = Index
	DrawToImage(self._ColorMap, ColorMap)
	
	if self.Setting.EdgeGlowEnabled then
		local EmissiveMask = self.TextureMaps.EmissiveMasks[Index]
		DrawToImage(self._EmissiveMask, EmissiveMask)
	end
end

--[[
Sets the current dissolve progress using normalized time.

<strong>Time</strong>: The time to be set in the range from 0 to 1.
]]
function Dissolver:SetTime(Time: number)
	local self: DissolverObject = self
	assert(CheckTypeof(Time, "number"), "Time must be a number")
	
	self:SetTrueTime(Time * self.Setting.Time)
end

--[[
Dissolves the MeshPart texture until the target true time is reached. If a dissolve is already in progress, it will be canceled and the most recent dissolve request will run instead.

This method does not yield.

<strong>TargetTrueTime</strong>: The target time to be set in seconds. Should be in the range from 0 to the maximum time specified in the settings.
]]
function Dissolver:TrueTimeDissolve(TargetTrueTime: number)
	local self: DissolverObject = self
	assert(CheckTypeof(TargetTrueTime, "number"), "TargetTrueTime must be a number")
	
	self:StopDissolve()
	TargetTrueTime = math.clamp(TargetTrueTime, 0, self.Setting.Time)
	local Sign = math.sign(TargetTrueTime - self.Time)
	local Min = TargetTrueTime
	local Max = self.Setting.Time
	if Sign == 1 then
		Min = 0
		Max = TargetTrueTime
	end
	
	self._DissolveConnection = RunService.Heartbeat:Connect(function(DeltaTime: number)
		local NewTime = math.clamp(self.Time + DeltaTime * Sign, Min, Max)
		if NewTime == TargetTrueTime then
			self:StopDissolve()
		end
		
		self:SetTrueTime(NewTime)
	end)
end

--[[
Dissolves the MeshPart texture until the target time is reached. If a dissolve is already in progress, it will be canceled and the most recent dissolve request will run instead.

This method does not yield.

<strong>TargetTime</strong>: The target time to be set in the range from 0 to 1.
]]
function Dissolver:Dissolve(TargetTime: number)
	local self: DissolverObject = self
	assert(CheckTypeof(TargetTime, "number"), "TargetTime must be a number")
	self:TrueTimeDissolve(TargetTime * self.Setting.Time)
end

--[[
Stops the current dissolve process.
]]
function Dissolver:StopDissolve()
	local self: DissolverObject = self
	if not self._DissolveConnection then
		return
	end

	self._DissolveConnection:Disconnect()
	self._DissolveConnection = nil
	self._FinishedEvent:Fire()
end

--[[
Disconnects all events, stops the current dissolve process, destroys the created EditableImage, and removes any MeshParts from the Dissolver.

This method can be used to destroy the DissolverObject once it is not needed.
]]
function Dissolver:Destroy()
	local self: DissolverObject = self
	
	for MeshPart, Data in pairs(self._MeshParts) do
		self:RemoveMeshPart(MeshPart)
	end
	
	self:StopDissolve()
	self._ColorMap:Destroy()
	
	if self.Setting.EdgeGlowEnabled then
		self._EmissiveMask:Destroy()
	end
	
	self._FinishedEvent:Destroy()
end


for i = 1, NumberOfWorkers do
	local NewWorker = DefaultWorker:Clone()
	NewWorker.Name = i
	NewWorker.Parent = script
	table.insert(Workers, NewWorker)
end
DefaultWorker:Destroy()

return Dissolver