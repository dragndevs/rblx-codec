local codec = { }
local compiled = { }
local decompiled = { }
local typeStr    = 2
local typeBool   = 3
local typeWrite  = 4
local typeEnd    = 5
local typeNumU8  = 6
local typeNumU16 = 7
local typeNumI32 = 8
local typeNumF32 = 9

local function classifyNumber(n: number): (number, number)
	if n == math.floor(n) then
		if n >= 0 and n <= 255 then
			return typeNumU8, 1
		elseif n >= 0 and n <= 65535 then
			return typeNumU16, 2
		elseif n >= -2147483648 and n <= 2147483647 then
			return typeNumI32, 4
		end
	end
	return typeNumF32, 4
end

function codec:encode(buf, tbl, offset)
	buffer.writeu8(buf, offset, typeWrite)
	offset += 1
	
	for key, value in pairs(tbl) do
		buffer.writeu8(buf, offset, typeStr)
		offset += 1
		buffer.writeu16(buf, offset, #key)
		offset += 2
		buffer.writestring(buf, offset, key)
		offset += #key
		
		local t = typeof(value)
		if t == "number" then
			local numType, _ = classifyNumber(value)
			buffer.writeu8(buf, offset, numType)
			offset += 1
			if numType == typeNumU8 then
				buffer.writeu8(buf, offset, value)
				offset += 1
			elseif numType == typeNumU16 then
				buffer.writeu16(buf, offset, value)
				offset += 2
			elseif numType == typeNumI32 then
				buffer.writei32(buf, offset, value)
				offset += 4
			elseif numType == typeNumF32 then
				buffer.writef32(buf, offset, value)
				offset += 4
			end
		elseif t == "string" then
			buffer.writeu8(buf, offset, typeStr)
			offset += 1
			buffer.writeu16(buf, offset, #value)
			offset += 2
			buffer.writestring(buf, offset, value)
			offset += #value
		elseif t == "boolean" then
			buffer.writeu8(buf, offset, typeBool)
			offset += 1
			buffer.writeu8(buf, offset, value and 1 or 0)
			offset += 1
		elseif t == "table" then
			offset = self:encode(buf, value, offset)
		end
	end
	
	buffer.writeu8(buf, offset, typeEnd)
	offset += 1
	
	return offset
end

function codec:readTable(buf, offset)
	local result = {}
	
	while true do
		if offset >= buffer.len(buf) then
			return result, offset
		end
		
		local keyType = buffer.readu8(buf, offset)
		offset += 1
		
		if keyType == typeEnd then break end
		local keyLen = buffer.readu16(buf, offset)
		offset += 2
		
		local key = buffer.readstring(buf, offset, keyLen)
		offset += keyLen
		
		local valueType = buffer.readu8(buf, offset)
		offset += 1
		
		if valueType == typeNumU8 then
			result[key] = buffer.readu8(buf, offset)
			offset += 1
			
		elseif valueType == typeNumU16 then
			result[key] = buffer.readu16(buf, offset)
			offset += 2
			
		elseif valueType == typeNumI32 then
			result[key] = buffer.readi32(buf, offset)
			offset += 4
			
		elseif valueType == typeNumF32 then
			result[key] = buffer.readf32(buf, offset)
			offset += 4
			
		elseif valueType == typeStr then
			local len = buffer.readu16(buf, offset)
			offset += 2
	
			result[key] = buffer.readstring(buf, offset, len)
			offset += len
			
		elseif valueType == typeBool then
			result[key] = buffer.readu8(buf, offset) == 1
			offset += 1
			
		elseif valueType == typeWrite then
			local sub
			sub, offset = self:readTable(buf, offset)
			result[key] = sub
			
		end
	end
	return result, offset
end

function codec:measure(tbl: {}): number
	local size = 2
	
	for key, value in pairs(tbl) do
		size += 1 + 2 + #key
		
		local t = typeof(value)
		if t == "number" then
			local _, bytes = classifyNumber(value)
			size += 1 + bytes
		elseif t == "string" then
			size += 1 + 2 + #value
		elseif t == "boolean" then
			size += 2
		elseif t == "table" then
			size += self:measure(value)
		end
	end
	return size
end

function codec:serialize(name: string, data: {})
	local size = self:measure(data)
	local buf = buffer.create(size)
	compiled[name] = buf
	self:encode(buf, data, 0)
	return buf, size
end

function codec:deserialize(input)
	local buf
	
	if typeof(input) == "buffer" then
		buf = input
	else
		buf = compiled[input]
		if not buf then return nil end
	end
	
	local result = self:readTable(buf, 1)
	decompiled[input] = result
	return result
end

function codec:pull(identifier: string | buffer)
	if decompiled[identifier] then
		return decompiled[identifier]
	end
	
	return `{identifier} not decompiled yet!`
end

function codec:destroy(identifier: string | buffer)
	compiled[identifier] = nil
	decompiled[identifier] = nil
end

return codec