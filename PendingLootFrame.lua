local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.PendingLootFrame = {}
local Class = Addon.PendingLootFrame

local instances = {}
local nextId = 1

function Class:New(parentFrame)
	local frame = CreateFrame("Frame", parentFrame:GetParent():GetParent():GetName().."ItemFrame"..nextId, parentFrame)
	frame = S:CloneInto(prototype, frame)
	nextId = nextId + 1

	frame.free = false

	local BORDER_FIX = 4
	frame:SetBackdrop({
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background-Dark]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = {
			left = BORDER_FIX,
			right = BORDER_FIX,
			top = BORDER_FIX,
			bottom = BORDER_FIX,
		},
	})

	frame.icon = CreateFrame("Button", nil, frame, "ItemButtonTemplate")
	frame.icon:SetPoint("LEFT", 2, 0)
	frame.icon:SetScript("OnEnter", function(self)
		if not frame.loot then
			return
		end

		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetHyperlink(frame.loot.link)
	end)
	frame.icon:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	frame.icon:SetScript("OnClick", function(self)
		if not frame.loot then
			return
		end

		if IsControlKeyDown() then
			DressUpItemLink(frame.loot.link)
		elseif IsShiftKeyDown() then
			S:InsertInChatEditbox(frame.loot.link)
		end
	end)

	frame.quantityLabel = frame.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.quantityLabel:SetPoint("BOTTOMRIGHT", -2, 2)
	frame.quantityLabel:SetTextColor(1, 1, 1, 1)
	frame.quantityLabel:SetJustifyH("RIGHT")
	frame.quantityLabel:SetJustifyV("BOTTOM")
	local filename, fontHeight, flags = frame.quantityLabel:GetFont()
	frame.quantityLabel:SetFont(filename, fontHeight, "OUTLINE")

	frame.container = CreateFrame("Frame", frame:GetName().."Container", frame)

	frame.nameLabel = frame.container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.nameLabel:SetJustifyH("LEFT")

	frame.rollButtons = {}
	for _, rollType in pairs(Addon.orderedRollTypes) do
		local rollButton = CreateFrame("Button", nil, frame.container)
		rollButton:SetSize(20, 20)
		rollButton.rollType = rollType

		rollButton.icon = rollButton:CreateTexture(nil, "ARTWORK")
		rollButton.icon:SetAllPoints(true)
		rollButton.icon:SetTexture(rollType.icon)

		table.insert(frame.rollButtons, rollButton)
	end

	local pendingRollType = Addon.rollTypes["Pending"]

	frame.pendingButton = CreateFrame("Button", nil, frame.container)
	frame.pendingButton:SetSize(20, 20)
	frame.pendingButton.rollType = pendingRollType

	frame.pendingButton.icon = frame.pendingButton:CreateTexture(nil, "ARTWORK")
	frame.pendingButton.icon:SetAllPoints(true)
	frame.pendingButton.icon:SetTexture(pendingRollType.icon)

	local noResponseRollType = Addon.rollTypes["No Response"]

	frame.noResponseButton = CreateFrame("Button", nil, frame.container)
	frame.noResponseButton:SetSize(20, 20)
	frame.noResponseButton.rollType = noResponseRollType

	frame.noResponseButton.icon = frame.noResponseButton:CreateTexture(nil, "ARTWORK")
	frame.noResponseButton.icon:SetAllPoints(true)
	frame.noResponseButton.icon:SetTexture(noResponseRollType.icon)

	frame.timerHighlight = frame.container:CreateTexture(nil, "BACKGROUND")
	frame.timerHighlight:SetPoint("TOPLEFT", frame.container, "TOPLEFT", 0, 0)
	frame.timerHighlight:SetPoint("BOTTOMLEFT", frame.container, "BOTTOMLEFT", 0, 0)
	frame.timerHighlight:SetColorTexture(0.5, 0.5, 0.5, 0.3)

	frame.assignButton = CreateFrame("Button", nil, frame.container, "UIPanelButtonTemplate")
	frame.assignButton:SetText(">")
	frame.assignButton:SetSize(32, 20)
	frame.assignButton:SetPoint("TOPRIGHT", frame.container, "TOPRIGHT", 0, 0)
	frame.assignButton:SetScript("OnEnter", function(button)
		local sortedRolls = S:Filter(frame.loot.rolls, function(roll)
			return (not S:FilterContains(frame.loot.assigning, function(assignment)
				return assignment.roll == roll
			end)) and (not S:FilterContains(frame.loot.assigned, function(assignment)
				return assignment.roll == roll
			end))
		end)

		local alreadyAssignedRolls = S:Map(S:Filter(frame.loot.assigned, function(assignment)
			return assignment.roll
		end), function(assignment)
			return assignment.roll
		end)

		if S:IsEmpty(sortedRolls) and S:IsEmpty(alreadyAssignedRolls) then
			return
		end
		Addon.Roll:Sort(sortedRolls)

		S:InsertAll(sortedRolls, alreadyAssignedRolls)

		GameTooltip:SetOwner(button, "ANCHOR_LEFT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine("Assign item to...")

		local rollObj = sortedRolls[1]
		local class = select(2, UnitClass(S:GetPlayerNameWithOptionalRealm(rollObj.player)))
		local colorPart = class and "|c"..RAID_CLASS_COLORS[class].colorStr or ""
		local valuesStr = S:Join(", ", rollObj.values)
		valuesStr = S:IsBlankString(valuesStr) and "" or ": "..valuesStr
		local playerStr = colorPart..S:GetPlayerNameWithOptionalRealm(rollObj.player).."|r".." ("..rollObj.type..valuesStr..")"

		GameTooltip:AddLine("Shift-click to assign to "..playerStr..".", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	frame.assignButton:SetScript("OnLeave", function(button)
		GameTooltip:Hide()
	end)
	frame.assignButton:SetScript("OnClick", function(self)
		local sortedRolls = S:Filter(frame.loot.rolls, function(roll)
			return (not S:FilterContains(frame.loot.assigning, function(assignment)
				return assignment.roll == roll
			end)) and (not S:FilterContains(frame.loot.assigned, function(assignment)
				return assignment.roll == roll
			end))
		end)

		local alreadyAssignedRolls = S:Map(S:Filter(frame.loot.assigned, function(assignment)
			return assignment.roll
		end), function(assignment)
			return assignment.roll
		end)

		if S:IsEmpty(sortedRolls) and S:IsEmpty(alreadyAssignedRolls) then
			return
		end
		Addon.Roll:Sort(sortedRolls)
		S:InsertAllUnique(sortedRolls, alreadyAssignedRolls)

		if IsShiftKeyDown() then
			frame.loot:AssignLoot(sortedRolls[1])
		else
			local groupedRolls = S:Group(sortedRolls, function(roll)
				return roll.type
			end)

			local sorted2Rolls = {}
			for rollType, groupedRollObjs in pairs(groupedRolls) do
				table.insert(sorted2Rolls, {
					type = rollType,
					rolls = groupedRollObjs,
				})
			end
			table.sort(sorted2Rolls, function(a, b)
				return Addon.rollTypes[a.type].index < Addon.rollTypes[b.type].index
			end)

			if not S:IsEmpty(alreadyAssignedRolls) then
				table.insert(sorted2Rolls, {
					type = "Already assigned",
					rolls = alreadyAssignedRolls,
				})
			end

			local menus = {}
			local submenus = {}
			for _, group in pairs(sorted2Rolls) do
				local menusToUse = S:IsEmpty(menus) and menus or submenus
				local rollType = Addon.rollTypes[rollType]
				table.insert(menusToUse, {
					text = group.type,
					isTitle = true,
					icon = rollType and rollType.icon or nil,
				})
				for _, rollObj in pairs(group.rolls) do
					local class = select(2, UnitClass(S:GetPlayerNameWithOptionalRealm(rollObj.player)))
					local colorPart = class and "|c"..RAID_CLASS_COLORS[class].colorStr or ""
					local valuesStr = S:Join(", ", rollObj.values)
					valuesStr = S:IsBlankString(valuesStr) and "" or ": "..valuesStr

					table.insert(menusToUse, {
						text = colorPart..S:GetPlayerNameWithOptionalRealm(rollObj.player).."|r"..valuesStr,
						func = function()
							frame.loot:AssignLoot(rollObj)
						end,
					})
				end
			end

			if not S:IsEmpty(submenus) then
				table.insert(menus, {
					text = "Other",
					hasArrow = true,
					menuList = submenus,
				})
			end
			Addon:ShowDropdown(menus, self)
		end
	end)
	frame.assignButton:Hide()

	table.insert(instances, frame)
	return frame
end

local function SetupFrame(frame)
	local defaultButtonSize = 37

	frame:SetHeight(Addon.DB.Settings.Raider.PendingFrame.Cell.Height)

	frame.container:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 0, 0)
	frame.container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)

	frame.nameLabel:ClearAllPoints()
	frame.nameLabel:SetPoint("TOPLEFT", frame.container, "TOPLEFT", 8, -8)
	frame.nameLabel:SetPoint("RIGHT", frame.container, "RIGHT", -32, 0)

	frame.timerHighlight:SetWidth(frame.container:GetWidth())
	frame.container:SetScript("OnUpdate", function(self)
		if (not frame.loot.startTime) or (not frame.loot.timeout) then
			frame.timerHighlight:SetWidth(0)
			return
		end

		if frame.loot:HasPendingRolls() then
			local f = (GetTime() - frame.loot.startTime) / frame.loot.timeout
			f = 1 - f
			f = math.min(math.max(f, 0), 1)
			frame.timerHighlight:SetWidth(self:GetWidth() * f)

			local r, g, b = 0.5, 0.5, 0.5
			if frame.loot:IsPendingLocalRoll() then
				if f >= 0.3 and f < 0.5 then
					r, g, b = unpack(S:Lerp((f - 0.3) / 0.2, { 1.0, 1.0, 0.0 }, { 0.5, 0.5, 0.5 }))
				elseif f >= 0.1 and f < 0.3 then
					r, g, b = unpack(S:Lerp((f - 0.1) / 0.2, { 1.0, 0.0, 0.0 }, { 1.0, 1.0, 0.0 }))
				elseif f < 0.1 then
					r, g, b = 1.0, 0.0, 0.0
				end
			end
			frame.timerHighlight:SetColorTexture(r, g, b, 0.3)
			frame.timerHighlight:Show()
		elseif frame.loot:IsFullyAssigned() then
			frame.timerHighlight:SetWidth(self:GetWidth())
			frame.timerHighlight:SetColorTexture(0.5, 0.5, 1.0, 0.3)
			frame.timerHighlight:Show()
		else
			frame.timerHighlight:SetWidth(self:GetWidth())
			frame.timerHighlight:SetColorTexture(0.0, 1.0, 0.0, 0.3)
			frame.timerHighlight:Show()
		end
	end)
	
	frame.icon:SetScript("OnUpdate", function(self)
		local availableHeight = frame:GetHeight() - 12
		local buttonScale = availableHeight / defaultButtonSize

		self:SetScript("OnUpdate", nil)
		frame.icon:SetScale(buttonScale)
	end)
end

function Class:Get(parentFrame)
	local frame = S:FilterFirst(instances, function(frame)
		return frame:GetParent() == parentFrame and frame.free
	end)
	if not frame then
		frame = self:New(parentFrame)
	end
	frame.free = false
	SetupFrame(frame)
	frame:Show()
	return frame
end

function prototype:Free()
	self:Hide()
	self:ClearAllPoints()
	self.free = true
end

function prototype:SetLoot(loot)
	self.loot = loot

	Addon.ItemInfoRequest:Get({ loot.link }, function(itemInfos)
		local itemInfo = itemInfos[loot.link]
		
		self.icon.icon:SetTexture(itemInfo.texture)

		local r, g, b = GetItemQualityColor(itemInfo.rarity)
		self.nameLabel:SetText(itemInfo.name)
		self.nameLabel:SetTextColor(r, g, b, 1)

		local availableRollTypes = loot:GetAvailableRollTypes(not loot:IsPendingLocalRoll())

		local outerSelf = self
		local index = 1
		for _, rollButton in pairs(self.rollButtons) do
			if S:FilterContains(availableRollTypes, function(rollType)
				return rollType == rollButton.rollType.type
			end) then
				rollButton:SetScript("OnEnter", function(self)
					self.isMouseOn = true
					if not self.isMouseDown then
						self.icon:SetTexture(self.rollType.icon.."-Hover")
					end
					GameTooltip:SetOwner(self, "ANCHOR_LEFT")
					GameTooltip:ClearLines()
					self.rollType:AddToTooltip(loot, S:Filter(loot.rolls, function(roll)
						return roll.type == self.rollType.type
					end), loot.cacheIsEquippable)
					GameTooltip:Show()
				end)
				rollButton:SetScript("OnLeave", function(self)
					self.isMouseOn = false
					if not self.isMouseDown then
						self.icon:SetTexture(self.rollType.icon)
					end
					GameTooltip:Hide()
				end)
				rollButton:SetScript("OnMouseDown", function(self)
					self.icon:SetTexture(self.rollType.icon.."-Down")
					GameTooltip:Hide()
					self.isMouseDown = true
				end)
				rollButton:SetScript("OnMouseUp", function(self)
					self.icon:SetTexture(self.rollType.icon)
					GameTooltip:Hide()
					self.isMouseDown = false
				end)
				rollButton:SetScript("OnClick", function(self)
					if not loot:IsPendingLocalRoll() then
						return
					end

					local localRoll = loot:GetRollForPlayer()
					localRoll:SetType(self.rollType.type)
					outerSelf:UpdateButtonAppearance()

					localRoll:SendRoll(loot)
				end)

				rollButton:ClearAllPoints()
				rollButton:SetPoint("LEFT", self.container, "LEFT", 6 + (index - 1) * 24, -self:GetHeight() / 6)
				rollButton:Show()

				index = index + 1
			else
				rollButton:Hide()
			end
		end

		local extraButtons = { self.pendingButton, self.noResponseButton }
		for _, extraButton in pairs(extraButtons) do
			extraButton:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_LEFT")
				GameTooltip:ClearLines()
				self.rollType:AddToTooltip(loot, S:Filter(loot.rolls, function(roll)
					return roll.type == self.rollType.type
				end), loot.cacheIsEquippable)
				GameTooltip:Show()
			end)
			extraButton:SetScript("OnLeave", function(self)
				GameTooltip:Hide()
			end)

			extraButton:ClearAllPoints()
			extraButton:SetPoint("RIGHT", self.container, "RIGHT", -6, -self:GetHeight() / 6)
		end

		if loot.cacheIsUnusable and (not loot.wasDisplayed) and Addon.DB.Settings.Raider.AutoPassUnusable then
			if loot:IsPendingLocalRoll() then
				local localRoll = loot:GetRollForPlayer()
				localRoll:SetType(loot.cacheDisenchant and "Disenchant" or "Pass")

				localRoll:SendRoll(loot)
			end
		end

		self:UpdateButtonAppearance()
		loot.wasDisplayed = true
	end)
