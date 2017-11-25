local selfAddonName = "Linnet"

Linnet = LibStub("AceAddon-3.0"):NewAddon(selfAddonName, "AceEvent-3.0", "AceComm-3.0", "AceBucket-3.0", "AceTimer-3.0")
local Addon = Linnet
local S = LibStub:GetLibrary("ShockahUtils")

--local LibWindow = LibStub("LibWindow-1.1")

Addon.Settings = {
	Debug = {
		Messages = true,
		DebugMode = true,
		QualityThreshold = LE_ITEM_QUALITY_POOR,
	},
	AceCommPrefix = "Linnet",
	LootAssignTimeout = 2, -- seconds
	LootReadyBucketPeriod = 0.2, -- seconds
}

local isLootWindowOpen = false
local lootCache = nil

Addon.dropdown = nil

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject(selfAddonName, {
	type = "launcher",
	text = selfAddonName,
	icon = "Interface\\AddOns\\"..selfAddonName.."\\Textures\\Roll-Transmog",
	OnClick = function(self, button)
		if button == "LeftButton" then
			local pendingFrame = Addon.PendingFrame:Get()
			pendingFrame:SetLoot(Addon.lootHistory.loot)
			pendingFrame:Show()
		elseif button == "RightButton" then
			Addon:ShowMinimapDropdown(self)
		end
	end,
	OnTooltipShow = function(tt)
		tt:AddLine(selfAddonName)
		tt:AddLine(" ")
		tt:AddLine("LMB: Pending Rolls window")
		tt:AddLine("RMB: Options")
	end
})

