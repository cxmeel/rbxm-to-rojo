local fs = require("@lune/fs")
local process = require("@lune/process")
local rbx = require("@lune/roblox")
local serde = require("@lune/serde")

local argparse = require("./lib/argparse")
local properties = require("./lib/properties")
local serializer = require("./lib/serializer")

local SERDE_FORMAT = {
	["%.json$"] = "json",
	["%.jsonc$"] = "jsonc",
	["%.toml$"] = "toml",
	["%.ya?ml$"] = "yaml",
}

local function processModel(path: string, explicit: boolean)
	local content = fs.readFile(path)
	local model = rbx.deserializeModel(content)

	local tree = {}

	local function processInstance(instance: rbx.Instance)
		local json = {
			ClassName = instance.ClassName,
		}

		if instance.Name then
			json.Name = instance.Name
		end

		local props = properties.getChangedProperties(instance)

		if next(props) ~= nil then
			json.Properties = {}

			for propertyName, property in props do
				json.Properties[propertyName] = serializer.serialize(property.value, explicit)
			end
		end

		local attributes = instance:GetAttributes()

		if next(attributes) then
			if not json.Properties then
				json.Properties = {}
			end

			if not json.Properties.Attributes then
				json.Properties.Attributes = {}
			end

			for attrName, attrValue in pairs(attributes) do
				json.Properties.Attributes[attrName] = serializer.serialize(attrValue, explicit)
			end
		end

		local tags = instance:GetTags()

		if #tags > 0 then
			if not json.Properties then
				json.Properties = {}
			end

			if not json.Properties.Tags then
				json.Properties.Tags = {}
			end

			for _, tag in ipairs(tags) do
				table.insert(json.Properties.Tags, tag)
			end
		end

		if #instance:GetChildren() > 0 then
			json.Children = {}

			for _, child in ipairs(instance:GetChildren()) do
				table.insert(json.Children, processInstance(child))
			end
		end

		return json
	end

	for _, instance in model do
		table.insert(tree, processInstance(instance))
	end

	return tree
end

local function processPlace(path: string, explicit: boolean)
	local content = fs.readFile(path)
	local place = rbx.deserializePlace(content)

	local tree = {
		name = place.Name,
	}

	local pidOk, placeId = pcall(function()
		return place.PlaceId
	end)

	if pidOk and placeId then
		tree.placeId = placeId
	end

	local function processInstance(instance: rbx.Instance)
		local hasItems = false
		local json = {
			["$className"] = instance.ClassName,
		}

		local props = properties.getChangedProperties(instance)

		if next(props) ~= nil then
			hasItems = true
			json["$properties"] = {}

			for propertyName, property in props do
				json["$properties"][propertyName] = serializer.serialize(property.value, explicit)
			end
		end

		local attributes = instance:GetAttributes()

		if next(attributes) then
			hasItems = true

			if not json["$properties"] then
				json["$properties"] = {}
			end

			if not json["$properties"].Attributes then
				json["$properties"].Attributes = {}
			end

			for attrName, attrValue in pairs(attributes) do
				json["$properties"].Attributes[attrName] = serializer.serialize(attrValue, explicit)
			end
		end

		local tags = instance:GetTags()

		if #tags > 0 then
			hasItems = true

			if not json["$properties"] then
				json["$properties"] = {}
			end

			if not json["$properties"].Tags then
				json["$properties"].Tags = {}
			end

			for _, tag in ipairs(tags) do
				table.insert(json["$properties"].Tags, tag)
			end
		end

		if #instance:GetChildren() > 0 then
			for _, child in instance:GetChildren() do
				local childJson = processInstance(child)

				if childJson then
					hasItems = true
					json[child.Name] = childJson
				end
			end
		end

		if not hasItems then
			return
		end

		return json
	end

	tree.tree = processInstance(place)

	return tree
end

local function resolveExtension(extension: string)
	extension = extension:lower()

	for pattern, format in SERDE_FORMAT do
		if extension:match(pattern) then
			return format
		end
	end

	return "json"
end

local function writeFile(path: string, content: string)
	local segments = path:split("/")
	local currentPath = ""

	table.remove(segments)

	for _, segment in segments do
		currentPath ..= `{segment}/`

		if not fs.isDir(currentPath) then
			fs.writeDir(currentPath)
		end
	end

	fs.writeFile(path, content)
end

local function main()
	local parser = argparse("convert", "Convert a Roblox model or place file to Rojo JSON format")

	parser:argument("path", "Path to the model or place file to convert")
	parser:option("-o --output", "Path to save the output JSON file")
	parser:flag("-p --print", "Print the output to the console instead of saving to a file", false)
	parser:flag("-x --explicit", "Write DataTypes in explicit format", false)
	parser:flag("-m --minified", "Minify the output JSON", false)

	local args = parser:parse(process.args) :: {
		path: string,
		output: string?,
		print: boolean,
		explicit: boolean,
		minified: boolean,
	}

	if not fs.isFile(args.path) then
		print("Error: The specified path is not a file.")
		return
	end

	local isPlaceFile = args.path:lower():match("%.rbxlx?$") ~= nil
	local tree

	if isPlaceFile then
		tree = processPlace(args.path, args.explicit)
	else
		tree = processModel(args.path, args.explicit)
	end

	local serdeFormat = "json"

	for pattern, format in SERDE_FORMAT do
		if args.output and args.output:lower():match(pattern) then
			serdeFormat = format
			break
		end
	end

	local output = serde.encode(serdeFormat, tree, not args.minified)

	local outputExt = resolveExtension(serdeFormat)
	local outputPath = args.output or args.path:gsub("%.[^.]+$", `.{outputExt}`)

	if args.print then
		print(output)
		return
	end

	writeFile(outputPath, output)
end

main()
