local selfAddonName = "Linnet"

Linnet = LibStub("AceAddon-3.0"):NewAddon(selfAddonName, "AceEvent-3.0", "AceComm-3.0", "AceBucket-3.0", "AceTimer-3.0")
local Addon = Linnet
local S = LibStub:GetLibrary("ShockahUtils")

--local LibWindow = LibStub("LibWindow-1.1")

Addon.Settings = {
	Debug = {
		Settings = true,
		Messages = true,
		AlwaysMasterLooter = false,
	},
	AceCommPrefix = "Linnet",
	LootAssignTimeout = 2, -- seconds
	LootReadyBucketPeriod = 0.2, -- seconds
}

local isLootWindowOpen = false
local lootCache = nil

function Addon:OnInitialize()
	self.lootHistory = self.LootHistory:New()

	self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfoReceived")
	self:RegisterBucketEvent("LOOT_READY", self.Settings.LootReadyBucketPeriod, "OnLootReady")
	self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")

	self:RegisterComm(self.Settings.AceCommPrefix)

	if not _G[selfAddonName.."DB"] then
		_G[selfAddonName.."DB"] = {
			Settings = {
				Master = {
					RollTimeout = 120, -- seconds
					QualityThreshold = LE_ITEM_QUALITY_EPIC, -- minimum quality to consider
					HideRollsUntilFinished = true, -- hide rollers until rolling is finished
					AutoProceed = { -- automatically distribute loot when all the rolls are done
						Enabled = false,
						OnlyIfEveryoneResponded = true,
					},
				},
				Raider = {
					AutoPassUnusable = true, -- automatically pass on unusable loot (plate on a cloth character etc.)
					PendingFrame = {
						Strata = "HIGH",
						Point = {
							point = "LEFT",
							relativeTo = "UIParent",
							relativePoint = "LEFT",
							xOffset = 16,
							yOffset = 0,
						},
						Size = { 250, 350 },
						Cell = {
							Height = 60,
							Spacing = -6,
						},
					},
				},
			},
		}
	end
	self.DB = _G[selfAddonName.."DB"]

	if self.Settings.Debug.Settings then
		self.DB.Settings.Master.RollTimeout = 30
		self.DB.Settings.Master.QualityThreshold = LE_ITEM_QUALITY_POOR
	end
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
	return lootMethod == "master" and masterLooterPartyID == 0
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

			if quality >= self.DB.Settings.Master.QualityThreshold and quantity == 1 then
				local lootID = self:LootIDForLootFrameSlot(i)
				if lootID then
					-- looted item is valid for rolling

					local loot = self.lootHistory:Get(lootID)
					if not loot then
						loot = self.Loot:New(lootID, GetLootSlotLink(i), 0)
						loot:SetInitialRolls(self.Loot:GetEligiblePlayers(i))
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

		local pendingFrame = self.PendingFrame:Get()
		pendingFrame:SetLoot(self.lootHistory.loot)
		pendingFrame:Show()
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
	if not link then
		return nil
	end
	return GetCorpseID(corpseGuid)..":"..S:ParseItemLink(link).itemString
end

function Addon:DebugPrint(message)
	if self.Settings.Debug.Messages then
		S:Dump(selfAddonName, message)
	end
end