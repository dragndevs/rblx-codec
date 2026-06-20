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
