--[[
    lune run src/convert <input> [-x | --explicit <true|false>]

    Converts a Roblox rbxm file to a Rojo-compatible json structure.
    The output can then be used with Rojo to sync the structure to a
    Roblox place.

	Defaults to using an explicit format, which wraps values in tables with type annotations. This can be disabled with the -x or --explicit flag.
--]]
local process = require("@lune/process")
local serde = require("@lune/serde")
local rbx = require("@lune/roblox")
local fs = require("@lune/fs")

local function findFlagValue(args: { string }, names: { string }): ((string | boolean)?, { string })
	for index, arg in args do
		for _, name in names do
			if arg:lower() == name:lower() then
				local poppedArgs = table.clone(args)
				local nextArg = args[index + 1]
				local hasValue = nextArg ~= nil and nextArg:sub(1, 1) ~= "-"

				if hasValue then
					table.remove(poppedArgs, index)
					table.remove(poppedArgs, index)

					return nextArg, poppedArgs
				end

				table.remove(poppedArgs, index)

				return true, poppedArgs
			end
		end
	end

	return nil, args
end

local INPUT_PATH = process.args[1]
local USE_EXPLICIT = findFlagValue(process.args, { "-x", "--explicit" })

if USE_EXPLICIT == nil then
	USE_EXPLICIT = true
elseif USE_EXPLICIT == "false" or USE_EXPLICIT == "0" then
	USE_EXPLICIT = false
end

if not INPUT_PATH then
	error("Usage: lune run src/convert <input> [-x | --explicit <true|false>]")
end

if INPUT_PATH:sub(1, 1) == "." then
	INPUT_PATH = `{process.cwd}/{INPUT_PATH:match("^[./\\]+(.+)$")}`
end

if not fs.isFile(INPUT_PATH) then
	error("Input file does not exist: " .. INPUT_PATH)
end

local OUTPUT_PATH = INPUT_PATH:gsub("%.rbxmx?$", ".model.json")

local rbxmContent = fs.readFile(INPUT_PATH)
local rbxm = rbx.deserializeModel(rbxmContent)

local ReflectionService = rbx.getReflectionDatabase()

local function toPod(value: any, implicit: boolean?): any
	if typeof(value) == "Axes" then
		local axes = {}

		for _, axis in { "X", "Y", "Z" } do
			if value[axis] then
				table.insert(axes, axis)
			end
		end

		return implicit and axes or { Axes = axes }
	elseif typeof(value) == "boolean" then
		return implicit and value or { Bool = value }
	elseif typeof(value) == "BrickColor" then
		return { BrickColor = value.Number }
	elseif typeof(value) == "CFrame" then
		if implicit then
			return { value:GetComponents() }
		end

		return {
			position = toPod(value.Position, true),
			orientation = {
				toPod(value.RightVector, true),
				toPod(value.UpVector, true),
				toPod(value.LookVector, true),
			},
		}
	elseif typeof(value) == "Color3" then
		local color = { value.R, value.G, value.B }
		return implicit and color or { Color3 = color }
	elseif typeof(value) == "ColorSequence" then
		local keypoints = {}

		for _, keypoint in value.Keypoints do
			table.insert(keypoints, {
				Time = keypoint.Time,
				Value = toPod(keypoint.Value, true),
			})
		end

		return { ColorSequence = { keypoints = keypoints } }
	elseif typeof(value) == "Content" then
		return implicit and value.Uri or { Content = value.Uri }
	elseif typeof(value) == "EnumItem" then
		return implicit and value.Name or { Enum = value.Value }
	elseif typeof(value) == "Faces" then
		local normals = { "Top", "Bottom", "Left", "Right", "Front", "Back" }
		local faces = {}

		for _, normal in normals do
			if value[normal] then
				table.insert(faces, normal)
			end
		end

		return { Faces = faces }
	elseif typeof(value) == "Font" then
		local font = {
			family = value.Family,
			weight = value.Weight.Name,
			style = value.Style.Name,
		}

		return implicit and font or { Font = font }
	elseif typeof(value) == "number" then
		return implicit and value or { Float64 = value }
	elseif typeof(value) == "NumberRange" then
		return { NumberRange = { value.Min, value.Max } }
	elseif typeof(value) == "NumberSequence" then
		local keypoints = {}

		for _, keypoint in value.Keypoints do
			table.insert(keypoints, {
				Time = keypoint.Time,
				Value = keypoint.Value,
			})
		end

		return { NumberSequence = { keypoints = keypoints } }
	elseif typeof(value) == "PhysicalProperties" then
		return {
			PhysicalProperties = {
				Density = value.Density,
				Friction = value.Friction,
				Elasticity = value.Elasticity,
				FrictionWeight = value.FrictionWeight,
				ElasticityWeight = value.ElasticityWeight,
			},
		}
	elseif typeof(value) == "Ray" then
		return {
			Ray = {
				origin = toPod(value.Origin, true),
				direction = toPod(value.Direction, true),
			},
		}
	elseif typeof(value) == "Rect" then
		return {
			Rect = {
				toPod(value.Min, true),
				toPod(value.Max, true),
			},
		}
	-- selene: allow(empty_if)
	elseif typeof(value) == "Region3" then
		-- TODO: Not implemented in Rojo
		-- return {
		-- 	Region3 = {
		-- 		toPod(value.CFrame.Position - (value.Size / 2), true),
		-- 		toPod(value.CFrame.Position + (value.Size / 2), true),
		-- 	},
		-- }
		return nil
	elseif typeof(value) == "string" then
		if implicit then
			return value
		end

		return { String = value }
	elseif typeof(value) == "UDim" then
		return { UDim = { value.Scale, value.Offset } }
	elseif typeof(value) == "UDim2" then
		return {
			UDim2 = {
				{ value.X.Scale, value.X.Offset },
				{ value.Y.Scale, value.Y.Offset },
			},
		}
	elseif typeof(value) == "Vector2" then
		local vec = { value.X, value.Y }
		return implicit and vec or { Vector2 = vec }
	elseif typeof(value) == "Vector3" then
		local vec = { value.X, value.Y, value.Z }
		return implicit and vec or { Vector3 = vec }
	end

	return nil
