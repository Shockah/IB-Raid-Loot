IBRaidLoot = LibStub("AceAddon-3.0"):NewAddon("IBRaidLoot", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceBucket-3.0", "AceTimer-3.0")
local lwin = LibStub("LibWindow-1.1")
if not IBRaidLootDB then
	IBRaidLootDB = {}
end

IBRaidLootSettings = {}
IBRaidLootSettings["DEBUG"] = true
IBRaidLootSettings["DEBUG_MODE"] = true
IBRaidLootSettings["RollTypes"] = {}
IBRaidLootSettings["RollTypeList"] = {}

IBRaidLootData = {}
IBRaidLootData["currentLootIDs"] = {}
IBRaidLootData["currentLoot"] = {}

local currentLootIDs = IBRaidLootData["currentLootIDs"]
local currentLoot = IBRaidLootData["currentLoot"]
local RollTypes = IBRaidLootSettings["RollTypes"]
local RollTypeList = IBRaidLootSettings["RollTypeList"]

local RollType = nil

RollType = {}
RollType["order"] = 0
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Major-Up]]
RollType["textureDown"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Major-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Major-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Major"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 1
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Minor-Up]]
RollType["textureDown"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Minor-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Minor-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Minor"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 2
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Offspec-Up]]
RollType["textureDown"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Offspec-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Offspec-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Off-spec"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 3
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Transmog-Up]]
RollType["textureDown"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Transmog-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Transmog-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Transmog"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 4
RollType["button"] = true
RollType["textureUp"] = [[Interface\Buttons\UI-GroupLoot-Pass-Up]]
RollType["textureDown"] = [[Interface\Buttons\UI-GroupLoot-Pass-Down]]
RollType["textureHighlight"] = [[Interface\Buttons\UI-GroupLoot-Pass-Highlight]]
RollType["shouldRoll"] = false
RollType["type"] = "Pass"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 100
RollType["button"] = false
RollType["textureUp"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Pending-Up]]
RollType["shouldRoll"] = false
RollType["type"] = "Pending"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

-- comm
local AceCommPrefix = "IBRaidLoot"
local nextCommMessageID = 1
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("IB-Raid-Loot", {
	type = "launcher",
	text = "IB-Raid-Loot",
	icon = [[Interface\Icons\inv_misc_dice_01]],
	OnClick = function(self, button)
		if button == "LeftButton" then
			IBRaidLoot:CreatePendingRollsFrame()
		elseif button == "RightButton" then
			if next(currentLootIDs) ~= nil then
				IBRaidLoot:CreateRollSummaryFrame()
			end
		end
	end,
	OnTooltipShow = function(tt)
		tt:AddLine("IB-Raid-Loot")
		tt:AddLine(" ")
		tt:AddLine("LMB: Pending Rolls")
		tt:AddLine("RMB: Roll Summary")
	end
})

local icon = LibStub("LibDBIcon-1.0")

-------
-- event handlers
-------

function IBRaidLoot:OnInitialize()
	self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
	self:RegisterBucketEvent("LOOT_READY", 0.25, "OnLootOpened")
	self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")

	self:RegisterComm(AceCommPrefix)

	self:RegisterChatCommand("ibrl", "OnSlashCommand")
	self:RegisterChatCommand("ibloot", "OnSlashCommand")

	self.db = LibStub("AceDB-3.0"):New("IBRaidLootDB", {
		profile = {
			minimap = {
				hide = false
			}
		}
	})

	icon:Register("IB-Raid-Loot", LDB, self.db.profile.minimap)
end

function IBRaidLoot:OnDisable()
	self:UnregisterAllEvents()
end

function IBRaidLoot:OnAddonLoaded(event, addon)
	if addon == "Aurora" then
		IBRaidLoot.AuroraF, IBRaidLoot.AuroraC = unpack(Aurora)
		self:UnregisterEvent("ADDON_LOADED")
	end
end

function IBRaidLoot:OnSlashCommand(input)
end

