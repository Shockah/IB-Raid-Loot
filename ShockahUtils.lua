local MAJOR, MINOR = "ShockahUtils", 1
local Self = LibStub:NewLibrary(MAJOR, MINOR)

if not Self then
	return
end

------------------------------
-- debug
------------------------------

function Self:Dump(prefix, message)
	if message == nil then
		print(prefix..": nil")
	elseif type(message) == "table" then
		print(prefix..":")
		self:DumpTable(message, 1)
	else
		print(prefix..": "..tostring(message))
	end
end

function Self:DumpTable(tbl, indent)
	indent = indent or 0
	for k, v in pairs(tbl) do
		formatting = string.rep("  ", indent)..k..": "
		if type(v) == "table" then
			print(formatting)
			self:DumpTable(v, indent + 1)
		elseif type(v) == "boolean" then
			print(formatting..tostring(v))
		elseif type(v) == "function" then
			print(formatting.."function")
		elseif type(v) == "userdata" then
			print(formatting.."userdata")
		else
			print(formatting..v)
		end
	end
end

------------------------------
-- tables
------------------------------

function Self:Clone(prototype)
	return self:CloneInto(prototype, {})
end

function Self:CloneInto(prototype, tbl)
	for k, v in pairs(prototype) do
		tbl[k] = v
	end
	return tbl
end

function Self:Clear(tbl)
	for k in pairs(tbl) do
		tbl[k] = nil
	end
end

function Self:IsEmpty(tbl)
	return next(tbl) == nil
end

function Self:Count(tbl)
	local count = 0
	for _, _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

function Self:KeyOf(tbl, value)
	for k, v in pairs(tbl) do
		if v == value then
			return k
		end
	end
	return nil
end

function Self:Contains(tbl, value)
	return self:KeyOf(tbl, value) ~= nil
end

function Self:ContainsMatching(tbl, filterFunction)
	for _, v in pairs(tbl) do
		if filterFunction(v) then
			return true
		end
	end
	return false
end

function Self:Slice(tbl, firstIndex, length, preserveIndexes)
	preserveIndexes = preserveIndexes or false
	local result = {}
	local lastIndex = firstIndex + length - 1

	if preserveIndexes then
		for i = firstIndex, lastIndex do
			result[i] = tbl[i]
		end
	else
		for i = firstIndex, lastIndex do
			table.insert(result, tbl[i])
		end
	end

	return result
end

function Self:Filter(tbl, filterFunction)
	local result = {}
	for _, v in pairs(tbl) do
		if filterFunction(v) then
			table.insert(result, v)
		end
	end
	return result
end

function Self:FilterFirst(tbl, filterFunction)
	for _, v in pairs(tbl) do
		if filterFunction(v) then
			return v
		end
	end
	return nil
end

function Self:Map(tbl, mapFunction)
	local result = {}
	for _, v in pairs(tbl) do
		table.insert(result, mapFunction(v))
	end
	return result
end

------------------------------
-- items
------------------------------

function Self:ParseItemLink(link)
	local linkParts = { string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?") }
	return {
		itemString = string.match(link, "item[%-?%d:]+"),
		color = linkParts[3],
		linkType = linkParts[4],
		ID = linkParts[5],
		enchant = linkParts[6],
		gems = {
			linkParts[7],
			linkParts[8],
			linkParts[9],
			linkParts[10],
		},
		suffix = linkParts[11],
		unique = linkParts[12],
		linkLevel = linkParts[13],
		reforging = linkParts[14],
		name = linkParts[15],
	}
end

------------------------------
-- players
------------------------------

function Self:GetPlayerNameWithRealm(player)
	player = player or GetUnitName("player", true)
	return string.find(player, "-") and player or player.."-"..GetRealmName()
end

function Self:GetPlayerNameWithOptionalRealm(player)
	player = player or GetUnitName("player", true)
	return string.gsub(player, "%-"..GetRealmName(), "")
end

------------------------------
-- chatbox
------------------------------

function Self:FindActiveChatEditbox()
	for i = 1, 10 do
		local frame = _G["ChatFrame"..i.."EditBox"]
		if frame and frame:IsVisible() then
			return frame
		end
	end
	return nil
end

function Self:InsertInChatEditbox(text)
	local chatEditbox = self:FindActiveChatEditbox()
	if chatEditbox then
		chatEditbox:Insert(text)
	end
end