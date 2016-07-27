local Frame = nil
local LinesFrame = nil
local currentIndex = 1

local currentLootIDs = IBRaidLootData["currentLootIDs"]
local currentLoot = IBRaidLootData["currentLoot"]
local RollTypes = IBRaidLootSettings["RollTypes"]
local RollTypeList = IBRaidLootSettings["RollTypeList"]

function IBRaidLoot:CreateRollSummaryFrame()
	if Frame ~= nil then
		Frame:Show()
		self:UpdateRollSummaryFrame()
		return Frame
	end

	Frame = CreateFrame("Frame", "IBRaidLoot_RollSummaryFrame", UIParent, "BasicFrameTemplateWithInset")
	Frame:SetFrameStrata("HIGH")
	Frame:SetSize(350, 400)
	Frame:SetPoint("CENTER", 0, 0)
	Frame:EnableMouse(true)
	Frame:SetMovable(true)

	table.insert(UISpecialFrames, "IBRaidLoot_PendingRollsFrame")
	self:SetupWindowFrame(Frame)

	local fTitle = Frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fTitle:SetPoint("TOP", 0, -6)
	fTitle:SetText("Roll Summary")
	fTitle:SetJustifyV("TOP")
	Frame.title = fTitle

	local fContent = CreateFrame("Frame", nil, Frame)
	fContent:SetSize(Frame:GetWidth() - 24, Frame:GetHeight() - 24 - 12)
	fContent:SetPoint("TOPLEFT", 12, -24 - 6)

	local fScroll = CreateFrame("ScrollFrame", nil, fContent, "UIPanelScrollFrameTemplate")
	fScroll:SetSize(fContent:GetWidth() - 24, fContent:GetHeight() - 56)
	fScroll:SetPoint("TOPLEFT", 0, -56)

	LinesFrame = CreateFrame("Frame", nil, nil, nil);
	LinesFrame:SetWidth(fScroll:GetWidth())
	LinesFrame:SetPoint("TOPLEFT", 0, 0)
	fScroll:SetScrollChild(LinesFrame)
	LinesFrame.subframeCount = 0
	LinesFrame.subframes = {}
	LinesFrame:Show()

	local fIcon = CreateFrame("Button", nil, fContent, "ItemButtonTemplate")
	fIcon:SetPoint("TOPLEFT", 0, 0)
	fIcon:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	fIcon:RegisterForClicks("RightButtonDown")
	Frame.icon = fIcon

	local fName = fContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fName:SetPoint("LEFT", fIcon, "RIGHT", 6, 0)
	fName:SetWidth(fContent:GetWidth() - fIcon:GetWidth() - 12 - 24 * 2 - 48 - 4)
	fName:SetJustifyH("LEFT")
	Frame.name = fName

	local fPrevButton = CreateFrame("Button", nil, fContent, "UIPanelButtonTemplate")
	fPrevButton:SetPoint("LEFT", fName, "RIGHT", 6, 0)
	fPrevButton:SetWidth(24)
	fPrevButton:SetText("<")
	fPrevButton:SetScript("OnClick", function(self)
		IBRaidLoot:GoToPrevRollSummaryLoot()
	end)
	Frame.prevButton = fPrevButton

	local fIndexText = fContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fIndexText:SetPoint("LEFT", fPrevButton, "RIGHT", 2, 0)
	fIndexText:SetWidth(48)
	fIndexText:SetJustifyH("CENTER")
	Frame.indexText = fIndexText

	local fNextButton = CreateFrame("Button", nil, fContent, "UIPanelButtonTemplate")
	fNextButton:SetPoint("LEFT", fIndexText, "RIGHT", 2, 0)
	fNextButton:SetWidth(24)
	fNextButton:SetText(">")
	fNextButton:SetScript("OnClick", function(self)
		IBRaidLoot:GoToNextRollSummaryLoot()
	end)
	Frame.nextButton = fNextButton

	local fPlayerText = fContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	fPlayerText:SetPoint("TOPLEFT", 0, -40)
	fPlayerText:SetSize(170, 15)
	fPlayerText:SetJustifyH("LEFT")
	fPlayerText:SetText("Player")

	local fRollTypeText = fContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	fRollTypeText:SetPoint("LEFT", fPlayerText, "RIGHT", 0, 0)
	fRollTypeText:SetSize(100, 15)
	fRollTypeText:SetJustifyH("LEFT")
	fRollTypeText:SetText("Option")

	local fRollValueText = fContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	fRollValueText:SetPoint("LEFT", fRollTypeText, "RIGHT", 0, 0)
	fRollValueText:SetSize(40, 15)
	fRollValueText:SetJustifyH("LEFT")
	fRollValueText:SetText("Roll")

	StaticPopupDialogs["IBRaidLoot_RollSummary_Confirm"] = {
		text = "Are you sure you want to give this item to %s?",
		button1 = ACCEPT,
		button2 = CANCEL,
		OnAccept = function(self, data)
			IBRaidLoot:GiveMasterLootItem(data["rollObj"]["player"], data["lootObj"])
		end,
		OnCancel = function(_, reason)
		end,
		sound = "levelup2",
		timeout = 30,
		whileDead = true,
		hideOnEscape = true,
		showAlert = true
	}

	self:UpdateRollSummaryFrame()
	return Frame
end

function IBRaidLoot:UpdateRollSummaryFrameForLoot(uniqueLootID)
	if Frame == nil or not Frame:IsVisible() then
		return
	end

	local lootObj = self:GetCurrentRollSummaryLoot()
	if lootObj == nil then
		return
	end

	if lootObj["uniqueLootID"] == uniqueLootID then
		self:UpdateRollSummaryFrame()
	end
end