end

local function getPropertyList(className: string)
	local props = ReflectionService:GetClass(className)

	if not props then
		return {}
	end

	local propertyList = {}

	for _, prop in props.Properties do
		if #prop.Tags == 0 then
			table.insert(propertyList, prop.Name)
		end
	end

	if props.Superclass then
		local superProps = getPropertyList(props.Superclass)

		for _, superProp in superProps do
			if not table.find(propertyList, superProp) then
				table.insert(propertyList, superProp)
			end
		end
	end

	table.sort(propertyList)

	return propertyList
end

local function convertInstance(instance: Instance, implicit: boolean): { [string]: any }
	local instanceJson = {
		ClassName = instance.ClassName,
	}

	if instance.Name then
		instanceJson.Name = instance.Name
	end

	local props = ReflectionService:GetClass(instance.ClassName)
	local propertyList = getPropertyList(instance.ClassName)

	if props then
		instanceJson.Properties = {}

		for _, propName in propertyList do
			local cvOk, currentValue = pcall(function()
				return instance[propName]
			end)

			local dvOk, defaultValue = pcall(function()
				return props.DefaultProperties[propName]
			end)

			if not dvOk then
				defaultValue = nil
			end

			if cvOk and currentValue ~= defaultValue then
				instanceJson.Properties[propName] = toPod(currentValue, implicit)
			end
		end
	end

	local attributes = instance:GetAttributes()

	if next(attributes) then
		if not instanceJson.Properties then
			instanceJson.Properties = {}
		end

		if not instanceJson.Properties.Attributes then
			instanceJson.Properties.Attributes = {}
		end

		for attrName, attrValue in pairs(attributes) do
			instanceJson.Properties.Attributes[attrName] = toPod(attrValue, implicit)
		end
	end

	local tags = instance:GetTags()

	if #tags > 0 then
		if not instanceJson.Properties then
			instanceJson.Properties = {}
		end

		if not instanceJson.Properties.Tags then
			instanceJson.Properties.Tags = {}
		end

		for _, tag in tags do
			table.insert(instanceJson.Properties.Tags, tag)
		end
	end

	if #instance:GetChildren() > 0 then
		instanceJson.Children = {}

		for _, child in instance:GetChildren() do
			table.insert(instanceJson.Children, convertInstance(child, implicit))
		end
	end

	return instanceJson
end

local tree = {}

for _, instance in rbxm do
	table.insert(tree, convertInstance(instance, not USE_EXPLICIT))
end

local jsonContent = serde.encode("json", tree, true)
fs.writeFile(OUTPUT_PATH, jsonContent)

print("Conversion complete! Output written to: " .. OUTPUT_PATH)
