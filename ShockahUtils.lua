local MAJOR, MINOR = "ShockahUtils", 1
local ShockahUtils = LibStub:NewLibrary(MAJOR, MINOR)

if not ShockahUtils then
	return
end

------------------------------
-- debug
------------------------------

function ShockahUtils:Dump(prefix, message)
	if type(message) == "table" then
		print(prefix..":")
		self:DumpTable(message, 1)
	else
		print(prefix..": "..tostring(message))
	end
end

function ShockahUtils:DumpTable(table, indent)
	if not indent then
		indent = 0
	end
	for k, v in pairs(table) do
		formatting = string.rep("  ", indent)..k..": "
		if type(v) == "table" then
			print(formatting)
			self:Dump(v, indent + 1)
		elseif type(v) == 'boolean' then
			print(formatting..tostring(v))      
		else
			print(formatting..v)
		end
	end
end

------------------------------
-- tables
------------------------------

function ShockahUtils:Count(table)
	local count = 0
	for _, _ in pairs(table) do
		count = count + 1
	end
	return count
end

function ShockahUtils:KeyOf(table, value)
	for k, v in pairs(table) do
		if v == value then
			return k
		end
	end
	return nil
end

function ShockahUtils:Contains(table, value)
	return self:KeyOf(table, value) ~= nil
end

------------------------------
-- chatbox
------------------------------

function ShockahUtils:FindActiveChatEditbox()
	for i = 1, 10 do
		local frame = _G["ChatFrame"..i.."EditBox"]
		if frame:IsVisible() then
			return frame
		end
	end
	return nil
end

function ShockahUtils:InsertInChatEditbox(text)
	local chatEditbox = self:FindActiveChatEditbox()
	if chatEditbox then
		chatEditbox:Insert(text)
	end
end