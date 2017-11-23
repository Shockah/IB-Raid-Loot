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

	frame.nameLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.nameLabel:SetJustifyH("LEFT")

	frame.rollButtons = {}
	for _, rollType in pairs(Addon.orderedRollTypes) do
		local rollButton = CreateFrame("Button", nil, frame)
		rollButton:SetSize(20, 20)
		rollButton.rollType = rollType

		rollButton.icon = rollButton:CreateTexture(nil, "ARTWORK")
		rollButton.icon:SetAllPoints(true)
		rollButton.icon:SetTexture(rollType.icon)

		table.insert(frame.rollButtons, rollButton)
	end

	table.insert(instances, frame)
	return frame
end

local function SetupFrame(frame)
	local defaultButtonSize = 37

	frame:SetHeight(Addon.DB.Settings.Raider.PendingFrame.Cell.Height)

	frame.nameLabel:ClearAllPoints()
	frame.nameLabel:SetPoint("LEFT", frame.icon, "RIGHT", 8, frame:GetHeight() / 6)
	frame.nameLabel:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	
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

		local index = 1
		for _, rollButton in pairs(self.rollButtons) do
			if S:ContainsMatching(availableRollTypes, function(rollType)
				return rollType == rollButton.rollType.type
			end) then
				rollButton.icon:SetTexture(rollButton.rollType.icon)
				rollButton:SetScript("OnEnter", function(self)
					if not self.isMouseDown then
						self.icon:SetTexture(self.rollType.icon.."-Hover")
					end
					GameTooltip:SetOwner(self, "ANCHOR_LEFT")
					GameTooltip:ClearLines()
					rollButton.rollType:AddToTooltip({})
					GameTooltip:Show()
				end)
				rollButton:SetScript("OnLeave", function(self)
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
					-- TODO: send roll
				end)

				rollButton:ClearAllPoints()
				rollButton:SetPoint("LEFT", self.icon, "RIGHT", 8 + (index - 1) * 24, -self:GetHeight() / 6)
				rollButton:Show()

				index = index + 1
			else
				rollButton:Hide()
			end
		end
	end)
end