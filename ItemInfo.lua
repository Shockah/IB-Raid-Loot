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