function Addon:OnInitialize()
	self.lootHistory = self.LootHistory:New()

	self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfoReceived")
	self:RegisterBucketEvent("LOOT_READY", self.Settings.LootReadyBucketPeriod, "OnLootReady")
	self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")
	self:RegisterEvent("LOOT_SLOT_CLEARED", "OnLootSlotCleared")

	self:RegisterComm(self.Settings.AceCommPrefix)

	if not _G[selfAddonName.."DB"] then
		_G[selfAddonName.."DB"] = {
			Settings = {
				Master = {
					RollTimeout = 120, -- seconds
					HideRollsUntilFinished = true, -- hide rollers until rolling is finished
					AutoProceed = { -- automatically distribute loot when all the rolls are done
						Enabled = false,
						OnlyIfEveryoneResponded = true,
					},
					AnnounceWinners = {
						Enabled = true,
						AsRaidWarning = true,
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

	LibStub("LibDBIcon-1.0"):Register(selfAddonName, LDB, self.DB.minimap)
end

function Addon:ShowMinimapDropdown(frame)
	local timeoutValues = {30, 60, 90, 120, 180, 300}
	local timeoutValueToText = function(value)
		if value >= 120 then
			return "Timeout: "..(value / 60).."m"
		else
			return "Timeout: "..value.."s"
		end
	end

	self:ShowDropdown({
		{
			text = "Master Looter",
			isTitle = true,
		},
		{
			text = timeoutValueToText(self.DB.Settings.Master.RollTimeout),
			tooltipText = "Time after which rolls timeout automatically if not responded to.",
			keepShownOnClick = true,
			func = function(self)
				local timeoutValues = {30, 60, 90, 120, 180, 300}

				local value = Addon.DB.Settings.Master.RollTimeout
				local key = S:KeyOf(timeoutValues, value)
				if not key then
					key = #timeoutValues
					value = timeoutValues[key]
				end

				key = key + 1
				if key > #timeoutValues then
					key = 1
				end
				value = timeoutValues[key]
				Addon.DB.Settings.Master.RollTimeout = value
				Addon:ShowDropdown(frame)
			end,
		},
		{
			text = "Hide rolls until finished",
			tooltipText = "Rolls (other than pending) are hidden until everyone rolls or until the timeout.",
			checked = self.DB.Settings.Master.HideRollsUntilFinished,
			keepShownOnClick = true,
			func = function()
				self.DB.Settings.Master.HideRollsUntilFinished = not self.DB.Settings.Master.HideRollsUntilFinished
			end,
		},
		{
			text = "Auto-proceed",
			tooltipText = "Automatically assign loot after rolling is finished.",
			checked = self.DB.Settings.Master.AutoProceed.Enabled,
			keepShownOnClick = true,
			func = function()
				self.DB.Settings.Master.AutoProceed.Enabled = not self.DB.Settings.Master.AutoProceed.Enabled
			end,
		},
		{
			text = "   Only if everyone responded",
			tooltipText = "Only automatically assign loot if actually everyone rolled.",
			checked = self.DB.Settings.Master.AutoProceed.OnlyIfEveryoneResponded,
			keepShownOnClick = true,
			func = function()
				self.DB.Settings.Master.AutoProceed.OnlyIfEveryoneResponded = not self.DB.Settings.Master.AutoProceed.OnlyIfEveryoneResponded
			end,
		},
		{
			text = "Announce assignees",
			tooltipText = "Announce assignees in Raid or Raid Warning chat.",
			checked = self.DB.Settings.Master.AnnounceWinners.Enabled,
			keepShownOnClick = true,
			func = function()
				self.DB.Settings.Master.AnnounceWinners.Enabled = not self.DB.Settings.Master.AnnounceWinners.Enabled
			end,
		},
		{
			text = "   In Raid Warning",
			tooltipText = "Use the Raid Warning for announcements.",
			checked = self.DB.Settings.Master.AnnounceWinners.AsRaidWarning,
			keepShownOnClick = true,
			func = function()
				self.DB.Settings.Master.AnnounceWinners.AsRaidWarning = not self.DB.Settings.Master.AnnounceWinners.AsRaidWarning
			end,
		},

		{
			text = "Raider",
			isTitle = true,
		},
		{
			text = "Auto-pass unusable",
			tooltipText = "Automatically pass equippable loot you can't use.",
			checked = self.DB.Settings.Raider.AutoPassUnusable,
			keepShownOnClick = true,
			func = function()
				self.DB.Settings.Raider.AutoPassUnusable = not self.DB.Settings.Raider.AutoPassUnusable
			end,
		},
	}, frame)
end

function Addon:ShowDropdown(menus, frame, seconds)
	if not self.dropdown then
		self.dropdown = CreateFrame("Frame", selfAddonName.."Dropdown", UIParent, "UIDropDownMenuTemplate")
	end

	EasyMenu(menus, self.dropdown, frame, 0, 0, "MENU", seconds or 2)
end

function Addon:OnDisable()
	self:UnregisterAllEvents()
end

function Addon:OnItemInfoReceived(event, itemID)
	self.ItemInfoRequest:HandleItemInfoResponse(itemID)
end

function Addon:GetLootThreshold()
	if self.Settings.Debug.DebugMode and self.Settings.Debug.QualityThreshold then
		return self.Settings.Debug.QualityThreshold
	end

	return GetLootThreshold()
end

function Addon:IsMasterLooter()
	if not IsInRaid() then
		return false
	end

	local lootMethod, masterLooterPartyID, masterLooterRaidID = GetLootMethod()
	return lootMethod == "master" and masterLooterPartyID == 0
end

function Addon:IsRaidAssist()
	if not IsInRaid() then
		return false
	end

	local num = GetNumGroupMembers()
	local myself = S:GetPlayerNameWithRealm()
	for i = 1, num do
		local name, rank = GetRaidRosterInfo(i)
		if name then
			if S:GetPlayerNameWithRealm(name) == myself then
				return rank >= 1
			end
		end
	end
	return false
end

function Addon:AnnounceWinner(message)
	if not self.DB.Settings.Master.AnnounceWinners.Enabled then
		return
	end

	if self.Settings.Debug.DebugMode then
		self:DebugPrint(message)
	else
		if self.DB.Settings.Master.AnnounceWinners.AsRaidWarning then
			if self:IsRaidAssist() then
				SendChatMessage(message, "RAID_WARNING")
			else
				SendChatMessage(message, "RAID")
			end
		else
			SendChatMessage(message, "RAID")
		end
	end
end

function Addon:OnLootReady()
	isLootWindowOpen = true
	if not self:IsMasterLooter() and not self.Settings.Debug.DebugMode then
		return
	end

	lootCache = self:CacheLootIDs()

	local lootThreshold = self:GetLootThreshold()
	local numLootItems = GetNumLootItems()
	for i = 1, numLootItems do
		if GetLootSlotType(i) == LOOT_SLOT_ITEM then
			local texture, item, quantity, quality = GetLootSlotInfo(i)

			if quality >= lootThreshold and quantity == 1 then
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
		pendingFrame:SetLoot(newLoot)
		pendingFrame:Show()
	end
end

function Addon:OnLootClosed()
	isLootWindowOpen = false

	local loot = S:Filter(self.lootHistory:GetNonAssignedLoot(), function(lootObj)
		return not S:IsEmpty(lootObj.assigning)
	end)
	for _, lootObj in pairs(loot) do
		lootObj:CancelLootAssigning(true)
	end
end

function Addon:OnLootSlotCleared(event, slotIndex)
	if not isLootWindowOpen then
		return
	end

	local loot = S:FilterFirst(self.lootHistory:GetNonAssignedLoot(), function(lootObj)
		return not S:IsEmpty(lootObj.assigning)
	end)
	if loot then
		loot:LootAssigned()
	else
		local cachedLootID = lootCache[slotIndex]
		local loot = S:FilterFirst(self.lootHistory:GetNonAssignedLoot(), function(lootObj)
			return lootObj.lootID == cachedLootID
		end)

		if loot then
			table.insert(loot.assigned, {})
		end
	end
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