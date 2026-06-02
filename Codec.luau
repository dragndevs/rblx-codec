local dataTypes = {
	u8 = "u8",
	u16 = "u16",
	u32 = "u32",
	i8 = "i8",
	i16 = "i16",
	i32 = "i32",
	f32 = "f32",
	f64 = "f64",
	bool = "bool",
	str = "str",
	vec3u8 = "vec3u8",
	vec3u16 = "vec3u16",
	vec3f32 = "vec3f32",
	cframe = "cframe",
	cframef32 = "cframef32",
}

local codec = {}
codec.__index = codec

local function sortedKeys(schema): {string}
	local keys = {}
	
	for k in pairs(schema) do table.insert(keys, k) end
	table.sort(keys)
	
	return keys
end

local function fieldSize(dtype: string, value: any): number
	if dtype == "u8" or dtype == "i8"  or dtype == "bool" then return 1
	elseif dtype == "u16" or dtype == "i16" then return 2
	elseif dtype == "u32" or dtype == "i32" or dtype == "f32" then return 4
	elseif dtype == "f64" then return 8
	elseif dtype == "str" then return 2 + #value
	elseif dtype == "vec3u8" then return 3
	elseif dtype == "vec3u16" then return 6
	elseif dtype == "vec3f32" then return 12
	elseif dtype == "cframe" then return 18
	elseif dtype == "cframef32" then return 24
	end

	return 0
end

function codec.new(schema)
	return setmetatable({schema = schema, keys = sortedKeys(schema)}, codec)
end

function codec:measure(data: {}): number
	local size = 0

	for _, key in ipairs(self.keys) do
		size += fieldSize(self.schema[key], data[key])
	end 

	return size
end

