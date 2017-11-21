local Self = Linnet

local activeRequests = {}

--[[
	Properties:
	* items: table --table of item IDs/strings/names/links
	* callback: function --the callback function to call when all items are available
]]

local function NewItemInfoRequest(items, callback)
	local obj = {
		items = items,
		callback = callback
	}
	return obj
end

function Self:HandleItemInfoResponse(itemID)
	local index, activeRequest
	for index, activeRequest in pairs(activeRequests) do
		if IsRequestFinished(activeRequest) then
			table.remove(activeRequests, index)
			activeRequest.callback(GetInfosForFinishedRequest(activeRequest))
			return
		end
	end
end

local function GetInfosForFinishedRequest(request)
	local infos = {}

	local item
	for _, item in pairs(request.items) do
		local itemInfo = { GetItemInfo(item) }
		infos[item] = itemInfo
	end

	return infos
end

function Self:GetItemInfo(items, callback)
	local infos = {}
	local hasAllInfos = true
	local needsRequest = false

	local item
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
		table.insert(activeRequests, NewItemInfoRequest(items, callback))
	end
end

local function GetActiveRequestForItem(item)
	local activeRequest
	for _, activeRequest in pairs(activeRequests) do
		local activeRequestItem
		for _, activeRequestItem in pairs(activeRequest.items) do
			if activeRequestItem == item then
				return activeRequest
			end
		end
	end
	return nil
end