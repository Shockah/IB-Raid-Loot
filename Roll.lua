--[[
	Roll

	Properties:
	* player: string -- player name with realm
	* type: string -- "2-set"/"4-set"/"Major"/"Minor"/"Off-spec"/"Transmog"/"Warforged"/"Pass"
	* value: int -- roll value (1-100)
]]

local selfAddonName = "Linnet"
local Self = _G[selfAddonName]
local SelfDB = _G[selfAddonName.."DB"]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}

function Self:NewRoll(player, type, value)
	local obj = S:Clone(prototype)
	obj.player = player or S:GetPlayerNameWithRealm(UnitName("player"))
	obj.type = type
	obj.value = value
	return obj
end