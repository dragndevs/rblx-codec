# CodeC

**Why use CodeC?**
CodeC is a lightweight, high-performance serializer and deserializer utilizing Luau's native `buffer` type. It minimizes data payloads sent over RemoteEvents/RemoteFunctions by compacting your structured data down to raw binary byte arrays.

## Table of Contents
- [Usage](#usage)
  - [Client Implementation](#client)
  - [Server Implementation](#server)
- [Supported Types](#supported-types)
- [API Reference](#api-reference)

---

# Usage

To use CodeC, you must define a matching layout schema on both the client and the server. Because the keys are auto-sorted alphabetically internally, it guarantees that the binary data written on one end aligns perfectly with the data read on the other.

## Client

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Codec = require(ReplicatedStorage.Codec)
local DataType = Codec.DataType

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Replication = Remotes:WaitForChild("Replication")

local player = Players.LocalPlayer

-- NOTE: The Client schema structure MUST match the Server schema structure exactly.
local schema = {
    Money = DataType.u32,
    PlayerId = DataType.u32,
    Name = DataType.str,
    Position = DataType.vec3f32,
    Alive = DataType.bool,
    CFrame = DataType.cframef32  
}

local c = Codec.new(schema)

-- Wait for character to be ready
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local dataPayload = {
    Money = 100, 
    PlayerId = player.UserId,
    Name = player.Name,
    Position = hrp.Position,
    Alive = true, 
    CFrame = hrp.CFrame,
}

-- Serialize payload into a dense binary buffer
local buf = c:serialize(dataPayload)

-- Send the raw buffer over the network
Replication:FireServer(buf)
```

## Server

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Codec = require(ReplicatedStorage.Codec)
local DataType = Codec.DataType

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Replication = Remotes:WaitForChild("Replication")

-- Identical schema structure as defined on the client
local schema = {
    Money = DataType.u32,
    PlayerId = DataType.u32,
    Name = DataType.str,
    Position = DataType.vec3f32,
    Alive = DataType.bool,
    CFrame = DataType.cframef32  
}

local c = Codec.new(schema)

Replication.OnServerEvent:Connect(function(client, buf)
    -- Decompress the binary data payload back into a Luau dictionary
    local result = c:deserialize(buf) 
    
    print("Received data from " .. client.Name)
    print("Payload Size: " .. buffer.len(buf) .. " bytes")
    print(result)
end)
```

## Supported Types

```lua
local DataTypes = {
    u8        = "u8",         -- Unsigned 8-bit Integer (1 byte)
    u16       = "u16",        -- Unsigned 16-bit Integer (2 bytes)
    u32       = "u32",        -- Unsigned 32-bit Integer (4 bytes)
    i8        = "i8",         -- Signed 8-bit Integer (1 byte)
    i16       = "i16",        -- Signed 16-bit Integer (2 bytes)
    i32       = "i32",        -- Signed 32-bit Integer (4 bytes)
    f32       = "f32",        -- 32-bit Floating Point (4 bytes)
    f64       = "f64",        -- 64-bit Floating Point (8 bytes)
    bool      = "bool",       -- Boolean (1 byte)
    str       = "str",        -- String (2 bytes length header + length of text)
    vec3u8    = "vec3u8",     -- Vector3 using Unsigned 8-bit integers per axis (3 bytes)
    vec3u16   = "vec3u16",    -- Vector3 using Unsigned 16-bit integers per axis (6 bytes)
    vec3f32   = "vec3f32",    -- Vector3 using standard 32-bit floats per axis (12 bytes)
    cframe    = "cframe",     -- CFrame with rounded u16 positions & f32 angles (18 bytes)
    cframef32 = "cframef32",  -- CFrame with full f32 positions & f32 angles (24 bytes)
}
```

## API

| Method | Parameters | Returns | Description |
| :--- | :--- | :--- | :--- |
| `Codec.new(schema: table)` | `schema`: A dictionary map of keys to data types | `CodecInstance` | Instantiates a new Codec parser instance and alphabetically sorts keys to guarantee reliable network packet mapping alignment. |
| `CodecInstance:serialize(data: table)` | `data`: The dictionary containing values matching the schema | `buffer` | Compresses, packages, and serializes all values into a newly allocated Luau data buffer. |
| `CodecInstance:deserialize(buf: buffer)` | `buf`: A raw Luau data buffer | `table` | Expands and translates binary buffer streams back into standard structured Luau data dictionaries. |
| `CodecInstance:measure(data: table)` | `data`: The dictionary containing values matching the schema | `number` | Dynamically calculates precise byte sizing requirements for the structure ahead of generation to optimize memory allocation speeds. |