end

function prototype:Update()
	self:SetLoot(self.loot)
end

function prototype:UpdateButtonAppearance()
	if not self.loot then
		return
	end

	if self.loot.quantity <= 1 then
		self.quantityLabel:Hide()
	else
		if #self.loot.assigned > 0 and (not self.loot:IsFullyAssigned()) then
			self.quantityLabel:SetText((#self.loot.assigned).."/"..self.loot.quantity)
		else
			self.quantityLabel:SetText(self.loot.quantity)
		end
		self.quantityLabel:Show()
	end

	if self.loot:IsPendingLocalRoll() then
		for _, rollButton in pairs(self.rollButtons) do
			if rollButton.isMouseDown then
				rollButton.icon:SetTexture(rollButton.rollType.icon.."-Down")
			elseif rollButton.isMouseOn then
				rollButton.icon:SetTexture(rollButton.rollType.icon.."-Hover")
			else
				rollButton.icon:SetTexture(rollButton.rollType.icon)
			end
			rollButton.icon:SetVertexColor(1.0, 1.0, 1.0)
		end
	else
		local localRoll = self.loot:GetRollForPlayer()
		local localRollType = localRoll and localRoll.type or nil

		for _, rollButton in pairs(self.rollButtons) do
			rollButton.icon:SetTexture(rollButton.rollType.icon)
			if rollButton.rollType.type == localRollType then
				rollButton.icon:SetVertexColor(1.0, 1.0, 0.0)
			else
				rollButton.icon:SetVertexColor(0.4, 0.4, 0.4)
			end
		end
	end

	if self.loot:HasPendingRolls() then
		self.pendingButton.icon:SetVertexColor(0.4, 0.4, 0.4)
		self.pendingButton:Show()

		self.noResponseButton:Hide()
	else
		self.noResponseButton.icon:SetVertexColor(0.4, 0.4, 0.4)
		self.noResponseButton:Show()

		self.pendingButton:Hide()
	end

	if ((not Addon:IsMasterLooter()) and (not Addon.Settings.Debug.DebugMode)) or self.loot:IsFullyAssigned() then
		self.assignButton:Hide()
	else
		self.assignButton:Show()
	end
end