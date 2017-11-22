local selfAddonName = "Linnet"

Linnet = LibStub("AceAddon-3.0"):NewAddon(selfAddonName, "AceEvent-3.0", "AceComm-3.0", "AceBucket-3.0", "AceTimer-3.0")
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

--local LibWindow = LibStub("LibWindow-1.1")

Addon.Settings = {
	Debug = {
		Settings = true,
		Messages = true,
		AlwaysMasterLooter = true,
	},
	AceCommPrefix = "Linnet",
	LootAssignTimeout = 2, -- seconds
	LootReadyBucketPeriod = 0.2, -- seconds
}

if not _G[selfAddonName.."DB"] then
	_G[selfAddonName.."DB"] = {
		Settings = {
			Master = {
				RollTimeout = 120, -- seconds
				QualityThreshold = LE_ITEM_QUALITY_EPIC, -- minimum quality to consider
				AutoProceed = { -- automatically distribute loot when all the rolls are done
					Enabled = false,
					OnlyIfEveryoneResponded = true,
				},
			},
			Raider = {
				AutoPassUnusable = true, -- automatically pass on unusable loot (plate on a cloth character etc.)
			},
		},
	}
end
local DB = _G[selfAddonName.."DB"]

if Addon.Settings.Debug.Settings then
	DB.Settings.Master.RollTimeout = 30
	DB.Settings.Master.QualityThreshold = LE_ITEM_QUALITY_POOR
end

local isLootWindowOpen = false
local lootCache = nil

function Addon:OnInitialize()
	self.lootHistory = self.LootHistory:New()

	self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfoReceived")
	self:RegisterBucketEvent("LOOT_READY", self.Settings.LootReadyBucketPeriod, "OnLootReady")
	self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")

	self:RegisterComm(self.Settings.AceCommPrefix)
end

function Addon:OnDisable()
	self:UnregisterAllEvents()
end

function Addon:OnItemInfoReceived(event, itemID)
	self.ItemInfoRequest:HandleItemInfoResponse(itemID)
end

function Addon:IsMasterLooter()
	if self.Settings.Debug.AlwaysMasterLooter then
		return true
	end

	if not IsInRaid() then
		return false
	end

	local lootMethod, masterLooterPartyID, masterLooterRaidID = GetLootMethod()
	return lootMethod == "master" and partyMaster == 0
end

function Addon:OnLootReady()
	isLootWindowOpen = true
	if not self:IsMasterLooter() then
		return
	end

	lootCache = self:CacheLootIDs()

	local numLootItems = GetNumLootItems()
	for i = 1, numLootItems do
		if GetLootSlotType(i) == LOOT_SLOT_ITEM then
			local texture, item, quantity, quality = GetLootSlotInfo(i)

			if quality >= DB.Settings.Master.QualityThreshold and quantity == 1 then
				local lootID = self:LootIDForLootFrameSlot(i)
				if lootID then
					-- looted item is valid for rolling

					local loot = self.lootHistory:Get(lootID)
					if not loot then
						loot = self.Loot:New(lootID, GetLootSlotLink(i), 0)
						loot:AddToHistory(self.lootHistory)
					end

					if loot.isNew then
						loot.quantity = loot.quantity + 1
						self:DebugPrint("New loot item: "..loot.link.." x"..loot.quantity)
					end
				end
			end
		end
	end

	local newLoot = self.lootHistory:GetAllNew()
	if not S:IsEmpty(newLoot) then
		self.LootMessage:New(newLoot):Send()
		for _, loot in pairs(newLoot) do
			loot.isNew = false
		end
	end
end

function Addon:OnLootClosed()
	isLootWindowOpen = false
end

function Addon:CacheLootIDs()
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

function Addon:LootIDForLootFrameSlot(lootSlotIndex)
	local corpseGuid = GetLootSourceInfo(lootSlotIndex)
	if not corpseGuid then
		return nil
	end
	local link = GetLootSlotLink(lootSlotIndex)
	return GetCorpseID(corpseGuid)..":"..string.gsub(link, "%|h.*$", "")
end

function Addon:DebugPrint(message)
	if self.Settings.Debug.Messages then
		S:Dump(selfAddonName, message)
	end
end