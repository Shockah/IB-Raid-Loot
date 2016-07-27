local Frame = nil
local ItemIcon = nil
local ItemName = nil
local PrevButton = nil
local NextButton = nil
local IndexText = nil
local LinesFrame = nil
local LineFrames = 0
local currentIndex = 1

local currentLootIDs = IBRaidLootData["currentLootIDs"]
local currentLoot = IBRaidLootData["currentLoot"]
local RollTypes = IBRaidLootData["RollTypes"]
local RollTypeList = IBRaidLootData["RollTypeList"]

function IBRaidLoot:CreateRollSummaryFrame()
	if Frame ~= nil then
		self:UpdateRollSummaryFrame()
		Frame:Show()
		return Frame
	end

	Frame = CreateFrame("Frame", "IBRaidLoot_RollSummaryFrame", UIParent)
	Frame:SetMovable(true)
	Frame:SetUserPlaced(true)
	Frame:SetFrameStrata("HIGH")
	Frame:SetWidth(350)
	Frame:SetHeight(400)
	Frame:SetPoint("CENTER", 0, 0)
	Frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 8, right = 8, top = 8, bottom = 8 }
	})
	Frame:SetBackdropColor(0, 0, 0, 1)
	Frame:Show()
	table.insert(UISpecialFrames, "IBRaidLoot_RollSummaryFrame")

	self:SetupWindowFrame(Frame, "Roll Summary")

	ItemIcon = CreateFrame("Button", nil, Frame, "ItemButtonTemplate")
	ItemIcon:SetWidth(32)
	ItemIcon:SetHeight(32)
	ItemIcon.icon:SetWidth(32)
	ItemIcon.icon:SetHeight(32)
	ItemIcon:SetPoint("TOPLEFT", 18, -36)
	ItemIcon:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	ItemIcon:RegisterForClicks("RightButtonDown")

	ItemName = Frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	ItemName:SetPoint("LEFT", ItemIcon, "RIGHT", 6, 0)
	ItemName:SetWidth(Frame:GetWidth() - 18 * 2 - ItemIcon:GetWidth() - 12 - 96 - 4)
	ItemName:SetJustifyH("LEFT")

	PrevButton = CreateFrame("Button", nil, Frame, "UIPanelButtonTemplate")
	PrevButton:SetPoint("LEFT", ItemName, "RIGHT", 6, 0)
	PrevButton:SetWidth(24)
	PrevButton:SetText("<")
	PrevButton:SetScript("OnClick", function(self)
		IBRaidLoot:GoToPrevRollSummaryLoot()
	end)

	IndexText = Frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	IndexText:SetPoint("LEFT", PrevButton, "RIGHT", 2, 0)
	IndexText:SetWidth(48)
	IndexText:SetJustifyH("CENTER")

	NextButton = CreateFrame("Button", "IBRaidLoot_RollSummaryNextItemButton", Frame, "UIPanelButtonTemplate")
	NextButton:SetPoint("LEFT", IndexText, "RIGHT", 2, 0)
	NextButton:SetWidth(24)
	NextButton:SetText(">")
	NextButton:SetScript("OnClick", function(self)
		IBRaidLoot:GoToNextRollSummaryLoot()
	end)

	local fPlayerText = Frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	fPlayerText:SetPoint("TOPLEFT", 18, -24 - 64 + 16)
	fPlayerText:SetSize(170, 15)
	fPlayerText:SetJustifyH("LEFT")
	fPlayerText:SetText("Player")

	local fRollTypeText = Frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	fRollTypeText:SetPoint("LEFT", fPlayerText, "RIGHT", 0, 0)
	fRollTypeText:SetSize(80, 15)
	fRollTypeText:SetJustifyH("LEFT")
	fRollTypeText:SetText("Option")

	local fRollValueText = Frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	fRollValueText:SetPoint("LEFT", fRollTypeText, "RIGHT", 0, 0)
	fRollValueText:SetSize(40, 15)
	fRollValueText:SetJustifyH("LEFT")
	fRollValueText:SetText("Roll")

	local fScroll = CreateFrame("ScrollFrame", "IBRaidLoot_RollSummaryScrollFrame", Frame, "UIPanelScrollFrameTemplate")
	fScroll:SetWidth(fScroll:GetParent():GetWidth() - 24 - 24)
	fScroll:SetHeight(fScroll:GetParent():GetHeight() - 36 - 64)
	fScroll:SetPoint("TOPLEFT", 12, -24 - 64)
	fScroll:Show()

	LinesFrame = CreateFrame("Frame", "IBRaidLoot_RollSummaryContentFrame", nil, nil);
	LinesFrame:SetWidth(fScroll:GetWidth())
	LinesFrame:SetHeight(60)
	LinesFrame:SetBackdrop({
		bgFile = "",
		edgeFile = "",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 1, right = 1, top = 1, bottom = 1}
	})
	fScroll:SetScrollChild(LinesFrame)
	LinesFrame:Show()

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

	ItemIcon.icon:SetTexture(lootObj["texture"])
	ItemIcon:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT");
		GameTooltip:SetHyperlink(lootObj["link"])
	end)

	local r, g, b = GetItemQualityColor(lootObj["quality"])
	ItemName:SetText(lootObj["name"])
	ItemName:SetTextColor(r, g, b, 1)

	IndexText:SetText(currentIndex.." / "..self:sizeof(currentLootIDs))

	PrevButton:SetEnabled(currentIndex > 1)
	NextButton:SetEnabled(currentIndex < self:sizeof(currentLootIDs))

	self:UpdateRollSummaryRollsFrame()
