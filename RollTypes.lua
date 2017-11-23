local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

Addon.rollTypes = {}
Addon.orderedRollTypes = {}

local texturesPath = "Interface\\AddOns\\"..selfAddonName.."\\Textures"
local rollTypes = {
	{
		type = "2-set",
		icon = texturesPath.."\\Roll-2set",
		shouldRoll = true,
		button = true,
	},
	{
		type = "4-set",
		icon = texturesPath.."\\Roll-4set",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Major",
		icon = texturesPath.."\\Roll-Major",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Minor",
		icon = texturesPath.."\\Roll-Minor",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Offspec",
		icon = texturesPath.."\\Roll-Offspec",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Transmog",
		icon = texturesPath.."\\Roll-Transmog",
		shouldRoll = true,
		button = true,
	},
	{
		type = "Warforged",
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
		type = "Pending",
		icon = texturesPath.."\\Roll-Pending",
		shouldRoll = false,
		button = false,
	},
}

for index, rollType in pairs(rollTypes) do
	rollType.index = index
	Addon.rollTypes[rollType.type] = rollType
	Addon.orderedRollTypes[index] = rollType
end