function IBRaidLoot:OnLootOpened()
	if not self:IsMasterLooter() then
		return
	end

	local newLoot = {}

	local numLootItems = GetNumLootItems()
	local threshold = self:GetLootThreshold()
	for i = 1, numLootItems do
		local texture, item, quantity, quality, locked = GetLootSlotInfo(i)
		local lootSlotType = GetLootSlotType(i)

		if not locked and lootSlotType == 1 and quality >= threshold and quantity == 1 then
			local link = GetLootSlotLink(i)
			local corpseGUID = GetLootSourceInfo(i)
			local uniqueLootID = self:GetUniqueLootID(link, corpseGUID)

			if corpseGUID then
				if currentLoot[uniqueLootID] == nil then
					local lootObj = {}
					lootObj["link"] = link
					lootObj["corpseGUID"] = corpseGUID
					lootObj["quality"] = quality
					lootObj["texture"] = texture
					lootObj["name"] = item
					lootObj["uniqueLootID"] = uniqueLootID

					local rolls = {}
					table.foreach(self:GetLootEligiblePlayers(), function(_, player)
						local rollObj = {}
						rollObj["player"] = player
						rollObj["uniqueLootID"] = uniqueLootID
						rollObj["type"] = "Pending"
						rollObj["value"] = 0
						rolls[player] = rollObj
					end)
					lootObj["rolls"] = rolls

					table.insert(currentLootIDs, uniqueLootID)
					currentLoot[uniqueLootID] = lootObj
					table.insert(newLoot, lootObj)
				end
			end
		end
	end

	if next(newLoot) ~= nil then
		self:CreatePendingRollsFrame()
		self:UpdateRollSummaryFrame()
		self:CommMessage("RollsRequest", newLoot, "RAID")
	end
end

function IBRaidLoot:OnLootClosed()
end

function IBRaidLoot:OnCommReceived(prefix, data, distribution, sender)
	local one = libCE:Decode(data)

	local two, message = libC:Decompress(one)
	if not two then
		self:DebugPrint("OnCommReceived: Error decompressing: "..message)
		return
	end

	local success, final = libS:Deserialize(two)
	if not success then
		self:DebugPrint("OnCommReceived: Error deserializing: "..final)
		return
	end

	if sender == GetUnitName("player") then
		return
	end
	self:OnCommMessage(final["Type"], final["Body"], distribution, sender)
end

function IBRaidLoot:OnCommMessage(type, obj, distribution, sender)
	if type == "RollsRequest" then
		for _, lootObj in pairs(obj) do
			local uniqueLootID = lootObj["uniqueLootID"]
			if currentLoot[uniqueLootID] == nil then
				table.insert(currentLootIDs, uniqueLootID)
				currentLoot[uniqueLootID] = lootObj
			end
		end

		self:CreatePendingRollsFrame()
	elseif type == "Roll" then
		obj["player"] = sender
		self:OnRollReceived(obj)
	elseif type == "RollResponse" then
		self:OnRollResponseReceived(obj)
	end
end

function IBRaidLoot:OnRollReceived(rollObj)
	local uniqueLootID = rollObj["uniqueLootID"]
	local lootObj = currentLoot[uniqueLootID]
	if lootObj == nil then
		self:DebugPrint("Received roll for loot "..uniqueLootID..", but there is no info on this item.")
		return
	end

	if self:IsMasterLooter() then
		if RollTypes[rollObj["type"]]["shouldRoll"] then
			rollObj["value"] = random(100)
			self:SendCommMessage("RollResponse", rollObj, "RAID")
		end
	end

	lootObj["rolls"][rollObj["player"]] = rollObj
	self:UpdateLootFrame()
	self:UpdateRollSummaryFrameForLoot(uniqueLootID)
end

function IBRaidLoot:OnRollResponseReceived(rollObj)
	local uniqueLootID = rollObj["uniqueLootID"]
	local lootObj = currentLoot[uniqueLootID]
	if lootObj == nil then
		self:DebugPrint("Received roll response for loot "..uniqueLootID..", but there is no info on this item.")
		return
	end

	lootObj["rolls"][rollObj["player"]] = rollObj
	self:UpdateLootFrame()
	self:UpdateRollSummaryFrameForLoot(uniqueLootID)
end

-------
-- debug-mode-aware functions
-------

function IBRaidLoot:GetLootThreshold()
	if IBRaidLootSettings["DEBUG_MODE"] then
		return 0
	end

	return GetLootThreshold()
end

function IBRaidLoot:IsMasterLooter()
	if IBRaidLootSettings["DEBUG_MODE"] then
		return true
	end

	return self:IsMasterLooter_Real()
end

function IBRaidLoot:GetLootEligiblePlayers(lootObj, player)
	if IBRaidLootSettings["DEBUG_MODE"] then
		return { GetUnitName("player") }
	end

	local players = {}
	for i = 1, 40 do
		local player = GetMasterLootCandidate(i)
		if player ~= nil then
			table.insert(players, player)
		end
	end
	return players
end

-------
-- helper functions
-------

