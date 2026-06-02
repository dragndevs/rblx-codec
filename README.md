# CodeC

**Why use CodeC?**
- CodeC is a basic lightweight seralizer/deseralizer for sending compressed data over Remotes.

## Table of Contents
- [Usage](#Usage)
- [API](#API)

# Usage
- Example usage: Compressing Client data and sending it over to the Server via Remote Events.

## Client
```lua
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local remotes = replicatedStorage.Remotes
local replication = remotes.Replication

local codec = require(replicatedStorage.Codec)
local dataType = codec.DataType

local player = players.LocalPlayer

--// client schema must match server schema
local schema = {
	Money = dataType.u32,
	PlayerId = dataType.u32,
	Name = dataType.str,
	Position = dataType.vec3f32,
	Alive = dataType.bool,
	CFrame = dataType.cframef32  
}

local c = codec.new(schema)

local buf = c:serialize({
	Money = 100, 
	PlayerId = "1", --// you can use player.UserId
	Name = "Dragn", --// you can use player.Name
	Position = player.Character.HumanoidRootPart.Position,
	Alive = true, 
	CFrame = player.Character.HumanoidRootPart.CFrame, --// can be replaced with euler
})

local send = buf
replication:FireServer(	send ) 
```

## Server
```lua
local replicatedStorage = game:GetService("ReplicatedStorage")
local clients = game:GetService("Players")
local remotes = replicatedStorage.Remotes
local replication = remotes.Replication

local codec = require(replicatedStorage.Codec)
local dataType = codec.DataType

--// same schema from client
local c = codec.new({
	Money = dataType.u32,
	PlayerId = dataType.u32,
	Name = dataType.str,
	Position = dataType.vec3u16,
	Alive = dataType.bool,
	CFrame = dataType.cframef32  
})

replication.OnServerEvent:Connect(function(client, buf)
	local result = c:deserialize(buf) --// deserializes data from buffer 
	print(result, " has" ,buffer.len(buf) .. " bytes")
end)

```

# Types

```lua
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
```

# API

## Methods

| Name | Parameters | Returns | Description |
| ---- | ---------- | ------- | ----------- |
| `.new` | schema: {} | schema keys codec | Sorts keys |
| `:serialize` | data: {} | buf: buffer | Compresses all data |
| `:deserialize` | buf: buffer | result | Decompresses all data |
| `:measure` | data: {} | size: number | Calculates buffer size before creating the buffer to decrease memory usage|
  
