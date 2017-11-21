--[[
	LootMessage

	Properties:
	* loot: table -- list of Loot objects
]]

local selfAddonName = "Linnet"
local Self = _G[selfAddonName]
local SelfDB = _G[selfAddonName.."DB"]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}

function Self:NewLootMessage(loot)
	local obj = S:Clone(prototype)
	obj.loot = {}
	return obj
end

function Self:HandleRawLootMessage(message)
	HandleLootMessage(message.loot, message.timeout)
end

local function HandleLootMessage(loot, timeout)
end

function prototype:Send()
	Self:SendCompressedCommMessage("Loot", {
		loot = self.loot,
		timeout = SelfDB.RollTimeout
	}, "RAID")
end