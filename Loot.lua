--[[
	Loot

	Properties:
	* lootID: string -- unique loot ID
	* link: string -- item link
	* quantity: int
	* isNew: bool -- whether this Loot object is still being processed for the first time
	* wasDisplayed: bool -- whether the item was displayed
	* rolls: table -- list of rolls
	* startTime: int -- time the rolling started at
	* timeout: int -- startTime + timeout to end at
	* hideRollsUntilFinished: bool -- initially coming from DB.Settings; hide rollers until rolling is finished
	* cacheIsEquippable: bool -- cached: is item equippable
	* cacheIsUnusable: bool -- cached: is item unusable (only Off-spec and Pass available)
	* cacheDisenchant: bool -- cached: whether the item is disenchantable
	* timeoutTimer: AceTimer ID -- timeout timer
	* assigning: table -- list of structs:
		* timer: AceTimer ID -- loot assigning timeout timer
		* roll: table -- already assigned Roll object
	* assigned: table -- the already assigned/gone amount of loot
		* timer: AceTimer ID -- loot assigning timeout timer
		* roll: table -- Roll object the loot is currently being assigned to
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.Loot = {}
local Class = Addon.Loot

function Class:New(lootID, link, quantity, isNew)
	local obj = S:Clone(prototype)
	obj.lootID = lootID
	obj.link = link
	obj.quantity = quantity or 1
	obj.isNew = (isNew == nil and true or isNew)
	obj.wasDisplayed = false
	obj.rolls = {}
	obj.cacheIsEquippable = false
	obj.cacheIsUnusable = false
	obj.cacheDisenchant = false
	obj.hideRollsUntilFinished = Addon.DB.Settings.Master.HideRollsUntilFinished
	obj.assigning = {}
	obj.assigned = {}
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

function prototype:GetItemInfo()
	if not self.itemInfo then
		self.itemInfo = Addon.ItemInfo:Get(self.link)
	end
	return self.itemInfo
end

function prototype:GetAvailableRollTypes(universal)
	local ENCHANTING_ID = 333
	local rollTypes = S:Map(S:Filter(Addon.orderedRollTypes, function(rollType)
		return rollType.button
	end), function(rollType)
		return rollType.type
	end)
	S:RemoveValue(rollTypes, "Disenchant")
	S:RemoveValue(rollTypes, "Pass")

	local itemInfo = self:GetItemInfo()

	local isWeapon = itemInfo.type.name == "Weapon"
	local isArmor = itemInfo.type.name == "Armor"
	local isMiscArmor = isArmor and itemInfo.subtype.name == "Miscellaneous"
	local isGem = itemInfo.type.name == "Gem"
	local isRelic = isGem and itemInfo.subtype.name == "Artifact Relic"
	local isNonRelicGem = isGem and (not isRelic)
	
	local isEquippable = isWeapon or isArmor or isGem

	local isWrongClass = (not universal) and itemInfo:IsWrongClass()
	local isWrongWeaponType = (not universal) and itemInfo:IsWrongWeaponType()
	local isWrongArmorType = (not universal) and itemInfo:IsWrongArmorType()

	if not universal then
		self.cacheIsEquippable = isEquippable or itemInfo:IsUncreatedSetPiece()
	end

	if isEquippable or itemInfo:IsUncreatedSetPiece() then
		if (not itemInfo:IsUncreatedSetPiece()) or isWeapon then
			S:RemoveValue(rollTypes, "2-set")
			S:RemoveValue(rollTypes, "4-set")
			S:RemoveValue(rollTypes, "Warforged")
		end

		if (isWrongClass or isWrongArmorType or isWrongWeaponType) then
			S:RemoveValue(rollTypes, "2-set")
			S:RemoveValue(rollTypes, "4-set")
			S:RemoveValue(rollTypes, "Major")
			S:RemoveValue(rollTypes, "Minor")
			S:RemoveValue(rollTypes, "Warforged")

			if (not itemInfo:Binds()) or itemInfo:BindsOnEquip() then
				S:RemoveValue(rollTypes, "Transmog")
				if not universal then
					self.cacheIsUnusable = true
				end
			end
		end

		if isMiscArmor or isGem then
			S:RemoveValue(rollTypes, "Transmog")
		end

		local isEnchanter = false
		if universal then
			isEnchanter = true
		else
			isEnchanter = false
			local prof1, prof2 = GetProfessions()
			local profs = { prof1, prof2 }
			for _, prof in pairs(profs) do
				if select(7, GetProfessionInfo(prof)) == ENCHANTING_ID then
					isEnchanter = true
				end
			end
		end

		if isEnchanter and not isWrongClass and not isNonRelicGem then
			table.insert(rollTypes, "Disenchant")
			if universal then
				table.insert(rollTypes, "Pass")
			end
			if not universal then
				self.cacheDisenchant = true
			end
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

function prototype:FixDuplicateRolls()
	if self:HasPendingRolls() then
		return
	end

	local sortedRolls = S:Filter(self.rolls, function(roll)
		return Addon.rollTypes[roll.type].shouldRoll
	end)

	local fixRolls = function(rolls)
		if S:Count(rolls) < 2 then
			return {}
		end

		for _, roll in pairs(rolls) do
			roll:RollAgain()
		end
		return rolls
	end

	local toSync = {}

	local continue = true
	while continue do
		continue = false
		Addon.Roll:Sort(sortedRolls)

		local equalRolls = {}

		for _, roll in pairs(sortedRolls) do
			if S:IsEmpty(equalRolls) then
				table.insert(equalRolls, roll)
			else
				local lastRoll = equalRolls[S:Count(equalRolls)]
				if not roll:IsEqual(lastRoll) then
					local fixedRolls = fixRolls(equalRolls)
					for _, roll in pairs(fixedRolls) do
						S:RemoveValue(toSync, roll)
						table.insert(toSync, roll)
						continue = true
					end
					S:Clear(equalRolls)
				end
				table.insert(equalRolls, roll)
			end
		end

		local fixedRolls = fixRolls(equalRolls)
		for _, roll in pairs(fixedRolls) do
			S:InsertUnique(toSync, roll)
			continue = true
		end
	end

	for _, toSyncRoll in pairs(toSync) do
		Addon.RollValuesMessage:New(self, toSyncRoll):Send()
	end
end

function prototype:HandleDoneRollingActions()
	if self:HasPendingRolls() then
		return
	end

	if self.timeoutTimer then
		Addon:CancelTimer(self.timeoutTimer)
		self.timeoutTimer = nil
	end

	local sortedRolls = S:Clone(self.rolls)
	Addon.Roll:Sort(sortedRolls)

	if Addon:IsMasterLooter() or Addon.Settings.Debug.DebugMode then
		self:FixDuplicateRolls()

		if Addon.DB.Settings.Master.AutoProceed.Enabled then
			if not S:IsEmpty(self.rolls) then
				local everyonePassed = not S:FilterContains(self.rolls, function(roll)
					return roll.type ~= "Pass"
				end)
				local everyoneResponded = not S:FilterContains(self.rolls, function(roll)
					return roll.type == "No Response"
				end)

				if (not everyonePassed) and everyoneResponded or (not Addon.DB.Settings.Master.AutoProceed.OnlyIfEveryoneResponded) then
					for i = 1, self.quantity do
						if sortedRolls[i].type ~= "Pending" and sortedRolls[i].type ~= "No Response" and sortedRolls[i].type ~= "Pass" then
							self:AssignLoot(sortedRolls[i])
						end
					end
				end
			end
		end

		if Addon.PendingFrame.frame then
			Addon.PendingFrame.frame:Update()
		end
	end
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

function prototype:IsFullyAssignedOrPending()
	return #self.assigning + #self.assigned >= self.quantity
end

function prototype:IsFullyAssigned()
	return #self.assigned >= self.quantity
end

function prototype:CancelLootAssigning(all)
	all = all or false

	if all then
		for _, assignment in pairs(self.assigning) do
			Addon:CancelTimer(assignment.timer)
		end
		S:Clear(self.assigning)
		return nil
	else
		if S:IsEmpty(self.assigning) then
			return nil
		end

		local finishedAssignment = S:FilterFirst(self.assigning, function(assignment)
			return Addon:TimeLeft(assignment.timer) == 0
		end)

		if finishedAssignment then
			S:RemoveValue(self.assigning, finishedAssignment)
			return finishedAssignment
		else
			local assignment = self.assigning[1]
			Addon:CancelTimer(self.assigning[1].timer)
			table.remove(self.assigning, 1)
			return assignment
		end
	end
end

function prototype:LootAssigned(cancelAll)
	if self:IsFullyAssigned() then
		return
	end

	local assignment = self:CancelLootAssigning(cancelAll)
	if assignment then
		assignment.roll.assigned = true
		self:AnnounceWinner(assignment.roll)
		table.insert(self.assigned, assignment)
		Addon.LootAssignedMessage:New(self, assignment.roll):Send()
	else
		table.insert(self.assigned, {})
		Addon.LootAssignedMessage:New(self, nil):Send()
	end

	if self:IsFullyAssigned() then
		local pendingRolls = S:Filter(self.rolls, function(roll)
			return roll.type == "Pending"
		end)
		for _, pendingRoll in pairs(pendingRolls) do
			Addon:CancelTimer(self.timeoutTimer)
			self.timeoutTimer = nil
			pendingRoll.type = "No Response"
			if Addon:IsMasterLooter() then
				pendingRoll:SendRoll(self)
			end
		end
	end

	if Addon.PendingFrame.frame then
		Addon.PendingFrame.frame:Update()
	end
end

function prototype:AssignLoot(roll)
	if self:IsFullyAssignedOrPending() then
		return
	end

	if Addon.Settings.Debug.DebugMode then
		table.insert(self.assigning, {
			timer = nil,
			roll = roll,
		})
		self:LootAssigned()
	else
		local lootIndex = self:GetCurrentLootIndex()
		if not lootIndex then
			UIErrorsFrame:AddMessage("The item is not available. Is the loot window open?", 1.0, 0.0, 0.0)
			return
		end

		local candidateIndex = roll:GetCurrentCandidateIndex(lootIndex)
		if not candidateIndex then
			UIErrorsFrame:AddMessage("Chosen player is not eligible for loot.", 1.0, 0.0, 0.0)
			return
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