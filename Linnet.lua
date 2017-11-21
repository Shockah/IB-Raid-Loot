Linnet = LibStub("AceAddon-3.0"):NewAddon("Linnet", "AceEvent-3.0", "AceComm-3.0", "AceBucket-3.0", "AceTimer-3.0")
local Self = Linnet

local LibWindow = LibStub("LibWindow-1.1")
local S = LibStub:GetLibrary("ShockahUtils")

local isLootWindowOpen = false
local lootCache = nil

Self.Settings = {
	Debug = {
		Messages = true,
		AlwaysMasterLooter = true,
	},
	LootAssignTimeout = 3, --seconds
	LootReadyBucketPeriod = 0.2, --seconds
}

--TODO: uncomment when done testing
--if not LinnetDB then
	LinnetDB = {
		RollTimeout = 120, --seconds
		QualityThreshold = LE_ITEM_QUALITY_POOR, --minimum quality to consider
	}
--end
local SelfDB = LinnetDB

function Self:OnInitialize()
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfoReceived")
	self:RegisterBucketEvent("LOOT_READY", self.Settings.LootReadyBucketPeriod, "OnLootReady")
	self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")
end

function Self:OnDisable()
	self:UnregisterAllEvents()
end

function Self:OnItemInfoReceived(event, itemID)
	self:HandleItemInfoResponse(itemID)
end

function Self:IsMasterLooter()
	if Self.Settings.Debug.AlwaysMasterLooter then
		return true
	end

	if not IsInRaid()
		return false
	end

	local lootMethod, masterLooterPartyID, masterLooterRaidID = GetLootMethod()
	return lootMethod == "master" and partyMaster == 0
end

function Self:OnLootReady()
	isLootWindowOpen = true
	if not self:IsMasterLooter() then
		return
	end

	lootCache = self:CacheLootIDs()
end

function Self:OnLootClosed()
	isLootWindowOpen = false
end

function Self:CacheLootIDs()
	local cache = {}
	if not isLootWindowOpen then
		return cache
	end

	local numLootItems = GetNumLootItems()
	for i = 1, numLootItems do
		table.insert(cache, self:LootIDForLootFrameSlot(i))
	end

	return cache
end

local function GetCorpseID(corpseGuid)
	local _, _, _, _, _, mobID, spawnID = strsplit("-", corpseGuid)
	return mobID..":"..spawnID
end

function Self:LootIDForLootFrameSlot(lootSlotIndex)
	local link = GetLootSlotLink(lootSlotIndex)
	local corpseGuid = GetLootSourceInfo(lootSlotIndex)
	return GetCorpseID(corpseGuid)..":"..string.gsub(link, "%|h.*$", "")
end