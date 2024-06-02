local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local allFiles = SharedTableRegistry:GetSharedTable("SaveFiles")
local dataSettings = require(ServerScriptService.SaveDataLoader.Settings)

local keyFormat = dataSettings.KeyFormat:gsub("%%s", "(%%d+)")

local sharedTable_find = function(sharedTable, toFind)
	for i, v in sharedTable do
		if v == toFind then
			return i
		end
	end
end

return function(file)
	local raw = nil

	local fileType = typeof(file)
	if fileType == "SharedTable" then
		raw = file
	else
		raw = file._RAW
	end

	if raw then
		local id = sharedTable_find(allFiles, raw)
		if id then
			local key = string.split(id, "/")[3]
			local userId = key:match(keyFormat)
			if userId then
				local numberId = tonumber(userId)
				if numberId then
					local player = Players:GetPlayerByUserId(numberId)
					if player then
						return player
					else
						return numberId
					end
				end
			end
		end
	end
end