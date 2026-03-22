local function serialize(value: any, explicit: boolean)
	local vt = typeof(value)

	-- Primitive handling
	if vt == "number" then
		return explicit and { Float64 = value } or value
	elseif vt == "string" then
		return explicit and { String = value } or value
	elseif vt == "boolean" then
		return explicit and { Bool = value } or value
	end

	-- DataTypes
	if vt == "Axes" then
		local axes = {}

		for _, axis in { "X", "Y", "Z" } do
			if value[axis] then
				table.insert(axes, axis)
			end
		end

		return explicit and { Axes = axes } or axes
	elseif vt == "BrickColor" then
		-- Explicit only
		return { BrickColor = value.Number }
	elseif vt == "CFrame" then
		if explicit then
			return {
				position = serialize(value.Position, true),
				orientation = {
					serialize(value.RightVector, true),
					serialize(value.UpVector, true),
					serialize(value.LookVector, true),
				},
			}
		end

		return { value:GetComponents() }
	elseif vt == "Color3" then
		local color = { value.R, value.G, value.B }
		return explicit and { Color3 = color } or color
	elseif vt == "ColorSequence" then
		-- Explicit only
		local keypoints = {}

		for _, keypoint in value.Keypoints do
			table.insert(keypoints, {
				Time = keypoint.Time,
				Value = serialize(keypoint.Value, true),
			})
		end

		return { ColorSequence = { keypoints = keypoints } }
	elseif vt == "Content" then
		return explicit and { Content = value.Uri } or value.Uri
	elseif vt == "EnumItem" then
		return explicit and { Enum = value.Value } or value.Name
	elseif vt == "Faces" then
		local normals = { "Top", "Bottom", "Left", "Right", "Front", "Back" }
		local faces = {}

		for _, normal in normals do
			if value[normal] then
				table.insert(faces, normal)
			end
		end

		return explicit and { Faces = faces } or faces
	elseif vt == "Font" then
		local font = {
			family = value.Family,
			weight = value.Weight.Name,
			style = value.Style.Name,
		}

		return explicit and { Font = font } or font
	elseif vt == "NumberRange" then
		-- Explicit only
		return { NumberRange = { value.Min, value.Max } }
	elseif vt == "NumberSequence" then
		-- Explicit only
		local keypoints = {}

		for _, keypoint in value.Keypoints do
			table.insert(keypoints, {
				Time = keypoint.Time,
				Value = keypoint.Value,
			})
		end

		return { NumberSequence = { keypoints = keypoints } }
	elseif vt == "PhysicalProperties" then
		-- Explicit only
		return {
			PhysicalProperties = {
				Density = value.Density,
				Friction = value.Friction,
				Elasticity = value.Elasticity,
				FrictionWeight = value.FrictionWeight,
				ElasticityWeight = value.ElasticityWeight,
			},
		}
	elseif vt == "Ray" then
		-- Explicit only
		return {
			Ray = {
				Origin = serialize(value.Origin, true),
				Direction = serialize(value.Direction, true),
			},
		}
	elseif vt == "Rect" then
		-- Explicit only
		return {
			Rect = {
				Min = serialize(value.Min, true),
				Max = serialize(value.Max, true),
			},
		}
	elseif vt == "UDim" then
		-- Explicit only
		return {
			UDim = {
				value.Scale,
				value.Offset,
			},
		}
	elseif vt == "UDim2" then
		-- Explicit only

		return {
			UDim2 = {
				{ value.X.Scale, value.X.Offset },
				{ value.Y.Scale, value.Y.Offset },
			},
		}
	elseif vt == "Vector2" then
		local vector = { value.X, value.Y }
		return explicit and { Vector2 = vector } or vector
	elseif vt == "Vector3" then
		local vector = { value.X, value.Y, value.Z }
		return explicit and { Vector3 = vector } or vector
	end

	return nil
end

return {
	serialize = serialize,
}