function IBRaidLoot:FindLootSlotForLootObj(lootObj)
	local numLootItems = GetNumLootItems()
	for i = 1, numLootItems do
		local texture, item, quantity, quality, locked = GetLootSlotInfo(i)
		local lootSlotType = GetLootSlotType(i)

		local link = GetLootSlotLink(i)
		local corpseGUID = GetLootSourceInfo(i)
		local uniqueLootID = self:GetUniqueLootID(link, corpseGUID)
		if uniqueLootID == lootObj["uniqueLootId"] then
			return i
		end
	end
	return false
end

function IBRaidLoot:FindLootCandidateIndexForPlayer(player)
	for i = 1, 40 do
		local candidate = GetMasterLootCandidate(i)
		if candidate == player then
			return i
		end
	end
	return false
end

function IBRaidLoot:GiveMasterLootItem(player, lootObj)
	local lootSlotIndex = self:FindLootSlotForLootObj(lootObj)
	if not lootSlotIndex then
		return "Loot window has to be open."
	end

	local candidateIndex = self:FindLootCandidateIndexForPlayer(player)
	if not lootSlotIndex then
		return player.." is not eligible for this item."
	end

	GiveMasterLoot(lootSlotIndex, candidateIndex)
end

function IBRaidLoot:IsMasterLooter_Real()
	if not IsInRaid() then
		return false
	end

	local method, partyMaster, raidMaster = GetLootMethod()
	return method == "master" and partyMaster == 0
end

function IBRaidLoot:DidRollOnItem(lootObj)
	local rollObj = lootObj["rolls"][GetUnitName("player")]
	if rollObj == nil then
		return false
	end

	return rollObj["type"] ~= "Pending"
end

function IBRaidLoot:DidEveryoneRollOnItem(lootObj)
	for player, rollObj in pairs(lootObj["rolls"]) do
		if rollObj["type"] == "Pending" then
			return false
		end
	end

	return true
end

function IBRaidLoot:GetRollsOfType(lootObj, type)
	local rolls = {}
	for player, rollObj in pairs(lootObj["rolls"]) do
		if rollObj["type"] == type then
			table.insert(rolls, rollObj)
		end
	end
	return rolls
end

function IBRaidLoot:GetSortedRolls(lootObj)
	local rolls = {}
	table.foreach(lootObj["rolls"], function(player, rollObj)
		table.insert(rolls, rollObj)
	end)
	table.sort(rolls, RollSortComparison)
	return rolls
end

function IBRaidLoot:RollSortComparison(a, b)
	local aTypeObj = RollTypes[a["type"]]
	local bTypeObj = RollTypes[b["type"]]
	if aTypeObj["order"] ~= bTypeObj["order"] then
		return aTypeObj["order"] < bTypeObj["order"]
	else
		if aTypeObj["shouldRoll"] then
			if a["value"] ~= b["value"] then
				return a["value"] > b["value"]
			else
				return a["player"] < b["player"]
			end
		else
			return a["player"] < b["player"]
		end
	end
end

function IBRaidLoot:GetItemIDFromLink(link)
	return string.gsub(link, ".-\124H([^\124]*)\124h.*", "%1")
end

function IBRaidLoot:GetUniqueLootID(link, corpseGUID)
	return corpseGUID..":"..self:GetItemIDFromLink(link)
end

function IBRaidLoot:CommMessage(type, obj, distribution, target)
	local message = {}
	message["Type"] = type
	message["ID"] = nextCommMessageID
	message["Body"] = obj

	local one = libS:Serialize(message)
	local two = libC:CompressHuffman(one)
	local final = libCE:Encode(two)

	nextCommMessageID = nextCommMessageID + 1
	IBRaidLoot:SendCommMessage(AceCommPrefix, final, distribution, target, "NORMAL")
end

function IBRaidLoot:DebugPrint(message)
	if IBRaidLootSettings["DEBUG"] then
		if type(message) == "table" then
			print("IBRaidLoot:")
			self:tprint(message, 1)
		else
			print("IBRaidLoot: "..tostring(message))
		end
	end
end

function IBRaidLoot:tprint(tbl, indent)
	if not indent then
		indent = 0
	end
	for k, v in pairs(tbl) do
		formatting = string.rep("  ", indent)..k..": "
		if type(v) == "table" then
			print(formatting)
			self:tprint(v, indent + 1)
		elseif type(v) == 'boolean' then
			print(formatting..tostring(v))      
		else
			print(formatting..v)
		end
	end
end

function IBRaidLoot:sizeof(tbl)
	local count = 0
	table.foreach(tbl, function(_, _)
		count = count + 1
	end)
	return count
end

function IBRaidLoot:SetupWindowFrame(frame)
	lwin.RegisterConfig(frame, self.db.profile, {
		prefix = frame:GetName().."_"
	})
	lwin.RestorePosition(frame)
	lwin.MakeDraggable(frame)
end