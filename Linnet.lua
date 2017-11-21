Linnet = LibStub("AceAddon-3.0"):NewAddon("Linnet", "AceEvent-3.0", "AceComm-3.0", "AceBucket-3.0", "AceTimer-3.0")
local LibWindow = LibStub("LibWindow-1.1")
local S = LibStub:GetLibrary("ShockahUtils")

local 

Linnet.Settings = {
	Debug = {
		Messages = true,
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

function Linnet:OnInitialize()
	self:RegisterBucketEvent("LOOT_READY", self.Settings.LootReadyBucketPeriod, "OnLootReady")
end

function Linnet:OnDisable()
	self:UnregisterAllEvents()
end

function Linnet:OnLootReady()
end