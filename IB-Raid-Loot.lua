-- settings
local DEBUG = true
local DEBUG_MODE = true

local RollType = nil
local RollTypes = {}
local RollTypeList = {}

RollType = {}
RollType["order"] = 0
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Major-Up]]
RollType["textureDown"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Major-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Major-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Major"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 1
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Minor-Up]]
RollType["textureDown"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Minor-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Minor-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Minor"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 2
RollType["button"] = true
RollType["textureUp"] = [[Interface\Buttons\UI-GroupLoot-Dice-Up]]
RollType["textureDown"] = [[Interface\Buttons\UI-GroupLoot-Dice-Down]]
RollType["textureHighlight"] = [[Interface\Buttons\UI-GroupLoot-Dice-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Off-spec"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 3
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Transmog-Up]]
RollType["textureDown"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Transmog-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Transmog-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Transmog"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 4
RollType["button"] = true
RollType["textureUp"] = [[Interface\Buttons\UI-GroupLoot-Pass-Up]]
RollType["textureDown"] = [[Interface\Buttons\UI-GroupLoot-Pass-Down]]
RollType["textureHighlight"] = [[Interface\Buttons\UI-GroupLoot-Pass-Highlight]]
RollType["shouldRoll"] = false
RollType["type"] = "Pass"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 100
RollType["button"] = false
RollType["textureUp"] = [[Interface\AddOns\IB-Raid-Loot\Textures\Roll-Pending-Up]]
RollType["shouldRoll"] = false
RollType["type"] = "Pending"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

IBRaidLoot = LibStub("AceAddon-3.0"):NewAddon("IBRaidLoot", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceBucket-3.0", "AceTimer-3.0")

-- comm
local AceCommPrefix = "IBRaidLoot"
local nextCommMessageID = 1
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

-- data
local currentLootIDs = {} -- List<UniqueLootID>
local currentLoot = {} -- Map<UniqueLootID, LootObj>

-- frames
local RollFrame = nil
local RollItemsFrame = nil
local RollItemFrames = 0

-------
-- event handlers
-------

function IBRaidLoot:OnInitialize()
	self:RegisterBucketEvent("LOOT_READY", 0.25, "OnLootOpened")
	self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")

	self:RegisterComm(AceCommPrefix)

	self:RegisterChatCommand("ibrl", "OnSlashCommand");
	self:RegisterChatCommand("ibloot", "OnSlashCommand");
end

function IBRaidLoot:OnDisable()
	self:UnregisterAllEvents()
end

function IBRaidLoot:OnSlashCommand(input)
end

function IBRaidLoot:OnLootOpened()
	if not self:IsMasterLooter() then
		return
	end

	local newLoot = {}

	local numLootItems = GetNumLootItems()
	local threshold = self:GetLootThreshold()
	for i = 1, numLootItems do
		local texture, item, quantity, quality, locked = GetLootSlotInfo(i)
		local lootSlotType = GetLootSlotType(i)

		if not locked and lootSlotType == 1 and quality >= threshold and quantity == 1 then
			local link = GetLootSlotLink(i)
			local corpseGUID = GetLootSourceInfo(i)
			local uniqueLootID = self:GetUniqueLootID(link, corpseGUID)

			if corpseGUID then
				if currentLoot[uniqueLootID] == nil then
					local lootObj = {}
					lootObj["link"] = link
					lootObj["corpseGUID"] = corpseGUID
					lootObj["quality"] = quality
					lootObj["texture"] = texture
					lootObj["name"] = item
					lootObj["uniqueLootID"] = uniqueLootID

					local rolls = {}
					table.foreach(self:GetLootEligiblePlayers(), function(_, player)
						local rollObj = {}
						rollObj["player"] = player
						rollObj["uniqueLootID"] = uniqueLootID
						rollObj["type"] = "Pending"
						rollObj["value"] = 0
						rolls[player] = rollObj
					end)
					lootObj["rolls"] = rolls

					table.insert(currentLootIDs, uniqueLootID)
					currentLoot[uniqueLootID] = lootObj
					table.insert(newLoot, lootObj)
				end
			end
		end
	end

	if next(newLoot) ~= nil then
		self:CreateLootFrame()
		self:CommMessage("RollsRequest", newLoot, "RAID")
	end
end

function IBRaidLoot:OnLootClosed()
end

function IBRaidLoot:OnCommReceived(prefix, data, distribution, sender)
	local one = libCE:Decode(data)

	local two, message = libC:Decompress(one)
	if not two then
		self:DebugPrint("OnCommReceived: Error decompressing: "..message)
		return
	end

	local success, final = libS:Deserialize(two)
	if not success then
		self:DebugPrint("OnCommReceived: Error deserializing: "..final)
		return
	end

	if sender == GetUnitName("player") then
		return
	end
	self:OnCommMessage(final["Type"], final["Body"], distribution, sender)
end

function IBRaidLoot:OnCommMessage(type, obj, distribution, sender)
	if type == "RollsRequest" then
		for _, lootObj in pairs(obj) do
			local uniqueLootID = lootObj["uniqueLootID"]
			if currentLoot[uniqueLootID] == nil then
				table.insert(currentLootIDs, uniqueLootID)
				currentLoot[uniqueLootID] = lootObj
			end
		end

		self:CreateLootFrame()
	elseif type == "Roll" then
		obj["player"] = sender
		self:OnRollReceived(obj)
	elseif type == "RollResponse" then
		self:OnRollResponseReceived(obj)
	end
end

function IBRaidLoot:OnRollReceived(rollObj)
	local uniqueLootID = rollObj["uniqueLootID"]
	local lootObj = currentLoot[uniqueLootID]
	if lootObj == nil then
		self:DebugPrint("Received roll for loot "..uniqueLootID..", but there is no info on this item.")
		return
	end

	if self:IsMasterLooter() then
		if RollTypes[rollObj["type"]]["shouldRoll"] then
			rollObj["value"] = random(100)
			self:SendCommMessage("RollResponse", rollObj, "RAID")
		end
	end

	lootObj["rolls"][rollObj["player"]] = rollObj
	self:UpdateLootFrame()
end

function IBRaidLoot:OnRollResponseReceived(rollObj)
	local uniqueLootID = rollObj["uniqueLootID"]
	local lootObj = currentLoot[uniqueLootID]
	if lootObj == nil then
		self:DebugPrint("Received roll response for loot "..uniqueLootID..", but there is no info on this item.")
		return
	end

	lootObj["rolls"][rollObj["player"]] = rollObj
	self:UpdateLootFrame()
end

-------
-- UI functions
-------

function IBRaidLoot:CreateLootFrame()
	if RollFrame ~= nil then
		self:UpdateLootFrame()
		RollFrame:Show()
		return RollFrame
	end

	RollFrame = CreateFrame("Frame", "IBRaidLootFrame", UIParent)
	RollFrame:SetFrameStrata("HIGH")
	RollFrame:SetWidth(600)
	RollFrame:SetHeight(400)
	RollFrame:SetPoint("CENTER", 0, 0)
	RollFrame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 8, right = 8, top = 8, bottom = 8 }
	})
	RollFrame:SetBackdropColor(0, 0, 0, 1)
	RollFrame:SetMovable(true)
	RollFrame:Show()
	table.insert(UISpecialFrames, "IBRaidLootFrame")

	self:SetupWindowFrame(RollFrame, "IB Raid Loot - Pending")

	local fScroll = CreateFrame("ScrollFrame", "IBRaidLootScrollFrame", RollFrame, "UIPanelScrollFrameTemplate")
	fScroll:SetWidth(fScroll:GetParent():GetWidth() - 24 - 24)
	fScroll:SetHeight(fScroll:GetParent():GetHeight() - 36)
	fScroll:SetPoint("TOPLEFT", 12, -24)
	fScroll:Show()

	RollItemsFrame = CreateFrame("Frame", "IBRaidLootScrollContentFrame", nil, nil);
	RollItemsFrame:SetWidth(fScroll:GetWidth())
	RollItemsFrame:SetHeight(60)
	RollItemsFrame:SetBackdrop({
		bgFile = "",
		edgeFile = "",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 1, right = 1, top = 1, bottom = 1}
	})
	fScroll:SetScrollChild(RollItemsFrame)
	RollItemsFrame:Show()

	self:CreateLootItemFrames()
	return RollFrame
