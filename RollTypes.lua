local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.rollTypes = {}
Addon.orderedRollTypes = {}

local texturesPath = "Interface\\AddOns\\"..selfAddonName.."\\Textures"
local rollTypes = {
	{
		type = "2-set",
		description = "The item either gives you a 2-set or it's your 1st set piece.",
		icon = texturesPath.."\\Roll-2set",
		shouldRoll = true,
		button = true,
	},
	{
		type = "4-set",
		description = "The item either gives you a 4-set or it's your 3rd set piece.",
		icon = texturesPath.."\\Roll-4set",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Major",
		equippableDescription = "The item gives you a major boost (either +10 item level or a much better effect) for the current spec.",
		description = "The item is of great use for you.",
		icon = texturesPath.."\\Roll-Major",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Minor",
		equippableDescription = "The item is an upgrade for the current spec.",
		description = "The item has some use for you.",
		icon = texturesPath.."\\Roll-Minor",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Off-spec",
		description = "The item is an upgrade for another spec.",
		icon = texturesPath.."\\Roll-Offspec",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Transmog",
		description = "The item has an appearance you didn't unlock yet.",
		icon = texturesPath.."\\Roll-Transmog",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Warforged",
		description = "The base item isn't an upgrade, but you want to try your luck at getting a better warforged/titanforged bonus.",
		icon = texturesPath.."\\Roll-Warforged",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Disenchant",
		icon = texturesPath.."\\Roll-Disenchant",
		shouldRoll = false,
		button = true,
	},
	{
		type = "Pass",
		icon = texturesPath.."\\Roll-Pass",
		shouldRoll = false,
		button = true,
	},
	{
		type = "No Response",
		icon = texturesPath.."\\Roll-NoResponse",
		shouldRoll = false,
		button = false,
	},
	{
		type = "Pending",
		icon = texturesPath.."\\Roll-Pending",
		shouldRoll = false,
		button = false,
	},
}

local function AddLinesToTooltip(self, rolls, onlyLocal)
	if onlyLocal then
		local localRoll = S:FilterFirst(rolls, function(roll)
			return roll.player == S:GetPlayerNameWithRealm()
		end)

		if localRoll then
			localRoll:AddToTooltip()
		end

		GameTooltip:AddLine("Rolls are hidden until rolling is finished.", 1.0, 0.5, 0.0)
	else
		GameTooltip:AddLine("")
		for _, roll in pairs(rolls) do
			roll:AddToTooltip()
		end
	end
end

function prototype:AddToTooltip(loot, rolls, equippable)
	local sortedRolls = S:Clone(rolls)
	Addon.Roll:Sort(sortedRolls)

	GameTooltip:AddLine(self.type, 1.0, 1.0, 1.0)
	if self.description then
		local description = self.description
		if equippable and self.equippableDescription then
			description = self.equippableDescription
		end
		GameTooltip:AddLine(description, 0.8, 0.8, 0.8, true)
	end

	local onlyLocal = loot and loot.hideRollsUntilFinished and self.type ~= "Pending" and loot:HasPendingRolls()
	GameTooltip:AddLine("")
	AddLinesToTooltip(self, sortedRolls, onlyLocal)
end

for index, rollType in pairs(rollTypes) do
	rollType.index = index
	rollType = S:CloneInto(prototype, rollType)
	Addon.rollTypes[rollType.type] = rollType
	Addon.orderedRollTypes[index] = rollType
end