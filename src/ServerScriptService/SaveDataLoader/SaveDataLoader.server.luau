local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local actor: Actor = script.Parent

local DataStore = require(actor.DataStore)
local createTableFromSharedTable = require(ServerStorage.Modules.ConvertSharedTableToTable)

local DataManipulator = require(ServerStorage.Modules.SaveFileManipulator)

local template = require(ServerStorage.Modules.SaveFileTemplate)
local saveSettings = require(actor.Settings)
local bindable = actor.Echo
local unloadBindable = actor.Unloaded
local updaters = require(actor.Updaters)

local version = #updaters

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

		local connections = {}
		local orderedStores = {}

		do --all of this is for ordered data stores
			local loadingStores = 0
			local thread = coroutine.running()

			local iter
			iter = function(item, currentTemplateValue, hierarchy, generics)
				local meta = getmetatable(currentTemplateValue)
				local generic = meta and meta.generic
				for i, v in currentTemplateValue do
					if typeof(v) == "table" then
						local newHierarchy = table.clone(hierarchy)

						if i == generic then
							for i2, v2 in item do
								table.insert(newHierarchy, i2)
								local newGenerics = table.clone(generics)
								table.insert(newGenerics, i2)
								iter(v2, v, newHierarchy, newGenerics)
							end
						else
							table.insert(newHierarchy, i)
							iter(item[i], v, newHierarchy, generics)
						end
					elseif meta then
						local order = meta.orderedValues
						if order then
							local orderKey = order[i]
							if orderKey then
								local newScope = scope .. "/" .. table.concat(generics, "/") .. (#generics > 0 and "/" or "") .. orderKey

								local orderedStore = DataStore.new(storeName, newScope, key)
								local orderedStoreMeta = getmetatable(orderedStore)
								orderedStoreMeta.DataStore = setmetatable({DataStoreService:GetOrderedDataStore(storeName, newScope)}, { --setasync errors on ordereddatastore if userids or options are present, making this hack necessary
									__index = function(t, k)
										local store = t[1]
										if k == "SetAsync" then
											return function(self, key, value, userIds, options)
												return store:SetAsync(key, value)
											end
										elseif typeof(store[k]) == "function" then
											return function(self, ...)
												return store[k](store, ...)
											end
										end
										return store[k]
									end
								})

								local newHierarchy = table.clone(hierarchy)
								table.insert(newHierarchy, i)

								orderedStores[orderedStore] = newHierarchy
								loadingStores += 1

								task.defer(function()
									local response = orderedStore:Open(v)
									if response == "Success" then
										item[i] = orderedStore.Value
										loadingStores -= 1

										table.insert(connections, orderedStore.Saving:Connect(function()
											local currentValue = storeSharedTable
											for i2, v2 in newHierarchy do
												currentValue = currentValue[v2]
											end
											orderedStore.Value = currentValue
										end))

										table.insert(connections, orderedStore.StateChanged:Connect(function(state: boolean?)
											if sharedTables[storeId] then
												print(`@{player} was kicked due to the state change of ordered store "{newScope}".`)
												player:Kick(`Your {orderKey} session was {if state == false then "closed" else "destroyed"} and you have been kicked to prevent data loss. Please rejoin Taxi Simulator Future at a later time.`)
											else
												--closed gracefully
											end
										end))

										if loadingStores == 0 then
											assert(coroutine.resume(thread))
										end
									else
										print(`@{player} was kicked because their "{newScope}" ordered store was in the {response} state.`)
										if response == "Locked" then
											player:Kick(`Your {orderKey} data is inaccessible. Please wait up to 5 minutes to allow Roblox to automatically unlock your save file.`)
										else
											player:Kick(`Your {orderKey} data is inaccessible. See status.roblox.com for more information.`)
										end
									end
								end)
							end
						end
					end
				end
			end
			iter(value, template, {}, {})

			if loadingStores > 0 then
				coroutine.yield()
			end
		end

		local storeVersion = store.Metadata.Version or 0

		for i = storeVersion + 1, version do
			updaters[i](value)
			store.Metadata.Version = i
		end

		if typeof(value) == "table" then
			storeSharedTable = SharedTable.new(value)
		else
			storeSharedTable = SharedTable.new()
		end

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

				for orderedStore, hierarchy in orderedStores do
					orderedStores[orderedStore] = nil
					local currentValue = storeSharedTable
					for i, v in hierarchy do
						currentValue = currentValue[v]
					end
					orderedStore.Value = currentValue
					orderedStore:Close()

					task.delay(10, function()
						if orderedStore and orderedStore.State == false then
							orderedStore:Destroy()
						end
					end)
				end

				unloadBindable:Fire(storeId)
				if player and sharedTables[storeId] then
					print(`@{player} was kicked due to save file state change.`)
					player:Kick(`Your session was {if state == false then "closed" else "destroyed"} and you have been kicked to prevent data loss. Please rejoin Taxi Simulator Future at a later time.`)
				end
			end
		end))

		sharedTables[storeId] = storeSharedTable
		stores[storeId] = store

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

	task.delay(10, function()
		if store and store.State == false then
			store:Destroy()
		end
	end)
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