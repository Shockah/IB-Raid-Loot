local Frame = nil
local ItemsFrame = nil

local currentLootIDs = IBRaidLootData["currentLootIDs"]
local currentLoot = IBRaidLootData["currentLoot"]
local RollTypes = IBRaidLootSettings["RollTypes"]
local RollTypeList = IBRaidLootSettings["RollTypeList"]

function IBRaidLoot:CreatePendingRollsFrame()
	if Frame ~= nil then
		Frame:Show()
		self:UpdatePendingRollsFrame()
		return Frame
	end

	Frame = CreateFrame("Frame", "IBRaidLoot_PendingRollsFrame", UIParent, "BasicFrameTemplateWithInset")
	Frame:SetFrameStrata("HIGH")
	Frame:SetSize(600, 400)
	Frame:SetPoint("CENTER", 0, 0)
	Frame:EnableMouse(true)
	Frame:SetMovable(true)

	table.insert(UISpecialFrames, "IBRaidLoot_PendingRollsFrame")
	self:SetupWindowFrame(Frame)

	local fTitle = Frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fTitle:SetPoint("TOP", 0, -6)
	fTitle:SetText("Pending Rolls")
	fTitle:SetJustifyV("TOP")
	Frame.title = fTitle

	local fScroll = CreateFrame("ScrollFrame", nil, Frame, "UIPanelScrollFrameTemplate")
	fScroll:SetPoint("TOPLEFT", 6, -24 - 6)
	fScroll:SetSize(Frame:GetWidth() - 24 - 12, Frame:GetHeight() - 24 - 12)

	ItemsFrame = CreateFrame("Frame", nil, nil, nil);
	ItemsFrame:SetWidth(fScroll:GetWidth())
	ItemsFrame:SetPoint("TOPLEFT", 0, 0)
	fScroll:SetScrollChild(ItemsFrame)
	ItemsFrame.subframeCount = 0
	ItemsFrame.subframes = {}
	ItemsFrame:Show()

	self:CreatePendingRollsItemFrames()
	return Frame
end

function IBRaidLoot:CreatePendingRollsItemFrames(closeIfNoItems)
	local hasItems = false
	for _, uniqueLootID in pairs(currentLootIDs) do
		local lootObj = currentLoot[uniqueLootID]
		if not self:DidRollOnItem(lootObj) then
			self:CreatePendingRollsItemFrame(lootObj)
			hasItems = true
		end
	end
	if not hasItems and closeIfNoItems then
		Frame:Hide()
	end
end

