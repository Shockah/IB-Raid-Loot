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
	* assigning: table -- list of structs:
		* timer: AceTimer ID -- loot assigning timeout timer
		* roll: table -- Roll object the loot is currently being assigned to
	* assigned: int -- the already assigned/gone amount of loot
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
	obj.assigning = {}
	obj.assigned = 0
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
	S:FilterRemove(lootHistory.loot, function(loot)
		return loot.lootID == self
	end)
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

	if (not S:IsEmpty(self.rolls)) and (Addon:IsMasterLooter() or Addon.Settings.Debug.DebugMode) then
		if Addon.DB.Settings.Master.AutoProceed.Enabled then
			local everyonePassed = not S:FilterContains(self.rolls, function(roll)
				return roll.type ~= "Pass"
			end)
			local everyoneResponded = not S:FilterContains(self.rolls, function(roll)
				return roll.type == "No Response"
			end)

			if (not everyonePassed) and everyoneResponded or (not Addon.DB.Settings.Master.AutoProceed.OnlyIfEveryoneResponded) then
				local sortedRolls = S:Clone(self.rolls)
				Addon.Roll:Sort(sortedRolls)

				if #sortedRolls > 1 and sortedRolls[1].type == sortedRolls[2].type and sortedRolls[1].values[#sortedRolls[1].values] == sortedRolls[2].values[#sortedRolls[2].values] then
					sortedRolls[1].values:RollAgain()
					sortedRolls[2].values:RollAgain()
					sortedRolls[1]:SendRoll(self)
					sortedRolls[2]:SendRoll(self)
					self:HandleDoneRollingActions()
				else
					self:AssignLoot(sortedRolls[1])
				end
			end
		end
	end

	return true
end

function prototype:AnnounceWinner(roll)
	local rollType = Addon.rollTypes[roll.type]
	local rollValues = S:Join(", ", roll.values)

	local message
	if rollType.shouldRoll then
		message = roll.player.." wins "..self.link.." with "..rollType.announceName.." roll of "..rollValues.."."
	else
		message = roll.player.." wins "..self.link.." with "..rollType.announceName.." roll."
	end
	Addon:AnnounceWinner(message)
end

function prototype:GetCurrentLootIndex()
	local numLootItems = GetNumLootItems()
	for i = 1, numLootItems do
		local lootID = Addon:LootIDForLootFrameSlot(i)
		if lootID == self.lootID then
			return i
		end
	end
	return nil
end

function prototype:IsFullyAssigned()
	return #self.assigning - self.assigned <= 0
end

function prototype:CancelLootAssigning(all)
	all = all or false

	if all then
		for _, assignment in pairs(self.assigning) do
			Addon:CancelTimer(assignment.timer)
		end
		S:Clear(self.assigning)
	else
		if S:IsEmpty(self.assigning) then
			return
		end

		local finishedAssignment = S:FilterFirst(self.assigning, function(assignment)
			return Addon:TimeLeft(assignment.timer) == 0
		end)

		if finishedAssignment then
			S:RemoveValue(self.assigning, finishedAssignment)
		else
			Addon:CancelTimer(self.assigning[1])
			table.remove(self.assigning, 1)
		end
	end
end

function prototype:LootAssigned(cancelAll)
	if self.assigned then
		return
	end

	self:CancelLootAssigning(cancelAll)
	self:AnnounceWinner(self.assigningTo)
	self.assigned = self.assigned + 1
end

function prototype:AssignLoot(roll)
	if self.assigned >= self.quantity or self:IsFullyAssigned() then
		return
	end

	if Addon.Settings.Debug.DebugMode then
		self:LootAssigned()
	else
		local lootIndex = self:GetCurrentLootIndex()
		if not lootIndex then
			UIErrorsFrame:AddMessage("The item is not available. Is the loot window open?", 1.0, 0.0, 0.0)
		end

		local candidateIndex = roll:GetCurrentCandidateIndex()
		if not candidateIndex then
			UIErrorsFrame:AddMessage("Chosen player is not eligible for loot.", 1.0, 0.0, 0.0)
		end

		table.insert(self.assigning, {
			timer = Addon:ScheduleTimer(function()
				self:CancelLootAssigning()
				UIErrorsFrame:AddMessage("Unknown error while giving out loot.", 1.0, 0.0, 0.0)
			end, Addon.Settings.LootAssignTimeout),
			roll = roll,
		})
		GiveMasterLoot(lootIndex, candidateIndex)
	end
end