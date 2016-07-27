IBRaidLoot = LibStub("AceAddon-3.0"):NewAddon("IBRaidLoot", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceBucket-3.0", "AceTimer-3.0")

IBRaidLootSettings = {}
IBRaidLootSettings["DEBUG"] = true
IBRaidLootSettings["DEBUG_MODE"] = true

IBRaidLootData = {}
IBRaidLootData["currentLootIDs"] = {}
IBRaidLootData["currentLoot"] = {}
IBRaidLootData["RollTypes"] = {}
IBRaidLootData["RollTypeList"] = {}

local currentLootIDs = IBRaidLootData["currentLootIDs"]
local currentLoot = IBRaidLootData["currentLoot"]
local RollTypes = IBRaidLootData["RollTypes"]
local RollTypeList = IBRaidLootData["RollTypeList"]

local RollType = nil

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

-- comm
local AceCommPrefix = "IBRaidLoot"
local nextCommMessageID = 1
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

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
		self:CreatePendingRollsFrame()
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

		self:CreatePendingRollsFrame()
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
-- debug-mode-aware functions
-------

function IBRaidLoot:GetLootThreshold()
	if IBRaidLootSettings["DEBUG_MODE"] then
		return 0
	end

	return GetLootThreshold()
end

function IBRaidLoot:IsMasterLooter()
	if IBRaidLootSettings["DEBUG_MODE"] then
		return true
	end

	return self:IsMasterLooter_Real()
end

function IBRaidLoot:GetLootEligiblePlayers(lootObj, player)
	if IBRaidLootSettings["DEBUG_MODE"] then
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
	if IBRaidLootSettings["DEBUG"] then
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