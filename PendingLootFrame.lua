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
		if not frame.loot.link then
			return
		end

		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetHyperlink(frame.loot.link)
	end)
	frame.icon:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

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
	frame.pendingButton.icon:SetTexture(pendingRollType.icon.."-Down")

	frame.timerHighlight = frame.container:CreateTexture(nil, "BACKGROUND")
	frame.timerHighlight:SetPoint("TOPLEFT", frame.container, "TOPLEFT", 0, 0)
	frame.timerHighlight:SetPoint("BOTTOMLEFT", frame.container, "BOTTOMLEFT", 0, 0)
	frame.timerHighlight:SetColorTexture(0.5, 0.5, 0.5, 0.3)

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
	frame.nameLabel:SetPoint("RIGHT", frame.container, "RIGHT", 0, 0)

	frame.timerHighlight:SetWidth(frame.container:GetWidth())
	frame.container:SetScript("OnUpdate", function(self)
		if (not frame.loot.startTime) or (not frame.loot.timeout) then
			frame.timerHighlight:SetWidth(0)
			return
		end

		local f = (GetTime() - frame.loot.startTime) / frame.loot.timeout
		f = 1 - f
		f = math.min(math.max(f, 0), 1)
		frame.timerHighlight:SetWidth(self:GetWidth() * f)

		local r, g, b
		if f >= 0.2 and f < 0.5 then
			r, g, b = unpack(S:Lerp((f - 0.2) / 0.3, { 1.0, 1.0, 0.0 }, { 0.5, 0.5, 0.5 }))
		elseif f < 0.2 then
			r, g, b = unpack(S:Lerp(f / 0.2, { 1.0, 0.0, 0.0 }, { 1.0, 1.0, 0.0 }))
		else
			r, g, b = 0.5, 0.5, 0.5
		end
		frame.timerHighlight:SetColorTexture(r, g, b, 0.3)
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
	if self.loot == loot then
		return
	end

	self.loot = loot

	Addon.ItemInfoRequest:Get({ loot.link }, function(itemInfos)
		--itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
		--itemEquipLoc, iconFileDataID, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, 
		--isCraftingReagent = GetItemInfo(itemID or "itemString" or "itemName" or "itemLink")

		local itemInfo = itemInfos[loot.link]
		local itemName = itemInfo[1]
		local itemRarity = itemInfo[3]
		local itemTexture = itemInfo[10]

		self.icon.icon:SetTexture(itemTexture)

		local r, g, b = GetItemQualityColor(itemRarity)
		self.nameLabel:SetText(itemName)
		self.nameLabel:SetTextColor(r, g, b, 1)

		local availableRollTypes = loot:GetAvailableRollTypes()

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
					self.rollType:AddToTooltip(loot.rolls, S:Filter(loot.rolls, function(roll)
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

					local localRoll = loot:GetLocalRoll()
					localRoll:SetType(self.rollType.type)
					outerSelf:UpdateButtonAppearance()

					-- TODO: send roll
				end)

				rollButton:ClearAllPoints()
				rollButton:SetPoint("LEFT", self.container, "LEFT", 6 + (index - 1) * 24, -self:GetHeight() / 6)
				rollButton:Show()

				index = index + 1
			else
				rollButton:Hide()
			end
		end

		self.pendingButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:ClearLines()
			self.rollType:AddToTooltip(loot.rolls, S:Filter(loot.rolls, function(roll)
				return roll.type == self.rollType.type
			end), loot.cacheIsEquippable)
			GameTooltip:Show()
		end)
		self.pendingButton:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)

		self.pendingButton:ClearAllPoints()
		self.pendingButton:SetPoint("RIGHT", self.container, "RIGHT", -6, -self:GetHeight() / 6)

		self:UpdateButtonAppearance()
	end)
end

function prototype:UpdateButtonAppearance()
	if not self.loot then
		return
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

		self.pendingButton.icon:SetTexture(self.pendingButton.rollType.icon)
		self.pendingButton.icon:SetVertexColor(0.4, 0.4, 0.4)
		self.pendingButton:Show()
	else
		local localRoll = self.loot:GetLocalRoll()
		local localRollType = localRoll and localRoll.type or nil

		for _, rollButton in pairs(self.rollButtons) do
			rollButton.icon:SetTexture(rollButton.rollType.icon)
			if rollButton.rollType.type == localRollType then
				rollButton.icon:SetVertexColor(1.0, 1.0, 0.0)
			else
				rollButton.icon:SetVertexColor(0.4, 0.4, 0.4)
			end
		end

		self.pendingButton:Hide()
	end
end