end

function IBRaidLoot:CreateRollSummaryRollFrames()
	local lootObj = self:GetCurrentRollSummaryLoot()
	local rolls = self:GetSortedRolls(lootObj)
	table.foreach(rolls, function(_, rollObj)
		IBRaidLoot:CreateRollSummaryRollFrame(rollObj)
	end)
end

function IBRaidLoot:CreateRollSummaryRollFrame(rollObj)
	local i = LineFrames + 1
	local f = _G["IBRaidLoot_RollSummaryRollFrame"..i]
	local fPlayerText = nil
	local fRollTypeText = nil
	local fRollValueText = nil

	LineFrames = LineFrames + 1
	if f == nil then
		f = CreateFrame("Frame", "IBRaidLoot_RollSummaryRollFrame"..i, LinesFrame, nil)
		f:SetWidth(LinesFrame:GetWidth())
		f:SetHeight(18)
		f:SetPoint("TOPLEFT", 0, -18 * (i - 1))

		fPlayerText = f:CreateFontString("IBRaidLoot_RollSummaryRollFramePlayerText"..i, "ARTWORK", "GameFontWhiteSmall")
		fPlayerText:SetPoint("TOPLEFT", 6, 0)
		fPlayerText:SetSize(170, 15)
		fPlayerText:SetJustifyH("LEFT")

		fRollTypeText = f:CreateFontString("IBRaidLoot_RollSummaryRollFrameRollTypeText"..i, "ARTWORK", "GameFontWhiteSmall")
		fRollTypeText:SetPoint("LEFT", fPlayerText, "RIGHT", 0, 0)
		fRollTypeText:SetSize(80, 15)
		fRollTypeText:SetJustifyH("LEFT")

		fRollValueText = f:CreateFontString("IBRaidLoot_RollSummaryRollFrameRollValueText"..i, "ARTWORK", "GameFontWhiteSmall")
		fRollValueText:SetPoint("LEFT", fRollTypeText, "RIGHT", 0, 0)
		fRollValueText:SetSize(40, 15)
		fRollValueText:SetJustifyH("LEFT")
	else
		fIcon = _G["IBRaidLoot_PendingRollsItemIcon"..i]
		fName = _G["IBRaidLoot_PendingRollsItemName"..i]
		fPlayerText = _G["IBRaidLoot_RollSummaryRollFramePlayerText"..i]
		fRollTypeText = _G["IBRaidLoot_RollSummaryRollFrameRollTypeText"..i]
		fRollValueText = _G["IBRaidLoot_RollSummaryRollFrameRollValueText"..i]
	end

	fPlayerText:SetText(rollObj["player"])
	fRollTypeText:SetText(rollObj["type"])
	if RollTypes[rollObj["type"]]["shouldRoll"] then
		fRollValueText:SetText(rollObj["value"])
	else
		fRollValueText:SetText("")
	end

	LinesFrame:SetHeight(18 * i)
	f:Show()
	
	return f
end

function IBRaidLoot:ClearRollSummaryRollFrames()
	for i = 1, LineFrames do
		local f = _G["IBRaidLoot_RollSummaryRollFrame"..i]
		if f ~= nil then
			f:Hide()
		end
	end
	LineFrames = 0
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