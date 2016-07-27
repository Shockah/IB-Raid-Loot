local Frame = nil
local ItemsFrame = nil
local ItemFrames = 0

local currentLootIDs = IBRaidLootData["currentLootIDs"]
local currentLoot = IBRaidLootData["currentLoot"]
local RollTypes = IBRaidLootData["RollTypes"]
local RollTypeList = IBRaidLootData["RollTypeList"]

function IBRaidLoot:CreatePendingRollsFrame()
	if Frame ~= nil then
		self:UpdatePendingRollsFrame()
		Frame:Show()
		return Frame
	end

	Frame = CreateFrame("Frame", "IBRaidLoot_PendingRollsFrame", UIParent)
	Frame:SetFrameStrata("HIGH")
	Frame:SetWidth(600)
	Frame:SetHeight(400)
	Frame:SetPoint("CENTER", 0, 0)
	Frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 8, right = 8, top = 8, bottom = 8 }
	})
	Frame:SetBackdropColor(0, 0, 0, 1)
	Frame:SetMovable(true)
	Frame:Show()
	table.insert(UISpecialFrames, "IBRaidLootFrame")

	self:SetupWindowFrame(Frame, "IB Raid Loot - Pending Rolls")

	local fScroll = CreateFrame("ScrollFrame", "IBRaidLoot_PendingRollsScrollFrame", Frame, "UIPanelScrollFrameTemplate")
	fScroll:SetWidth(fScroll:GetParent():GetWidth() - 24 - 24)
	fScroll:SetHeight(fScroll:GetParent():GetHeight() - 36)
	fScroll:SetPoint("TOPLEFT", 12, -24)
	fScroll:Show()

	ItemsFrame = CreateFrame("Frame", "IBRaidLoot_PendingRollsContentFrame", nil, nil);
	ItemsFrame:SetWidth(fScroll:GetWidth())
	ItemsFrame:SetHeight(60)
	ItemsFrame:SetBackdrop({
		bgFile = "",
		edgeFile = "",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 1, right = 1, top = 1, bottom = 1}
	})
	fScroll:SetScrollChild(ItemsFrame)
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
	local i = ItemFrames + 1
	local f = _G["IBRaidLoot_PendingRollsItemFrame"..i]
	local fIcon = nil
	local fName = nil

	ItemFrames = ItemFrames + 1
	if f == nil then
		f = CreateFrame("Frame", "IBRaidLoot_PendingRollsItemFrame"..i, ItemsFrame, nil)
		f:SetWidth(ItemsFrame:GetWidth())
		f:SetHeight(60)
		f:SetPoint("TOPLEFT", 0, -60 * (i - 1))
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = {left = 1, right = 1, top = 1, bottom = 1}
		})

		local EDGE_MARGIN = 6
		local BUTTON_MARGIN = 6

		fIcon = CreateFrame("Button", "IBRaidLoot_PendingRollsItemIcon"..i, f, "ItemButtonTemplate")
		fIcon:SetWidth(48)
		fIcon:SetHeight(48)
		fIcon.icon:SetWidth(48)
		fIcon.icon:SetHeight(48)
		fIcon:SetPoint("TOPLEFT", EDGE_MARGIN, -EDGE_MARGIN)
		fIcon:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		fIcon:RegisterForClicks("RightButtonDown")

		local buttonCount = self:GetRollTypeButtonCount()

		local ICON_NAME_OFFSET = 8
		local NAME_BUTTONS_OFFSET = 16
		local BUTTON_SIZE = 32

		local maxOffX = 0
		local xx = 0
		local baseX = -EDGE_MARGIN
		table.foreach(RollTypeList, function(_, obj)
			if obj["button"] then
				local fButton = CreateFrame("Button", "IBRaidLoot_PendingRollsItemButton_"..obj["type"]..i, f, nil)
				fButton:SetWidth(BUTTON_SIZE)
				fButton:SetHeight(BUTTON_SIZE)
				local offX = baseX - (buttonCount - xx - 1) * (BUTTON_SIZE + BUTTON_MARGIN) - BUTTON_MARGIN
				if offX < maxOffX then
					maxOffX = offX
				end
				fButton:SetPoint("RIGHT", offX, 0)
				fButton.isMouseDown = false

				local fButtonIcon = fButton:CreateTexture(nil, "ARTWORK")
				fButtonIcon:SetAllPoints(true)
				fButtonIcon:SetTexture(obj["textureUp"])
				fButton.icon = fButtonIcon

				xx = xx + 1
			end
		end)
		local buttonsWidth = -maxOffX + BUTTON_SIZE

		fName = fIcon:CreateFontString("IBRaidLoot_PendingRollsItemName"..i, "ARTWORK", "GameFontNormal")
		fName:SetPoint("TOPLEFT", fIcon, "TOPRIGHT", ICON_NAME_OFFSET, -EDGE_MARGIN - 2)
		fName:SetWidth(f:GetWidth() - EDGE_MARGIN * 2 - fIcon:GetWidth() - ICON_NAME_OFFSET - NAME_BUTTONS_OFFSET - buttonsWidth)
		fName:SetJustifyH("LEFT")

		local ROLL_SIZE = 12
		local ROLL_ICON_TEXT_MARGIN = 2
		local ROLL_TEXT_SIZE = 18
		local ROLL_MARGIN = 6

		xx = 0
		baseX = ICON_NAME_OFFSET
		table.foreach(RollTypeList, function(_, obj)
			local fRolls = CreateFrame("Button", "IBRaidLoot_PendingRollsItemRolls"..obj["type"]..i, f, nil)
			fRolls:SetWidth(ROLL_SIZE + ROLL_ICON_TEXT_MARGIN + ROLL_TEXT_SIZE)
			fRolls:SetHeight(ROLL_SIZE)
			fRolls:SetPoint("BOTTOMLEFT", fIcon, "BOTTOMRIGHT", baseX + xx * (ROLL_SIZE + ROLL_ICON_TEXT_MARGIN + ROLL_TEXT_SIZE + ROLL_MARGIN), EDGE_MARGIN + 2)
			fRolls:SetScript("OnLeave", function(self)
				GameTooltip:Hide()
			end)

			local fRollsIcon = fRolls:CreateTexture(nil, "ARTWORK")
			fRollsIcon:SetWidth(ROLL_SIZE)
			fRollsIcon:SetHeight(ROLL_SIZE)
			fRollsIcon:SetPoint("LEFT", 0, 0)
			fRollsIcon:SetTexture(obj["textureUp"])
			fRolls.icon = fRollsIcon

			local fRollsText = fIcon:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			fRollsText:SetPoint("LEFT", fRollsIcon, "RIGHT", ROLL_ICON_TEXT_MARGIN, 0)
			fRollsText:SetWidth(ROLL_TEXT_SIZE)
			fRollsText:SetJustifyH("LEFT")
			fRolls.text = fRollsText

			xx = xx + 1
		end)
	else
		fIcon = _G["IBRaidLoot_PendingRollsItemIcon"..i]
		fName = _G["IBRaidLoot_PendingRollsItemName"..i]
	end

	fIcon.icon:SetTexture(lootObj["texture"])
	fIcon:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT");
		GameTooltip:SetHyperlink(lootObj["link"])
	end)
	--[[fIcon:SetScript("OnClick", function(self)
		if IsControlKeyDown() then
			DressUpItemLink(lootObj["link"])
		end
	end)]]--
	fIcon:Show()

	local r, g, b = GetItemQualityColor(lootObj["quality"])
	fName:SetText(lootObj["name"])
	fName:SetTextColor(r, g, b, 1)
	fName:Show()

	table.foreach(RollTypeList, function(_, obj)
		if obj["button"] then
			local fButton = _G["IBRaidLoot_PendingRollsItemButton_"..obj["type"]..i]
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
				IBRaidLoot:UpdatePendingRollsFrame(true)
			end)
			fButton:Show()
		end
	end)

	table.foreach(RollTypeList, function(_, obj)
		local fRolls = _G["IBRaidLoot_PendingRollsItemRolls"..obj["type"]..i]
		local rolls = self:GetRollsOfType(lootObj, obj["type"])
		fRolls.text:SetText(#rolls)
		fRolls:SetScript("OnEnter", function(self)
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
		fRolls:Show()
	end)

	ItemsFrame:SetHeight(60 * i)
	f:Show()
	
	return f
end

function IBRaidLoot:ClearPendingRollsItemFrames()
	for i = 1, ItemFrames do
		local f = _G["IBRaidLoot_PendingRollsItemFrame"..i]
		if f ~= nil then
			f:Hide()
		end
	end
	ItemFrames = 0
end

function IBRaidLoot:UpdatePendingRollsFrame(closeIfNoItems)
	if ItemsFrame == nil then
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