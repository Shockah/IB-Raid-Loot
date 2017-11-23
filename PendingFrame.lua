local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.PendingFrame = {}
local Class = Addon.PendingFrame

local function SetupFrame(frame)
	frame:SetFrameStrata(Addon.DB.Settings.Raider.PendingFrame.Strata)
	frame:SetSize(unpack(Addon.DB.Settings.Raider.PendingFrame.Size))
end

function Class:Get()
	if self.frame then
		SetupFrame(self.frame)
		return self.frame
	end

	local frame = CreateFrame("Frame", selfAddonName.."PendingFrame", UIParent, "BasicFrameTemplateWithInset")
	frame = S:CloneInto(prototype, frame)
	frame.itemFrames = {}

	local point = Addon.DB.Settings.Raider.PendingFrame.Point
	if point.relativeTo then
		point.relativeTo = _G[point.relativeTo]
	end

	frame:SetPoint(point.point, point.relativeTo, point.relativePoint, point.xOffset, point.yOffset)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, relativeTo, relativePoint, xOffset, yOffset = self:GetPoint(1)
		Addon.DB.Settings.Raider.PendingFrame.Point = {
			point = point,
			relativeTo = relativeTo and relativeTo:GetName() or nil,
			relativePoint = relativePoint,
			xOffset = xOffset,
			yOffset = yOffset,
		}
	end)

	frame.resizeButton = CreateFrame("Button", "BarGroupResizeButton", frame)
	frame.resizeButton:SetSize(16, 16)
	frame.resizeButton:EnableMouse(true)
	frame.resizeButton:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			local parent = self:GetParent()
			parent.isResizing = true
			parent:StartSizing("BOTTOMRIGHT")
			parent:SetScript("OnUpdate", function()
				if parent.isResizing then
					-- TODO: resize inner frames
				else
					parent:SetScript("OnUpdate", nil)
				end
			end)
		end
	end)
	frame.resizeButton:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			local parent = self:GetParent()
			if parent.isResizing then
				parent:StopMovingOrSizing()
				parent.isResizing = false
				Addon.DB.Settings.Raider.PendingFrame.Size = { parent:GetWidth(), parent:GetHeight() }
			end
		end
	end)
	frame.resizeButton:SetNormalTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Up")
	frame.resizeButton:SetHighlightTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Down")
	frame.resizeButton:ClearAllPoints()
	frame.resizeButton:GetNormalTexture():SetRotation(0)
	frame.resizeButton:GetHighlightTexture():SetRotation(0)
	frame.resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	--frame.resizeButton:Show()

	frame.titleLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.titleLabel:SetPoint("TOP", 0, -4)
	frame.titleLabel:SetText("Pending Rolls")
	frame.titleLabel:SetJustifyV("TOP")

	frame.itemScrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	frame.itemScrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4 - 24)
	frame.itemScrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4 - 24, 4)
	frame.itemScrollFrame:SetScript("OnUpdate", function(self)
		frame.itemContainer:SetWidth(self:GetWidth())
	end)

	frame.itemContainer = CreateFrame("Frame", nil, frame.itemScrollFrame)
	frame.itemScrollFrame:SetScrollChild(frame.itemContainer)

	table.insert(UISpecialFrames, frame:GetName())

	self.frame = frame
	SetupFrame(self.frame)
	return self.frame
end

function prototype:SetLoot(loot)
	self.loot = loot

	for _, itemFrame in pairs(self.itemFrames) do
		itemFrame:Free()
	end
	S:Clear(self.itemFrames)
	
	local cellHeight = Addon.DB.Settings.Raider.PendingFrame.Cell.Height
	local cellSpacing = Addon.DB.Settings.Raider.PendingFrame.Cell.Spacing

	local index = 1
	for _, lootObj in pairs(loot) do
		local itemFrame = Addon.PendingLootFrame:Get(self.itemContainer)
		table.insert(self.itemFrames, itemFrame)

		local yOffset = -(index - 1) * (cellHeight + cellSpacing)
		itemFrame:SetPoint("TOPLEFT", self.itemContainer, "TOPLEFT", 0, yOffset)
		itemFrame:SetPoint("TOPRIGHT", self.itemContainer, "TOPRIGHT", 0, yOffset)

		itemFrame:SetLoot(lootObj)

		index = index + 1
	end

	self.itemContainer:SetHeight(cellHeight * S:Count(loot) + cellSpacing * (S:Count(loot) - 1))
end