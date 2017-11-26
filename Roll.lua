--[[
	Roll

	Properties:
	* player: string -- player name with realm
	* type: string -- "Major", "Minor", etc.
	* values: table -- table of int roll values (1-100)
	* assigned: bool -- was it assigned
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
	obj.assigned = false
	return obj
end

local function SortFunction(a, b)
	if a == nil or b == nil then
		return b == nil
	end

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

			local aValue = a.values[index]
			local bValue = b.values[index]

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

function Class:Sort(rolls)
	table.sort(rolls, SortFunction)
end

function prototype:AddToTooltip()
	local class = select(2, UnitClass(S:GetPlayerNameWithOptionalRealm(self.player)))
	local r, g, b = 1.0, 1.0, 1.0
	if class then
		r = RAID_CLASS_COLORS[class].r
		g = RAID_CLASS_COLORS[class].g
		b = RAID_CLASS_COLORS[class].b
	end

	local prefix = self.assigned and "> " or ""

	GameTooltip:AddDoubleLine(
		prefix..S:GetPlayerNameWithOptionalRealm(self.player),
		S:Join(", ", self.values),
		r, g, b,
		1.0, 1.0, 1.0
	)
end

function prototype:SetType(type)
	self.type = type
	S:Clear(self.values)
	if Addon:IsMasterLooter() or Addon.Settings.Debug.DebugMode then
		self:RollAgain()
	end
end

function prototype:RollAgain()
	if Addon.rollTypes[self.type].shouldRoll then
		table.insert(self.values, random(100))
	end
end

function prototype:SendRoll(loot)
	if Addon.Settings.Debug.DebugMode then
		loot:HandleDoneRollingActions()
	else
		if Addon:IsMasterLooter() then
			Addon.RollValuesMessage:New(loot, self):Send()
		else
			Addon.RollMessage:New(loot, self.type):Send()
		end
	end
end

function prototype:GetCurrentCandidateIndex(slotIndex)
	for i = 1, MAX_RAID_MEMBERS do
		local candidate = GetMasterLootCandidate(slotIndex, i)
		if S:GetPlayerNameWithRealm(candidate) == self.player then
			return i
		end
	end
	return nil
end