function IBRaidLoot:UpdateRollSummaryFrame()
	if Frame == nil or not Frame:IsVisible() then
		return
	end

	local lootObj = self:GetCurrentRollSummaryLoot()

	Frame.icon.icon:SetTexture(lootObj["texture"])
	Frame.icon:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT");
		GameTooltip:SetHyperlink(lootObj["link"])
	end)

	local r, g, b = GetItemQualityColor(lootObj["quality"])
	Frame.name:SetText(lootObj["name"])
	Frame.name:SetTextColor(r, g, b, 1)

	Frame.indexText:SetText(currentIndex.." / "..self:sizeof(currentLootIDs))

	Frame.prevButton:SetEnabled(currentIndex > 1)
	Frame.nextButton:SetEnabled(currentIndex < self:sizeof(currentLootIDs))

	self:UpdateRollSummaryRollsFrame()
end

function IBRaidLoot:CreateRollSummaryRollFrames()
	local lootObj = self:GetCurrentRollSummaryLoot()
	local rolls = self:GetSortedRolls(lootObj)
	table.foreach(rolls, function(_, rollObj)
		IBRaidLoot:CreateRollSummaryRollFrame(lootObj, rollObj)
	end)
end

function IBRaidLoot:CreateRollSummaryRollFrame(lootObj, rollObj)
	local i = LinesFrame.subframeCount + 1
	local f = LinesFrame.subframes[i]

	local HEIGHT = 18

	LinesFrame.subframeCount = LinesFrame.subframeCount + 1
	if f == nil then
		f = CreateFrame("Button", nil, LinesFrame)
		LinesFrame.subframes[i] = f
		f:SetWidth(LinesFrame:GetWidth())
		f:SetHeight(HEIGHT)
		f:SetPoint("TOPLEFT", 0, -HEIGHT * (i - 1))

		local fHighlight = f:CreateTexture(nil, "BACKGROUND")
		fHighlight:SetAllPoints(true)
		f.highlight = fHighlight

		local fPlayerText = f:CreateFontString(nil, "ARTWORK", "GameFontWhiteSmall")
		fPlayerText:SetPoint("TOPLEFT", 0, 0)
		fPlayerText:SetSize(170, 15)
		fPlayerText:SetJustifyH("LEFT")
		f.playerText = fPlayerText

		local fRollTypeIcon = f:CreateTexture(nil, "ARTWORK")
		fRollTypeIcon:SetSize(12, 12)
		fRollTypeIcon:SetPoint("LEFT", fPlayerText, "RIGHT", 0, 0)
		f.rollTypeIcon = fRollTypeIcon

		local fRollTypeText = f:CreateFontString(nil, "ARTWORK", "GameFontWhiteSmall")
		fRollTypeText:SetPoint("LEFT", fRollTypeIcon, "RIGHT", 0, 0)
		fRollTypeText:SetSize(100 - 12, 15)
		fRollTypeText:SetJustifyH("LEFT")
		f.rollTypeText = fRollTypeText

		local fRollValueText = f:CreateFontString(nil, "ARTWORK", "GameFontWhiteSmall")
		fRollValueText:SetPoint("LEFT", fRollTypeText, "RIGHT", 0, 0)
		fRollValueText:SetSize(40, 15)
		fRollValueText:SetJustifyH("LEFT")
		f.rollValueText = fRollValueText
	end

	if lootObj["player"] then
		if rollObj["player"] == lootObj["player"] then
			f.highlight:SetColorTexture(0, 1, 0, 0.35)
		else
			f.highlight:SetColorTexture(1, 1, 1, 0.2)
		end

		f:SetScript("OnEnter", nil)
		f:SetScript("OnLeave", nil)
		f.highlight:Show()

		f:SetScript("OnClick", nil)
	else
		f.highlight:SetColorTexture(1, 1, 0, 0.35)
		f.highlight:Hide()
		f:SetScript("OnEnter", function(self)
			self.highlight:Show()
		end)
		f:SetScript("OnLeave", function(self)
			self.highlight:Hide()
		end)

		f:SetScript("OnClick", function(self, button)
			if IBRaidLoot:IsMasterLooter() then
				local dialog = StaticPopup_Show("IBRaidLoot_RollSummary_Confirm", rollObj["player"])
				if dialog then
					local data = {}
					data["rollObj"] = rollObj
					data["lootObj"] = lootObj
					dialog.data = data
				end
			end
		end)
	end

	f.playerText:SetText(string.gsub(rollObj["player"], "%-"..GetRealmName(), ""))
	f.rollTypeIcon:SetTexture(RollTypes[rollObj["type"]]["textureUp"])
	f.rollTypeText:SetText(rollObj["type"])
	if RollTypes[rollObj["type"]]["shouldRoll"] then
		f.rollValueText:SetText(rollObj["value"])
	else
		f.rollValueText:SetText("")
	end

	LinesFrame:SetHeight(HEIGHT * i)
	f:Show()
end

function IBRaidLoot:ClearRollSummaryRollFrames()
	for _, frame in pairs(LinesFrame.subframes) do
		frame:Hide()
	end
	LinesFrame.subframeCount = 0
end

function IBRaidLoot:UpdateRollSummaryRollsFrame()
	if Frame == nil or not Frame:IsVisible() then
		return
	end
	
	self:ClearRollSummaryRollFrames()
	self:CreateRollSummaryRollFrames()
end

function IBRaidLoot:GetCurrentRollSummaryLoot()
	return currentLoot[currentLootIDs[currentIndex]]
end

function IBRaidLoot:GoToPrevRollSummaryLoot()
	currentIndex = currentIndex - 1
	self:UpdateRollSummaryFrame()
end

function IBRaidLoot:GoToNextRollSummaryLoot()
	currentIndex = currentIndex + 1
	self:UpdateRollSummaryFrame()
end