function IBRaidLoot:CreatePendingRollsItemFrame(lootObj)
	local i = ItemsFrame.subframeCount + 1
	local f = ItemsFrame.subframes[i]

	local HEIGHT = 60
	local BORDER_FIX = 4
	local PADDING = 6 + BORDER_FIX
	local CHILD_MARGIN = 6
	local BUTTON_SIZE = 32
	local BUTTON_MARGIN = 4
	local ROLL_INFO_ICON_SIZE = 12
	local ROLL_INFO_TEXT_SIZE = 18
	local ROLL_INFO_ICON_TEXT_MARGIN = 2
	local ROLL_INFO_MARGIN = 4

	ItemsFrame.subframeCount = ItemsFrame.subframeCount + 1
	if f == nil then
		f = CreateFrame("Frame", nil, ItemsFrame)
		ItemsFrame.subframes[i] = f
		f:SetWidth(ItemsFrame:GetWidth() + BORDER_FIX * 2)
		f:SetHeight(HEIGHT + BORDER_FIX * 2)
		f:SetPoint("TOPLEFT", -BORDER_FIX, -HEIGHT * (i - 1) + BORDER_FIX)
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = {left = BORDER_FIX, right = BORDER_FIX, top = BORDER_FIX, bottom = BORDER_FIX}
		})

		fInner = CreateFrame("Frame", nil, f)
		fInner:SetWidth(f:GetWidth() - PADDING * 2)
		fInner:SetHeight(f:GetHeight() - PADDING * 2)
		fInner:SetPoint("CENTER", 0, 0)
		local availableWidth = fInner:GetWidth()

		fIcon = CreateFrame("Button", nil, fInner, "ItemButtonTemplate")
		fIcon:SetSize(32, 32)
		fIcon:SetScale(1 / 32 * 40)
		fIcon:SetPoint("LEFT", 2, 0)
		fIcon:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		f.icon = fIcon
		availableWidth = availableWidth - fIcon:GetWidth() * fIcon:GetScale() - CHILD_MARGIN - 2

		local rollButtonCount = self:GetRollTypeButtonCount()
		local xx = 0
		f.rollButtons = {}
		for _, obj in pairs(RollTypeList) do
			if obj["button"] then
				local fButton = CreateFrame("Button", nil, fInner)
				fButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
				fButton:SetPoint("RIGHT", -(rollButtonCount - xx - 1) * (BUTTON_SIZE + BUTTON_MARGIN) + BUTTON_MARGIN - CHILD_MARGIN, 0)
				fButton.isMouseDown = false
				table.insert(f.rollButtons, fButton)
				if xx ~= 0 then
					availableWidth = availableWidth - BUTTON_MARGIN
				end
				availableWidth = availableWidth - fButton:GetWidth()

				local fButtonIcon = fButton:CreateTexture(nil, "ARTWORK")
				fButtonIcon:SetAllPoints(true)
				fButtonIcon:SetTexture(obj["textureUp"])
				fButton.icon = fButtonIcon

				xx = xx + 1
			end
		end

		fName = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		fName:SetPoint("LEFT", fIcon, "RIGHT", CHILD_MARGIN, 8)
		fName:SetWidth(availableWidth)
		fName:SetJustifyH("LEFT")
		f.name = fName

		xx = 0
		f.rollInfos = {}
		local w = ROLL_INFO_ICON_SIZE + ROLL_INFO_ICON_TEXT_MARGIN + ROLL_INFO_TEXT_SIZE
		for _, obj in pairs(RollTypeList) do
			local fRollInfo = CreateFrame("Frame", nil, fInner)
			fRollInfo:SetWidth(w)
			fRollInfo:SetHeight(ROLL_INFO_ICON_SIZE)
			fRollInfo:SetPoint("BOTTOMLEFT", fIcon, "BOTTOMRIGHT", CHILD_MARGIN + xx * (w + ROLL_INFO_MARGIN), 4)
			fRollInfo:SetScript("OnLeave", function(self)
				GameTooltip:Hide()
			end)
			table.insert(f.rollInfos, fRollInfo)

			local fRollInfoIcon = fInner:CreateTexture(nil, "ARTWORK")
			fRollInfoIcon:SetSize(ROLL_INFO_ICON_SIZE, ROLL_INFO_ICON_SIZE)
			fRollInfoIcon:SetPoint("LEFT", fRollInfo, "LEFT", 0, 0)
			fRollInfoIcon:SetTexture(obj["textureUp"])
			fRollInfo.icon = fRollInfoIcon

			local fRollInfoText = fInner:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			fRollInfoText:SetWidth(ROLL_INFO_TEXT_SIZE)
			fRollInfoText:SetHeight(ROLL_INFO_ICON_SIZE)
			fRollInfoText:SetPoint("LEFT", fRollInfoIcon, "RIGHT", ROLL_INFO_ICON_TEXT_MARGIN, 0)
			fRollInfoText:SetJustifyH("LEFT")
			fRollInfo.text = fRollInfoText

			xx = xx + 1
		end
	end

	f.icon.icon:SetTexture(lootObj["texture"])
	f.icon:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT");
		GameTooltip:SetHyperlink(lootObj["link"])
	end)
	--[[fIcon:SetScript("OnClick", function(self)
		if IsControlKeyDown() then
			DressUpItemLink(lootObj["link"])
		end
	end)]]--

	local r, g, b = GetItemQualityColor(lootObj["quality"])
	f.name:SetText(lootObj["name"])
	f.name:SetTextColor(r, g, b, 1)

	local index = 0
	for _, obj in pairs(RollTypeList) do
		if obj["button"] then
			index = index + 1
			local fButton = f.rollButtons[index]
			fButton:SetScript("OnEnter", function(self)
				if not self.isMouseDown then
					self.icon:SetTexture(obj["textureHighlight"])
				end
				GameTooltip:SetOwner(self, "ANCHOR_LEFT");
				GameTooltip:SetText(obj["type"])
			end)
			fButton:SetScript("OnLeave", function(self)
				if not self.isMouseDown then
					self.icon:SetTexture(obj["textureUp"])
				end
				GameTooltip:Hide()
			end)
			fButton:SetScript("OnMouseDown", function(self)
				self.icon:SetTexture(obj["textureDown"])
				GameTooltip:Hide()
				self.isMouseDown = true
			end)
			fButton:SetScript("OnMouseUp", function(self)
				self.icon:SetTexture(obj["textureUp"])
				GameTooltip:Hide()
				self.isMouseDown = false
			end)
			fButton:SetScript("OnClick", function(self)
				local rollObj = {}
				rollObj["uniqueLootID"] = lootObj["uniqueLootID"]
				rollObj["type"] = obj["type"]
				rollObj["value"] = 0

				if IBRaidLoot:IsMasterLooter() then
					if RollTypes[rollObj["type"]]["shouldRoll"] then
						rollObj["value"] = random(100)
					end
					IBRaidLoot:CommMessage("RollResponse", rollObj, "RAID")
				else
					IBRaidLoot:CommMessage("Roll", rollObj, "RAID")
				end
				
				rollObj["player"] = GetUnitName("player")
				lootObj["rolls"][rollObj["player"]] = rollObj
				if ItemFrames == 1 then
					IBRaidLoot:CreateRollSummaryFrame()
				end
				IBRaidLoot:UpdatePendingRollsFrame(true)
				IBRaidLoot:UpdateRollSummaryFrameForLoot(lootObj["uniqueLootID"])
			end)
		end
	end

	index = 0
	for _, obj in pairs(RollTypeList) do
		index = index + 1
		local fRollInfo = f.rollInfos[index]
		local rolls = self:GetRollsOfType(lootObj, obj["type"])
		table.sort(rolls, function(a, b)
			return IBRaidLoot:RollSortComparison(a, b)
		end)
		fRollInfo.text:SetText(#rolls)
		fRollInfo:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_LEFT");
			GameTooltip:ClearLines()
			table.foreach(rolls, function(_, rollObj)
				if RollTypes[rollObj["type"]]["shouldRoll"] then
					GameTooltip:AddDoubleLine(rollObj["player"], rollObj["value"])
				else
					GameTooltip:AddLine(rollObj["player"])
				end
			end)
			GameTooltip:Show()
		end)
	end

	f:Show()
	ItemsFrame:SetHeight(HEIGHT * i)
	
	return f
end

function IBRaidLoot:ClearPendingRollsItemFrames()
	for _, frame in pairs(ItemsFrame.subframes) do
		frame:Hide()
	end
	ItemsFrame.subframeCount = 0
end

function IBRaidLoot:UpdatePendingRollsFrame(closeIfNoItems)
	if Frame == nil or not Frame:IsVisible() then
		return
	end
	
	self:ClearPendingRollsItemFrames()
	self:CreatePendingRollsItemFrames(closeIfNoItems)
end

function IBRaidLoot:GetRollTypeButtonCount()
	local buttons = 0
	table.foreach(RollTypeList, function(_, obj)
		if obj["button"] then
			buttons = buttons + 1
		end
	end)
	return buttons
end