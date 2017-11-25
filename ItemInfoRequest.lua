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

local function GetActiveRequestForItem(item)
	for _, activeRequest in pairs(activeRequests) do
		for _, activeRequestItem in pairs(activeRequest.items) do
			if activeRequestItem == item then
				return activeRequest
			end
		end
	end
	return nil
end

function Class:Get(items, callback)
	local infos = {}
	local hasAllInfos = true
	local needsRequest = false

	for _, item in pairs(items) do
		local itemInfo = { GetItemInfo(item) }
		if itemInfo[1] == nil then
			hasAllInfos = false
			if not GetActiveRequestForItem(item) then
				needsRequest = true
			end
		else
			infos[item] = itemInfo
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
		local itemInfo = { GetItemInfo(item) }
		infos[item] = itemInfo
	end
	return infos
end