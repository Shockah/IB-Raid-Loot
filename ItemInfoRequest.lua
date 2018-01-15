--[[
	ItemInfoRequest

	Properties:
	* items: table -- table of item IDs/strings/names/links
	* callback: function -- the callback function to call when all items are available
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.ItemInfoRequest = {}
local Class = Addon.ItemInfoRequest

local activeRequests = {}

function Class:New(items, callback)
	local obj = S:Clone(prototype)
	obj.items = items
	obj.callback = callback
	return obj
end

function Class:Get(items, callback)
	local infos = {}
	local hasAllInfos = true
	local needsRequest = false

	for _, item in pairs(items) do
		local itemInfoTable = { GetItemInfo(item) }
		local itemInfo = Addon.ItemInfo:Get(item)
		if itemInfo then
			infos[item] = itemInfo
		else
			hasAllInfos = false
			needsRequest = true
		end
	end

	if hasAllInfos then
		callback(infos)
	elseif needsRequest then
		table.insert(activeRequests, Class:New(items, callback))
	end
end

function Class:HandleItemInfoResponse(itemID)
	for index, activeRequest in pairs(activeRequests) do
		if activeRequest:IsFinished() then
			table.remove(activeRequests, index)
			activeRequest:CallbackOnFinish()
			return
		end
	end
end

function prototype:IsFinished()
	for _, item in pairs(self.items) do
		if not GetItemInfo(item) then
			return false
		end
	end
	return true
end

function prototype:CallbackOnFinish()
	self.callback(self:GetItemInfos())
end

function prototype:GetItemInfos()
	local infos = {}
	for _, item in pairs(self.items) do
		infos[item] = Addon.ItemInfo:Get(item)
	end
	return infos
end