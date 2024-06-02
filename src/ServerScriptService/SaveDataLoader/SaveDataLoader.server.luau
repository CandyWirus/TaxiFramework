local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local ServerStorage = game:GetService("ServerStorage")

local actor: Actor = script.Parent

local DataStore = require(actor.DataStore)
local createTableFromSharedTable = require(ServerStorage.Modules.ConvertSharedTableToTable)

local DataManipulator = require(ServerStorage.Modules.SaveFileManipulator)

local template = require(ServerStorage.Modules.SaveFileTemplate)
local saveSettings = require(actor.Settings)
local bindable = actor.Echo
local unloadBindable = actor.Unloaded

do
	local iter
	iter = function(item)
		if typeof(item) == "table" then
			local metatable = getmetatable(item)
			local generic = metatable and metatable.generic

			for i, v in item do
				if i == generic then
					item[i] = nil
				else
					iter(v)
				end
			end

			setmetatable(item, nil)
		end
	end
	iter(template)
end

local storeName = saveSettings.StoreName
local scope = saveSettings.Scope
local keyFormat = saveSettings.KeyFormat

local string_format = string.format

local sharedTables = SharedTableRegistry:GetSharedTable("SaveFiles")
local stores = {}

local playerConnections = {}
local waitingProfiles = {}

Players.PlayerAdded:Connect(function(player: Player)
	print(`@{player} joined the game.`)
	local key = string_format(keyFormat, player.UserId)
	local store = DataStore.new(storeName, scope, key)

	local storeId = store.Id
	local response, responseData = store:Open({})

	if response == "Success" then
		store.UserIds = {player.UserId}

		local value = store.Value

		DataManipulator.Reconcile(value, template)

		local storeSharedTable
		if typeof(value) == "table" then
			storeSharedTable = SharedTable.new(value)
		else
			storeSharedTable = SharedTable.new()
		end
		sharedTables[storeId] = storeSharedTable
		stores[storeId] = store

		local connections = {}
		table.insert(connections, store.Saving:Connect(function()
			if storeSharedTable then
				local newTable, isMixed = createTableFromSharedTable(storeSharedTable)
		
				local uncompressedUsagePercent = #HttpService:JSONEncode(newTable) / 4194303
		
				if isMixed or uncompressedUsagePercent >= 1 then
					store.Metadata.Compression = {
						Level = 1,
						Safety = true
					}
				else
					store.Metadata.Compression = nil
				end
		
				store.Value = newTable
			else
				warn(`Warning: StoreSharedTable not found for {storeId}/{store.UniqueId}`)
				store:Destroy()
			end
		end))

		table.insert(connections, store.StateChanged:Connect(function(state: boolean?)
			if not state then
				unloadBindable:Fire(storeId)
				if player then
					print(`@{player} was kicked due to save file state change.`)
					player:Kick(`Your session was {if state == false then "closed" else "destroyed"} and you have been kicked to prevent data loss. Please rejoin Taxi Simulator Future at a later time.`)
				end
			end
		end))

		playerConnections[player] = connections
	else
		print(`@{player} was kicked because their save file was in the {response} state.`)
		if response == "Locked" then
			player:Kick(`Your save file is inaccessible. Please wait up to 5 minutes to allow Roblox to automatically unlock your save file.`)
		else
			player:Kick(`Your save file is inaccessible. See status.roblox.com for more information.`)
		end
	end
	if waitingProfiles[storeId] then
		bindable:Fire("ProfileLoaded", storeId, response)
		waitingProfiles[storeId] = nil
	end
	print(`@{player}'s save data was loaded successfully.`)
end)

local baseId = `{storeName}/{scope}/`
Players.PlayerRemoving:Connect(function(player)
	print(`@{player} left the game.`)
	local storeId = baseId .. string_format(keyFormat, player.UserId)
	local store = stores[storeId]

	local storeSharedTable = sharedTables[storeId]
	sharedTables[storeId] = nil

	DataManipulator.TrimSaveFile(storeSharedTable)

	if store then
		store:Close()
	end

	local connections = playerConnections[player]
	for i = 1, #connections do
		connections[i]:Disconnect()
	end

	if waitingProfiles[storeId] then
		bindable:Fire("ProfileLoaded", storeId, "Error")
		waitingProfiles[storeId] = nil
	end

	task.wait(10)
	if store and store.State == false then
		store:Destroy()
	end
end)

local topics = {}

SharedTableRegistry:SetSharedTable("SaveFiles", sharedTables)

topics.WaitForProfile = function(player: Player | string)
	local storeId = baseId .. string_format(keyFormat, player.UserId)
	local foundStore

	if typeof(player) == "Instance" then
		foundStore = DataStore.find(storeName, scope, string_format(keyFormat, player.UserId))
	else
		foundStore = DataStore.find(string.split(player, "/"))
	end

	if foundStore and foundStore.State then
		bindable:Fire("ProfileLoaded", storeId, "Success")
	else
		waitingProfiles[storeId] = true
	end
end

bindable.Event:ConnectParallel(function(topic, ...)
	local topicFunction = topics[topic]
	if topicFunction then
		topicFunction(...)
	end
end)

actor:SetAttribute("Loaded", true)