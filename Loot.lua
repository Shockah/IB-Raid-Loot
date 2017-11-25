--[[
	Loot

	Properties:
	* lootID: string -- unique loot ID
	* link: string -- item link
	* quantity: int
	* isNew: bool -- whether this Loot object is still being processed for the first time
	* rolls: table -- list of rolls
	* startTime: int -- time the rolling started at
	* timeout: int -- startTime + timeout to end at
	* hideRollsUntilFinished: bool -- initially coming from DB.Settings; hide rollers until rolling is finished
	* cacheIsEquippable: bool -- cached: is item equippable
	* timeoutTimer: AceTimer ID -- timeout timer
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.Loot = {}
local Class = Addon.Loot

local classToArmorType = {
	MAGE = "Cloth",
	PRIEST = "Cloth",
	WARLOCK = "Cloth",

	DEMONHUNTER = "Leather",
	DRUID = "Leather",
	MONK = "Leather",
	ROGUE = "Leather",

	HUNTER = "Mail",
	SHAMAN = "Mail",

	DEATHKNIGHT = "Plate",
	PALADIN = "Plate",
	WARRIOR = "Plate",
}
local weaponTypes = {
	"Bow",
	"Crossbow",
	"Dagger",
	"Gun",
	"Fishing Pole",
	"Fist Weapon",
	"One-Handed Axe",
	"One-Handed Mace",
	"One-Handed Sword",
	"Polearm",
	"Staff",
	"Thrown",
	"Two-Handed Axe",
	"Two-Handed Mace",
	"Two-Handed Sword",
	"Wand",
	"Warglaive",
}

function Class:New(lootID, link, quantity, isNew)
	local obj = S:Clone(prototype)
	obj.lootID = lootID
	obj.link = link
	obj.quantity = quantity or 1
	obj.isNew = (isNew == nil and true or isNew)
	obj.rolls = {}
	obj.cacheIsEquippable = false
	obj.hideRollsUntilFinished = Addon.DB.Settings.Master.HideRollsUntilFinished
	return obj
end

function Class:GetEligiblePlayers(slotIndex)
	local result = {}

	if Addon.Settings.Debug.DebugMode then
		if IsInRaid() then
			local num = GetNumGroupMembers()
			for i = 1, num do
				local name = GetRaidRosterInfo(i)
				if name then
					table.insert(result, S:GetPlayerNameWithRealm(name))
				end
			end
		elseif IsInGroup() then
			table.insert(result, S:GetPlayerNameWithRealm())
			local num = GetNumGroupMembers()
			for i = 1, num do
				local name = UnitName("party"..i)
				if name then
					table.insert(result, S:GetPlayerNameWithRealm(name))
				end
			end
		else
			table.insert(result, S:GetPlayerNameWithRealm())
		end
		return result
	end

	for i = 1, MAX_RAID_MEMBERS do
		local name = GetMasterLootCandidate(slotIndex, i)
		if name then
			table.insert(result, S:GetPlayerNameWithRealm(name))
		end
	end

	return result
end

function prototype:SetTimeout(timeout)
	if timeout then
		self.startTime = GetTime()
		self.timeout = timeout
		if self.timeoutTimer then
			Addon:CancelTimer(self.timeoutTimer)
		end
		self.timeoutTimer = Addon:ScheduleTimer(function()
			local pendingRolls = S:Filter(self.rolls, function(roll)
				return roll.type == "Pending"
			end)
			for _, pendingRoll in pairs(pendingRolls) do
				self.timeoutTimer = nil
				pendingRoll.type = "No Response"
				if Addon:IsMasterLooter() then
					pendingRoll:SendRoll(self)
				end
			end
			self:HandleDoneRollingActions()
		end, timeout)
	else
		self.startTime = nil
		self.timeout = nil
		if self.timeoutTimer then
			Addon:CancelTimer(self.timeoutTimer)
			self.timeoutTimer = nil
		end
	end
end

function prototype:SetInitialRolls(eligiblePlayers)
	S:Clear(self.rolls)
	for _, eligiblePlayer in pairs(eligiblePlayers) do
		table.insert(self.rolls, Addon.Roll:New(eligiblePlayer, "Pending"))
	end
end

function prototype:AddToHistory(lootHistory, timeout)
	self:SetTimeout(timeout or Addon.DB.Settings.Master.RollTimeout)
	table.insert(lootHistory.loot, self)
end

function prototype:GetRollForPlayer(player)
	local player = S:GetPlayerNameWithRealm(player)
	return S:FilterFirst(self.rolls, function(roll)
		return roll.player == player
	end)
end

function prototype:IsPendingLocalRoll()
	local localRoll = self:GetRollForPlayer()
	return localRoll and localRoll.type == "Pending"
end

function prototype:HasPendingRolls()
	return S:FilterContains(self.rolls, function(roll)
		return roll.type == "Pending"
	end)
end

function prototype:GetAvailableRollTypes()
	local ENCHANTING_ID = 333
	local rollTypes = S:Map(S:Filter(Addon.orderedRollTypes, function(rollType)
		return rollType.button
	end), function(rollType)
		return rollType.type
	end)
	S:RemoveValue(rollTypes, "Disenchant")
	S:RemoveValue(rollTypes, "Pass")

	local itemInfo = { GetItemInfo(self.link) }
	--itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
	--itemEquipLoc, iconFileDataID, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
	--isCraftingReagent = GetItemInfo(itemID or "itemString" or "itemName" or "itemLink")

	local isUncreatedSetPiece, isWrongClass, isWrongWeaponType = S:ParseTooltip(function(tooltip)
		tooltip:SetHyperlink(self.link)
	end, function(left, right)
		local isUncreatedSetPiece = S:FilterContains(left, function(line)
			return S:StringStartsWith(line.text, "Use: Create a class set item appropriate for your loot specialization")
		end)
		local isWrongClass = S:FilterContains(left, function(line)
			if S:Round(line.r * 255) == 255 and S:Round(line.g * 255) == 32 and S:Round(line.b * 255) == 32 then
				return S:StringStartsWith(line.text, "Class: ") or S:StringStartsWith(line.text, "Classes: ")
			else
				return false
			end
		end)
		local isWrongWeaponType = S:FilterContains(left, function(line)
			if S:Round(line.r * 255) == 255 and S:Round(line.g * 255) == 32 and S:Round(line.b * 255) == 32 then
				for _, weaponType in pairs(weaponTypes) do
					if weaponType == line.text then
						return true
					end
				end
			else
				return false
			end
		end)
		return isUncreatedSetPiece, isWrongClass, isWrongWeaponType
	end)

	local weaponType = itemInfo[6] == "Weapon" and itemInfo[7] or nil
	local armorType = itemInfo[6] == "Armor" and itemInfo[7] or nil
	local equipLocation = itemInfo[9]
	local bindType = itemInfo[14]

	local isWeapon = not S:IsBlankString(weaponType)
	local isArmor = not S:IsBlankString(armorType)
	local isMiscArmor = isArmor and armorType == "Miscellaneous"
	
	local isEquippable = isWeapon or isArmor
	local isWrongArmorType = isArmor and armorType and (not isMiscArmor) and equipLocation ~= "INVTYPE_CLOAK" and armorType ~= classToArmorType[select(2, UnitClass("player"))]

	self.cacheIsEquippable = isEquippable or isUncreatedSetPiece

	if isEquippable or isUncreatedSetPiece then
		if (not isUncreatedSetPiece) or isWeapon then
			S:RemoveValue(rollTypes, "2-set")
			S:RemoveValue(rollTypes, "4-set")
			S:RemoveValue(rollTypes, "Warforged")
		end

		if isWrongClass or isWrongArmorType or isWrongWeaponType then
			S:RemoveValue(rollTypes, "2-set")
			S:RemoveValue(rollTypes, "4-set")
			S:RemoveValue(rollTypes, "Major")
			S:RemoveValue(rollTypes, "Minor")
			S:RemoveValue(rollTypes, "Warforged")

			if bindType ~= 0 and bindType ~= 2 then -- 0 = no bind; 2 = BoE
				S:RemoveValue(rollTypes, "Transmog")
			end
		end

		if isMiscArmor then
			S:RemoveValue(rollTypes, "Transmog")
		end 

		local isEnchanter = false
		local prof1, prof2 = GetProfessions()
		local profs = { prof1, prof2 }
		for _, prof in pairs(profs) do
			if select(7, GetProfessionInfo(prof)) == ENCHANTING_ID then
				isEnchanter = true
			end
		end

		if isEnchanter and not isWrongClass then
			table.insert(rollTypes, "Disenchant")
		else
			table.insert(rollTypes, "Pass")
		end
	else
		S:RemoveValue(rollTypes, "2-set")
		S:RemoveValue(rollTypes, "4-set")
		S:RemoveValue(rollTypes, "Warforged")
		S:RemoveValue(rollTypes, "Transmog")
		S:RemoveValue(rollTypes, "Off-spec")
		table.insert(rollTypes, "Pass")
	end
	
	return rollTypes
end

function prototype:HandleDoneRollingActions()
	if self:HasPendingRolls() then
		return false
	end

	if self.timeoutTimer then
		Addon:CancelTimer(self.timeoutTimer)
	end

	if Addon.PendingFrame.frame then
		Addon.PendingFrame.frame:Update()
	end

	return true
end