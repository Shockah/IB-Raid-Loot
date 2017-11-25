--[[
	Roll

	Properties:
	* player: string -- player name with realm
	* type: string -- "Major", "Minor", etc.
	* values: table -- table of int roll values (1-100)
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.Roll = {}
local Class = Addon.Roll

function Class:New(player, type, values)
	local obj = S:Clone(prototype)
	obj.player = player or S:GetPlayerNameWithRealm(UnitName("player"))
	obj.type = type
	obj.values = values == nil and {} or (type(values) == "number" and {values} or values)
	return obj
end

function Class:SortFunction(a, b)
	local aType = Addon.rollTypes[a.type]
	local bType = Addon.rollTypes[b.type]

	if aType ~= bType then
		return aType.index < bType.index
	end

	if aType.shouldRoll then
		local index = 0
		local continue = true
		while continue do
			index = index + 1

			local aValue = a.values[i]
			local bValue = b.values[i]

			if aValue == nil or bValue == nil then
				if aValue == nil and bValue == nil then
					continue = false
				else
					return bValue == nil
				end
			else
				return aValue > bValue
			end
		end
	end

	return a.player < b.player
end

function prototype:AddToTooltip()
	GameTooltip:AddDoubleLine(
		S:GetPlayerNameWithOptionalRealm(self.player),
		S:Join(", ", self.values),
		1.0, 1.0, 1.0,
		1.0, 1.0, 1.0
	)
end

function prototype:SetType(type)
	self.type = type
	S:Clear(self.values)
	if Addon.rollTypes[self.type].shouldRoll then
		table.insert(self.values, random(100))
	end
end