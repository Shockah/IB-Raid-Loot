local selfAddonName = "Linnet"

Linnet = LibStub("AceAddon-3.0"):NewAddon(selfAddonName, "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
local Addon = Linnet
local S = LibStub:GetLibrary("ShockahUtils")

Addon.Settings = {
	Debug = {
		Messages = false,
		DebugMode = false,
		QualityThreshold = LE_ITEM_QUALITY_POOR,
	},
	AceCommPrefix = "Linnet",
	LootAssignTimeout = 2, -- seconds
	MaxRollValue = 100,
}

local isLootWindowOpen = false

Addon.lootCache = {}
Addon.dropdown = nil

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject(selfAddonName, {
	type = "launcher",
	text = selfAddonName,
	icon = "Interface\\AddOns\\"..selfAddonName.."\\Textures\\Roll-Transmog",
	OnClick = function(self, button)
		if button == "LeftButton" then
			local pendingFrame = Addon.PendingFrame:Get()
			pendingFrame:SetLoot(Addon.lootHistory.loot)
			pendingFrame:Update()
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
	self:RegisterEvent("LOOT_READY", "OnLootReady")
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
						Size = { 320, 350 },
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
			notCheckable = true,
		},
		{
			text = timeoutValueToText(self.DB.Settings.Master.RollTimeout),
			tooltipTitle = "",
			tooltipText = "Time after which rolls timeout automatically if not responded to.",
			tooltipOnButton = true,
			notCheckable = true,
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
				Addon:ShowMinimapDropdown(frame)
			end,
		},
		{
			text = "Hide rolls until finished",
			tooltipTitle = "",
			tooltipText = "Rolls (other than pending) are hidden until everyone rolls or until the timeout.",
			tooltipOnButton = true,
			checked = self.DB.Settings.Master.HideRollsUntilFinished,
			func = function()
				self.DB.Settings.Master.HideRollsUntilFinished = not self.DB.Settings.Master.HideRollsUntilFinished
				Addon:ShowMinimapDropdown(frame)
			end,
		},
		{
			text = "Auto-proceed",
			tooltipTitle = "",
			tooltipText = "Automatically assign loot after rolling is finished.",
			tooltipOnButton = true,
			checked = self.DB.Settings.Master.AutoProceed.Enabled,
			func = function()
				self.DB.Settings.Master.AutoProceed.Enabled = not self.DB.Settings.Master.AutoProceed.Enabled
				Addon:ShowMinimapDropdown(frame)
			end,
		},
		{
			text = "   Only if everyone responded",
			tooltipTitle = "",
			tooltipText = "Only automatically assign loot if actually everyone rolled.",
			tooltipOnButton = true,
			checked = self.DB.Settings.Master.AutoProceed.OnlyIfEveryoneResponded,
			func = function()
				self.DB.Settings.Master.AutoProceed.OnlyIfEveryoneResponded = not self.DB.Settings.Master.AutoProceed.OnlyIfEveryoneResponded
				Addon:ShowMinimapDropdown(frame)
			end,
		},
		{
			text = "Announce assignees",
			tooltipTitle = "",
			tooltipText = "Announce assignees in Raid or Raid Warning chat.",
			tooltipOnButton = true,
			checked = self.DB.Settings.Master.AnnounceWinners.Enabled,
			func = function()
				self.DB.Settings.Master.AnnounceWinners.Enabled = not self.DB.Settings.Master.AnnounceWinners.Enabled
				Addon:ShowMinimapDropdown(frame)
			end,
		},
		{
			text = "   In Raid Warning",
			tooltipTitle = "",
			tooltipText = "Use the Raid Warning for announcements.",
			tooltipOnButton = true,
			checked = self.DB.Settings.Master.AnnounceWinners.AsRaidWarning,
			func = function()
				self.DB.Settings.Master.AnnounceWinners.AsRaidWarning = not self.DB.Settings.Master.AnnounceWinners.AsRaidWarning
				Addon:ShowMinimapDropdown(frame)
			end,
		},

		{
			text = "Raider",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Auto-pass unusable",
			tooltipTitle = "",
			tooltipText = "Automatically pass equippable loot you can't use.",
			tooltipOnButton = true,
			checked = self.DB.Settings.Raider.AutoPassUnusable,
			func = function()
				self.DB.Settings.Raider.AutoPassUnusable = not self.DB.Settings.Raider.AutoPassUnusable
				Addon:ShowMinimapDropdown(frame)
			end,
		},

		{
			text = "Other",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Clear loot history",
			tooltipTitle = "",
			tooltipText = "Clear loot history (in case of the addon malfunctioning).",
			tooltipOnButton = true,
			notCheckable = true,
			func = function()
				S:Clear(Addon.lootHistory.loot)
				if Addon.PendingFrame.frame then
					Addon.PendingFrame.frame:SetLoot({})
					Addon.PendingFrame.frame:Update()
				end
			end,
		},
	}, frame)
end

function Addon:ShowDropdown(menus, frame, seconds)
	if not self.dropdown then
		self.dropdown = CreateFrame("Frame", selfAddonName.."Dropdown", UIParent, "UIDropDownMenuTemplate")
	end

	self.dropdown:Hide()
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
	if (not self:IsMasterLooter()) and (not self.Settings.Debug.DebugMode) then
		return
	end

	self.lootCache = self:CacheLootIDs()

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
		pendingFrame:Update()
		pendingFrame:Show()
	end

	for _, loot in pairs(self.lootHistory.loot) do
		loot:HandleDoneRollingActions()
	end
end

function Addon:OnLootClosed()
	isLootWindowOpen = false
	if (not self:IsMasterLooter()) and (not self.Settings.Debug.DebugMode) then
		return
	end

	cachedLootID = {}

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

	local cachedLootID = self.lootCache[slotIndex]
	if not cachedLootID then
		return
	end

	local loot = S:FilterFirst(self.lootHistory.loot, function(lootObj)
		return lootObj.lootID == cachedLootID
	end)

	if loot then
		if S:IsEmpty(loot.assigning) then
			loot.quantity = loot.quantity - 1
		else
			loot:LootAssigned()
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
		cache[i] = self:LootIDForLootFrameSlot(i)
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