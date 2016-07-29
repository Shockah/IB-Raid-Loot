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
	for _, lootID in pairs(currentLootIDs) do
		local lootObj = currentLoot[lootID]
		if self:AmIOnRollListForItem(lootObj) and not self:DidRollOnItem(lootObj) then
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

		local fHighlight = fInner:CreateTexture(nil, "BACKGROUND")
		fHighlight:SetSize(fInner:GetWidth(), fInner:GetHeight())
		fHighlight:SetPoint("TOPLEFT", 0, 0)
		fHighlight:SetColorTexture(1, 1, 1, 0.15)
		f.highlight = fHighlight

		fIcon = CreateFrame("Button", nil, fInner, "ItemButtonTemplate")
		fIcon:SetPoint("LEFT", 2, 0)
		fIcon:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		f.icon = fIcon
		availableWidth = availableWidth - fIcon:GetWidth() * fIcon:GetScale() - CHILD_MARGIN - 2

		local fQuantity = fIcon:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		fQuantity:SetPoint("BOTTOMRIGHT", -2, 2)
		fQuantity:SetTextColor(1, 1, 1, 1)
		fQuantity:SetJustifyH("RIGHT")
		fQuantity:SetJustifyV("BOTTOM")
		local filename, fontHeight, flags = fQuantity:GetFont()
		fQuantity:SetFont(filename, fontHeight, "OUTLINE")
		f.quantity = fQuantity

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
			if obj["order"] <= 100 then
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
	end

	local iName, _, iQuality, _, _, _, _, _, _, iTexture, _ = GetItemInfo(lootObj["link"])
	if not iName then
		return
	end

	if GetTime() < lootObj["timeoutEnd"] then
		f:SetScript("OnUpdate", function(self, elapsed)
			local time = GetTime()
			local timeMin = lootObj["timeoutStart"]
			local timeMax = lootObj["timeoutEnd"]
			local v = (time - timeMin) / (timeMax - timeMin)
			v = math.min(math.max(v, 0), 1)
			local v2 = 1 - v

			self.highlight:SetWidth(self.highlight:GetParent():GetWidth() * v2)
			if v == 1 then
				self:SetScript("OnUpdate", nil)
			end
		end)
	else
		f:SetScript("OnUpdate", nil)
	end

	f.icon.icon:SetTexture(iTexture)
	f.icon:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT");
		GameTooltip:SetHyperlink(lootObj["link"])
	end)
	f.icon:SetScript("OnClick", function(self)
		if IsControlKeyDown() then
			DressUpItemLink(lootObj["link"])
		elseif IsShiftKeyDown() then
			IBRaidLoot:InsertInChatEditbox(lootObj["link"])
		end
	end)

	if lootObj["quantity"] == 1 then
		f.quantity:SetText("")
	else
		f.quantity:SetText(lootObj["quantity"])
	end

	local r, g, b = GetItemQualityColor(iQuality)
	f.name:SetText(iName)
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
				local player = GetUnitName("player", true)
				if not string.find(player, "-") then
					player = player.."-"..GetRealmName()
				end

				local rollObj = lootObj["rolls"][player]
				rollObj["type"] = obj["type"]

				local sendObj = {}
				sendObj["lootID"] = lootObj["lootID"]
				sendObj["type"] = rollObj["type"]

				if IBRaidLoot:IsMasterLooter() then
					if RollTypes[rollObj["type"]]["shouldRoll"] then
						rollObj["value"] = random(100)
						sendObj["value"] = rollObj["value"]
					end
					sendObj["player"] = player
					IBRaidLoot:CommMessage("RollResponse", sendObj, "RAID")
				else
					IBRaidLoot:CommMessage("Roll", sendObj, "RAID")
				end

				if ItemsFrame.subframeCount == 1 then
					IBRaidLoot:GoToFirstUnassigned()
					IBRaidLoot:CreateRollSummaryFrame()
				end
				IBRaidLoot:UpdatePendingRollsFrame(true)
				IBRaidLoot:UpdateRollSummaryFrameForLoot(lootObj["lootID"])
			end)
		end
	end

	index = 0
	for _, obj in pairs(RollTypeList) do
		if obj["order"] <= 100 then
			index = index + 1
			local fRollInfo = f.rollInfos[index]
			local rolls = self:GetRollsOfType(lootObj, obj["type"])
			self:SortRolls(rolls)
			fRollInfo.text:SetText(#rolls)
			fRollInfo:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_LEFT");
				GameTooltip:ClearLines()
				GameTooltip:AddLine(obj["type"])
				for _, rollObj in pairs(rolls) do
					if RollTypes[rollObj["type"]]["shouldRoll"] then
						GameTooltip:AddDoubleLine(string.gsub(rollObj["player"], "%-"..GetRealmName(), ""), rollObj["value"])
					else
						GameTooltip:AddLine(string.gsub(rollObj["player"], "%-"..GetRealmName(), ""))
					end
				end
				GameTooltip:Show()
			end)
		end
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
	for _, obj in pairs(RollTypeList) do
		if obj["button"] then
			buttons = buttons + 1
		end
	end
	return buttons
end