function codec:serialize(data: {}): buffer
	local buf = buffer.create(self:measure(data))
	local offset = 0

	for _, key in ipairs(self.keys) do
		local dtype = self.schema[key]
		local v = data[key]

		if dtype == "u8"  then buffer.writeu8 (buf, offset, v) ; offset += 1
		elseif dtype == "u16" then buffer.writeu16(buf, offset, v) ; offset += 2
		elseif dtype == "u32" then buffer.writeu32(buf, offset, v) ; offset += 4
		elseif dtype == "i8"  then buffer.writei8 (buf, offset, v) ; offset += 1
		elseif dtype == "i16" then buffer.writei16(buf, offset, v) ; offset += 2
		elseif dtype == "i32" then buffer.writei32(buf, offset, v) ; offset += 4
		elseif dtype == "f32" then buffer.writef32(buf, offset, v) ; offset += 4
		elseif dtype == "f64" then buffer.writef64(buf, offset, v) ; offset += 8

		elseif dtype == "bool" then
			buffer.writeu8(buf, offset, v and 1 or 0) ; offset += 1

		elseif dtype == "str" then
			buffer.writeu16(buf, offset, #v)   ; offset += 2
			buffer.writestring(buf, offset, v) ; offset += #v

		elseif dtype == "vec3u8" then
			buffer.writeu8(buf, offset, v.X) ; offset += 1
			buffer.writeu8(buf, offset, v.Y) ; offset += 1
			buffer.writeu8(buf, offset, v.Z) ; offset += 1

		elseif dtype == "vec3u16" then
			buffer.writeu16(buf, offset, v.X) ; offset += 2
			buffer.writeu16(buf, offset, v.Y) ; offset += 2
			buffer.writeu16(buf, offset, v.Z) ; offset += 2

		elseif dtype == "vec3f32" then
			buffer.writef32(buf, offset, v.X) ; offset += 4
			buffer.writef32(buf, offset, v.Y) ; offset += 4
			buffer.writef32(buf, offset, v.Z) ; offset += 4

		elseif dtype == "cframe" then
			local pos = v.Position
			buffer.writeu16(buf, offset, math.round(pos.X)) ; offset += 2
			buffer.writeu16(buf, offset, math.round(pos.Y)) ; offset += 2
			buffer.writeu16(buf, offset, math.round(pos.Z)) ; offset += 2
			local rx, ry, rz = v:ToEulerAnglesXYZ()
			buffer.writef32(buf, offset, rx) ; offset += 4
			buffer.writef32(buf, offset, ry) ; offset += 4
			buffer.writef32(buf, offset, rz) ; offset += 4

		elseif dtype == "cframef32" then
			local pos = v.Position
			buffer.writef32(buf, offset, pos.X) ; offset += 4
			buffer.writef32(buf, offset, pos.Y) ; offset += 4
			buffer.writef32(buf, offset, pos.Z) ; offset += 4
			local rx, ry, rz = v:ToEulerAnglesXYZ()
			buffer.writef32(buf, offset, rx) ; offset += 4
			buffer.writef32(buf, offset, ry) ; offset += 4
			buffer.writef32(buf, offset, rz) ; offset += 4
		end
	end

	return buf
end

function codec:deserialize(buf: buffer): {}
	local result = {}
	local offset = 0

	for _, key in ipairs(self.keys) do
		local dtype = self.schema[key]

		if dtype == "u8"  then result[key] = buffer.readu8 (buf, offset) ; offset += 1
		elseif dtype == "u16" then result[key] = buffer.readu16(buf, offset) ; offset += 2
		elseif dtype == "u32" then result[key] = buffer.readu32(buf, offset) ; offset += 4
		elseif dtype == "i8"  then result[key] = buffer.readi8 (buf, offset) ; offset += 1
		elseif dtype == "i16" then result[key] = buffer.readi16(buf, offset) ; offset += 2
		elseif dtype == "i32" then result[key] = buffer.readi32(buf, offset) ; offset += 4
		elseif dtype == "f32" then result[key] = buffer.readf32(buf, offset) ; offset += 4
		elseif dtype == "f64" then result[key] = buffer.readf64(buf, offset) ; offset += 8

		elseif dtype == "bool" then
			result[key] = buffer.readu8(buf, offset) == 1 ; offset += 1

		elseif dtype == "str" then
			local len = buffer.readu16(buf, offset) ; offset += 2
			result[key] = buffer.readstring(buf, offset, len) ; offset += len

		elseif dtype == "vec3u8" then
			local x = buffer.readu8(buf, offset) ; offset += 1
			local y = buffer.readu8(buf, offset) ; offset += 1
			local z = buffer.readu8(buf, offset) ; offset += 1
			result[key] = Vector3.new(x, y, z)

		elseif dtype == "vec3u16" then
			local x = buffer.readu16(buf, offset) ; offset += 2
			local y = buffer.readu16(buf, offset) ; offset += 2
			local z = buffer.readu16(buf, offset) ; offset += 2
			result[key] = Vector3.new(x, y, z)

		elseif dtype == "vec3f32" then
			local x = buffer.readf32(buf, offset) ; offset += 4
			local y = buffer.readf32(buf, offset) ; offset += 4
			local z = buffer.readf32(buf, offset) ; offset += 4
			result[key] = Vector3.new(x, y, z)

		elseif dtype == "cframe" then
			local x  = buffer.readu16(buf, offset) ; offset += 2
			local y  = buffer.readu16(buf, offset) ; offset += 2
			local z  = buffer.readu16(buf, offset) ; offset += 2
			local rx = buffer.readf32(buf, offset)  ; offset += 4
			local ry = buffer.readf32(buf, offset)  ; offset += 4
			local rz = buffer.readf32(buf, offset)  ; offset += 4
			result[key] = CFrame.new(x, y, z) * CFrame.fromEulerAnglesXYZ(rx, ry, rz)

		elseif dtype == "cframef32" then
			local x  = buffer.readf32(buf, offset) ; offset += 4
			local y  = buffer.readf32(buf, offset) ; offset += 4
			local z  = buffer.readf32(buf, offset) ; offset += 4
			local rx = buffer.readf32(buf, offset) ; offset += 4
			local ry = buffer.readf32(buf, offset) ; offset += 4
			local rz = buffer.readf32(buf, offset) ; offset += 4
			result[key] = CFrame.new(x, y, z) * CFrame.fromEulerAnglesXYZ(rx, ry, rz)
		end
	end

	return result
end

return {
	DataType = dataTypes,
	new = codec.new
}