end

function IBRaidLoot:CreateLootItemFrames(closeIfNoItems)
	local hasItems = false
	for _, uniqueLootID in pairs(currentLootIDs) do
		local lootObj = currentLoot[uniqueLootID]
		if not self:DidRollOnItem(lootObj) then
			self:CreateLootItemFrame(lootObj)
			hasItems = true
		end
	end
	if not hasItems and closeIfNoItems then
		RollFrame:Hide()
	end
end

function IBRaidLoot:CreateLootItemFrame(lootObj)
	local i = RollItemFrames + 1
	local f = _G["IBRollItemFrame"..i]
	local fIcon = nil
	local fName = nil

	RollItemFrames = RollItemFrames + 1
	if f == nil then
		f = CreateFrame("Frame", "IBRollItemFrame"..i, RollItemsFrame, nil)
		f:SetWidth(RollItemsFrame:GetWidth())
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

		fIcon = CreateFrame("Button", "IBRollItemIcon"..i, f, "ItemButtonTemplate")
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
				local fButton = CreateFrame("Button", "IBRollItem_Button_"..obj["type"]..i, f, nil)
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

		fName = fIcon:CreateFontString("IBRollItemNameText"..i, "ARTWORK", "GameFontNormal")
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
			local fRolls = CreateFrame("Button", "IBRollItem_Rolls_"..obj["type"]..i, f, nil)
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

			local fRollsText = fIcon:CreateFontString("IBRollItem_RollsText_"..obj["type"]..i, "ARTWORK", "GameFontNormal")
			fRollsText:SetPoint("LEFT", fRollsIcon, "RIGHT", ROLL_ICON_TEXT_MARGIN, 0)
			fRollsText:SetWidth(ROLL_TEXT_SIZE)
			fRollsText:SetJustifyH("LEFT")
			fRolls.text = fRollsText

			xx = xx + 1
		end)
	else
		fIcon = _G["IBRollItemIcon"..i]
		fName = _G["IBRollItemNameText"..i]
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
			local fButton = _G["IBRollItem_Button_"..obj["type"]..i]
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
				IBRaidLoot:UpdateLootFrame(true)
			end)
			fButton:Show()
		end
	end)

	table.foreach(RollTypeList, function(_, obj)
		local fRolls = _G["IBRollItem_Rolls_"..obj["type"]..i]
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

	RollItemsFrame:SetHeight(60 * i)
	f:Show()
	
	return f
end

function IBRaidLoot:ClearLootItemFrames()
	for i = 1, RollItemFrames do
		local f = _G["IBRollItemFrame"..i]
		if f ~= nil then
			f:Hide()
		end
	end
	RollItemFrames = 0
end

function IBRaidLoot:UpdateLootFrame(closeIfNoItems)
	if RollItemsFrame == nil then
		return
	end
	
	self:ClearLootItemFrames()
	self:CreateLootItemFrames(closeIfNoItems)
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

-------
-- debug-mode-aware functions
-------

function IBRaidLoot:GetLootThreshold()
	if DEBUG_MODE then
		return 0
	end

	return GetLootThreshold()
end

function IBRaidLoot:IsMasterLooter()
	if DEBUG_MODE then
		return true
	end

	return self:IsMasterLooter_Real()
end

function IBRaidLoot:GetLootEligiblePlayers(lootObj, player)
	if DEBUG_MODE then
		return { GetUnitName("player") }
	end

	local players = {}
	for i = 1, 40 do
		local player = GetMasterLootCandidate(i)
		if player ~= nil then
			table.insert(players, player)
		end
	end
	return players
end

-------
-- helper functions
-------

function IBRaidLoot:IsMasterLooter_Real()
	if not IsInRaid() then
		return false
	end

	local method, partyMaster, raidMaster = GetLootMethod()
	return method == "master" and partyMaster == 0
end

function IBRaidLoot:DidRollOnItem(lootObj)
	local rollObj = lootObj["rolls"][GetUnitName("player")]
	if rollObj == nil then
		return false
	end

	return rollObj["type"] ~= "Pending"
end

function IBRaidLoot:DidEveryoneRollOnItem(lootObj)
	for player, rollObj in pairs(lootObj["rolls"]) do
		if rollObj["type"] == "Pending" then
			return false
		end
	end

	return true
end

function IBRaidLoot:GetRollsOfType(lootObj, type)
	local rolls = {}
	for player, rollObj in pairs(lootObj["rolls"]) do
		if rollObj["type"] == type then
			table.insert(rolls, rollObj)
		end
	end
	return rolls
end

function IBRaidLoot:GetItemIDFromLink(link)
	return string.gsub(link, ".-\124H([^\124]*)\124h.*", "%1")
end

function IBRaidLoot:GetUniqueLootID(link, corpseGUID)
	return corpseGUID..":"..self:GetItemIDFromLink(link)
end

function IBRaidLoot:CommMessage(type, obj, distribution, target)
	local message = {}
	message["Type"] = type
	message["ID"] = nextCommMessageID
	message["Body"] = obj

	local one = libS:Serialize(message)
	local two = libC:CompressHuffman(one)
	local final = libCE:Encode(two)

	nextCommMessageID = nextCommMessageID + 1
	IBRaidLoot:SendCommMessage(AceCommPrefix, final, distribution, target, "NORMAL")
end

function IBRaidLoot:DebugPrint(message)
	if DEBUG then
		if type(message) == "table" then
			print("IBRaidLoot:")
			self:tprint(message, 1)
		else
			print("IBRaidLoot: "..tostring(message))
		end
	end
end

function IBRaidLoot:tprint(tbl, indent)
	if not indent then
		indent = 0
	end
	for k, v in pairs(tbl) do
		formatting = string.rep("  ", indent)..k..": "
		if type(v) == "table" then
			print(formatting)
			self:tprint(v, indent + 1)
		elseif type(v) == 'boolean' then
			print(formatting..tostring(v))      
		else
			print(formatting..v)
		end
	end
end

function IBRaidLoot:SetupWindowFrame(frame, titleText)
	local titlebg = frame:CreateTexture(nil, "BACKGROUND")
	titlebg:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Title-Background]])
	titlebg:SetPoint("TOPLEFT", 9, -6)
	titlebg:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -28, -24)
	
	local dialogbg = frame:CreateTexture(nil, "BACKGROUND")
	dialogbg:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])
	dialogbg:SetPoint("TOPLEFT", 8, -24)
	dialogbg:SetPoint("BOTTOMRIGHT", -6, 8)
	dialogbg:SetVertexColor(0, 0, 0, .75)
	
	local topleft = frame:CreateTexture(nil, "BORDER")
	topleft:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Border]])
	topleft:SetWidth(64)
	topleft:SetHeight(64)
	topleft:SetPoint("TOPLEFT")
	topleft:SetTexCoord(0.501953125, 0.625, 0, 1)
	
	local topright = frame:CreateTexture(nil, "BORDER")
	topright:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Border]])
	topright:SetWidth(64)
	topright:SetHeight(64)
	topright:SetPoint("TOPRIGHT")
	topright:SetTexCoord(0.625, 0.75, 0, 1)
	
	local top = frame:CreateTexture(nil, "BORDER")
	top:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Border]])
	top:SetHeight(64)
	top:SetPoint("TOPLEFT", topleft, "TOPRIGHT")
	top:SetPoint("TOPRIGHT", topright, "TOPLEFT")
	top:SetTexCoord(0.25, 0.369140625, 0, 1)
	
	local bottomleft = frame:CreateTexture(nil, "BORDER")
	bottomleft:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Border]])
	bottomleft:SetWidth(64)
	bottomleft:SetHeight(64)
	bottomleft:SetPoint("BOTTOMLEFT")
	bottomleft:SetTexCoord(0.751953125, 0.875, 0, 1)
	
	local bottomright = frame:CreateTexture(nil, "BORDER")
	bottomright:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Border]])
	bottomright:SetWidth(64)
	bottomright:SetHeight(64)
	bottomright:SetPoint("BOTTOMRIGHT")
	bottomright:SetTexCoord(0.875, 1, 0, 1)
	
	local bottom = frame:CreateTexture(nil, "BORDER")
	bottom:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Border]])
	bottom:SetHeight(64)
	bottom:SetPoint("BOTTOMLEFT", bottomleft, "BOTTOMRIGHT")
	bottom:SetPoint("BOTTOMRIGHT", bottomright, "BOTTOMLEFT")
	bottom:SetTexCoord(0.376953125, 0.498046875, 0, 1)
	
	local left = frame:CreateTexture(nil, "BORDER")
	left:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Border]])
	left:SetWidth(64)
	left:SetPoint("TOPLEFT", topleft, "BOTTOMLEFT")
	left:SetPoint("BOTTOMLEFT", bottomleft, "TOPLEFT")
	left:SetTexCoord(0.001953125, 0.125, 0, 1)
	
	local right = frame:CreateTexture(nil, "BORDER")
	right:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Border]])
	right:SetWidth(64)
	right:SetPoint("TOPRIGHT", topright, "BOTTOMRIGHT")
	right:SetPoint("BOTTOMRIGHT", bottomright, "TOPRIGHT")
	right:SetTexCoord(0.1171875, 0.2421875, 0, 1)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 1)
	close:SetScript("OnClick", function(self)
		PlaySound("gsTitleOptionExit")
		RollFrame:Hide()
	end)
	
	local titletext = frame:CreateFontString(nil, "ARTWORK")
	titletext:SetFontObject(GameFontNormal)
	titletext:SetPoint("TOPLEFT", 12, -8)
	titletext:SetPoint("TOPRIGHT", -32, -8)
	titletext:SetText(titleText)
	
	local title = CreateFrame("Button", nil, frame)
	title:SetPoint("TOPLEFT", titlebg)
	title:SetPoint("BOTTOMRIGHT", titlebg)
	title:EnableMouse()
	title:SetScript("OnMouseDown", function(self)
		self:GetParent():StartMoving()
	end)
	title:SetScript("OnMouseUp", function(self)
		self:GetParent():StopMovingOrSizing()
	end)
end