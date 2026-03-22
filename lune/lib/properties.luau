local rbx = require("@lune/roblox")

local ReflectionService = rbx.getReflectionDatabase()
local classCache = {}

export type PropertyListItem = {
	className: string,
	property: { [string]: rbx.DatabaseProperty },
}

export type ChangedPropertyItem = PropertyListItem & {
	value: any,
}

local function getPropertyList(className: string): { [string]: PropertyListItem }
	if classCache[className] then
		return classCache[className]
	end

	local properties = {}
	local classInfo = ReflectionService:GetClass(className)

	while true do
		for propertyName, property in classInfo.Properties do
			-- Filter out properties with tags
			if #property.Tags > 0 then
				continue
			end

			if propertyName == "Name" then
				continue
			end

			properties[propertyName] = {
				className = className,
				property = { [propertyName] = property },
			}
		end

		if not classInfo.Superclass then
			break
		end

		classInfo = ReflectionService:GetClass(classInfo.Superclass)
	end

	classCache[className] = properties

	return properties
end

local function getChangedProperties(object: rbx.Instance): { [string]: ChangedPropertyItem }
	local propertyList = getPropertyList(object.ClassName)
	local changedProperties = {}

	local classInfo = ReflectionService:GetClass(object.ClassName)

	for propertyName, propertyInfo in propertyList do
		if classInfo.Name ~= propertyInfo.className then
			classInfo = ReflectionService:GetClass(propertyInfo.className)
		end

		local dvOk, defaultValue = pcall(function()
			return classInfo.DefaultProperties[propertyName]
		end)

		local cvOk, currentValue = pcall(function()
			return object[propertyName]
		end)

		if not dvOk or not cvOk then
			continue
		end

		if defaultValue ~= currentValue then
			local newInfo = table.clone(propertyInfo)
			newInfo.value = currentValue

			changedProperties[propertyName] = newInfo
		end
	end

	return changedProperties
end

return {
	getPropertyList = getPropertyList,
	getChangedProperties = getChangedProperties,
}
