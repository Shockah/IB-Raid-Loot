--[[
	Loot

	Properties:
	* lootID: string -- unique loot ID
	* link: string -- item link
	* quantity: int
	* isNew: bool -- whether this Loot object is still being processed for the first time
	* rolls: table -- list of rolls
	* startTime: int -- time the rolling started at
	* timeout: int -- startTime + timeout to end at
]]

local selfAddonName = "Linnet"
local Self = _G[selfAddonName]
local SelfDB = _G[selfAddonName.."DB"]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}

function Self:NewLoot(lootID, link, quantity, isNew)
	local obj = S:Clone(prototype)
	obj.lootID = lootID
	obj.link = link
	obj.quantity = quantity or 1
	obj.isNew = (isNew == nil and true or isNew)
	obj.rolls = {}
	return obj
end

function prototype:SetTimeout(timeout)
	if timeout then
		self.startTime = GetTime()
		self.timeout = timeout
	else
		self.startTime = nil
		self.timeout = nil
	end
end

function prototype:AddToHistory(lootHistory, timeout)
	self:SetTimeout(timeout or SelfDB.RollTimeout)
	table.insert(lootHistory.loot, self)
end