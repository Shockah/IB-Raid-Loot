--[[
	ItemInfo

	Properties:
	* originalRequest: string -- original item name / string / link requested
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.ItemInfo = {}
local Class = Addon.ItemInfo

local classToArmorType = {
	MAGE = "Cloth",
	PRIEST = "Cloth",
	WARLOCK = "Cloth",

	DEMONHUNTER = "Leather",
	DRUID = "Leather",
	MONK = "Leather",
	ROGUE = "Leather",

	HUNTER = "Mail",
	SHAMAN = "Mail",

	DEATHKNIGHT = "Plate",
	PALADIN = "Plate",
	WARRIOR = "Plate",
}

local weaponTypes = {
	"Bow",
	"Crossbow",
	"Dagger",
	"Gun",
	"Fishing Pole",
	"Fist Weapon",
	"Polearm",
	"Staff",
	"Thrown",
	"Wand",
	"Warglaive",
	"Axe",
	"Mace",
	"Sword",
}

function Class:New(originalRequest, tbl)
	local obj = S:Clone(prototype)
	obj.originalRequest = originalRequest
	obj.name = tbl[1]
	obj.link = tbl[2]
	obj.rarity = tbl[3]
	obj.itemLevel = tbl[4]
	obj.minimumLevel = tbl[5]
	obj.type = {
		id = tbl[12],
		name = tbl[6],
	}
	obj.subtype = {
		id = tbl[13],
		name = tbl[7],
	}
	obj.stack = tbl[8]
	obj.equipLocation = {
		internalName = tbl[9],
		name = _G[tbl[9]],
	}
	obj.texture = tbl[10]
	obj.sellPrice = tbl[11]
	obj.bindType = tbl[14]
	obj.expansionId = tbl[15]
	obj.itemSetId = tbl[16]
	obj.isCraftingReagent = tbl[17]
	return obj
end

function Class:Get(item)
	local itemInfoTable = { GetItemInfo(item) }
	if itemInfoTable[1] == nil then
		return nil
	else
		return self:New(item, itemInfoTable)
	end 
end

function prototype:Binds()
	return self.bindType ~= 0
end

function prototype:BindsOnPickup()
	return self.bindType == 1
end

function prototype:BindsOnEquip()
	return self.bindType == 2
end

function prototype:BindsOnUse()
	return self.bindType == 3
end

function prototype:IsQuestItem()
	return self.bindType == 4
end

local function ParseTooltip(self)
	local isUncreatedSetPiece, isWrongClass, isWrongWeaponType = S:ParseTooltip(function(tooltip)
		tooltip:SetHyperlink(self.link)
	end, function(left, right)
		local isUncreatedSetPiece = S:FilterContains(left, function(line)
			return
				S:StringStartsWith(line.text, "Use: Create a class set item appropriate for your loot specialization")
				or
				(S:StringStartsWith(line.text, "Use: Create a soulbound Tier ") and S:StringEndsWith(line.text, " item appropriate for your class."))
		end)
		local isWrongClass = S:FilterContains(left, function(line)
			if S:Round(line.r * 255) == 255 and S:Round(line.g * 255) == 32 and S:Round(line.b * 255) == 32 then
				return S:StringStartsWith(line.text, "Class: ") or S:StringStartsWith(line.text, "Classes: ")
			else
				return false
			end
		end)
		local isWrongWeaponType = S:FilterContains(left, function(line)
			if S:Round(line.r * 255) == 255 and S:Round(line.g * 255) == 32 and S:Round(line.b * 255) == 32 then
				for _, weaponType in pairs(weaponTypes) do
					if weaponType == line.text then
						return true
					end
				end
			else
				return false
			end
		end)
		return isUncreatedSetPiece, isWrongClass, isWrongWeaponType
	end)

	self.isUncreatedSetPiece = isUncreatedSetPiece
	self.isWrongClass = isWrongClass
	self.isWrongWeaponType = isWrongWeaponType
end

function prototype:IsUncreatedSetItem()
	if self.isUncreatedSetItem == nil then
		ParseTooltip(self)
	end
	return self.isUncreatedSetItem
end

function prototype:IsWrongClass()
	if self.isWrongClass == nil then
		ParseTooltip(self)
	end
	return self.isWrongClass
end

function prototype:IsWrongWeaponType()
	if self.isWrongWeaponType == nil then
		ParseTooltip(self)
	end
	return self.isWrongWeaponType
end

function prototype:IsWrongArmorType()
	return self.type.name == "Armor" and self.subtype.name ~= "Miscellaneous" and self.equipLocation.internalName ~= "INVTYPE_CLOAK" and self.subtype.name ~= classToArmorType[select(2, UnitClass("player"))]
end