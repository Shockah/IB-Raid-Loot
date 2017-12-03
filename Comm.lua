local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

Addon.Comm = {
	handlers = {},
}
local Class = Addon.Comm

function Class:SendCompressedCommMessage(type, obj, distribution, target)
	local message = {}
	message.Type = type
	message.Body = obj

	local one = libS:Serialize(message)
	local two = libC:CompressHuffman(one)
	local final = libCE:Encode(two)

	Addon:SendCommMessage(Addon.Settings.AceCommPrefix, final, distribution, target, "NORMAL")
end

function Class:OnDecompressedCommReceived(type, obj, distribution, sender)
	local handler = self.handlers[type]
	if handler then
		handler:Handle(obj, distribution, sender)
	end
end

function Addon:OnCommReceived(prefix, data, distribution, sender)
	local one = libCE:Decode(data)
	sender = S:GetPlayerNameWithRealm(sender)

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

	if sender == S:GetPlayerNameWithRealm() then
		return
	end
	Class:OnDecompressedCommReceived(final.Type, final.Body, distribution, sender)
end