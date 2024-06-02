local SharedTableRegistry = game:GetService("SharedTableRegistry")
local ServerScriptService = game:GetService("ServerScriptService")
local managerActor = ServerScriptService.SaveDataLoader
local saveManagerSettings = require(managerActor.Settings)

local storeName = saveManagerSettings.StoreName
local scope = saveManagerSettings.Scope
local keyFormat = saveManagerSettings.KeyFormat

local bindable = managerActor.Echo

local string_format = string.format

local baseId = `{storeName}/{scope}/`

local sharedTable = SharedTableRegistry:GetSharedTable("SaveFiles")

local getDataStoreFromPlayer = function(player: Player | string)
	local id
	if typeof(player) == "Instance" then
		local userId = player.UserId
		id = baseId .. string_format(keyFormat, userId)
	else
		id = player
	end

	return sharedTable[id], id
end

local waitForDataStore = function(player: Player | string)
	local found, foundId = getDataStoreFromPlayer(player)
	if found then
		return found, foundId, "Success"
	else
		local stupidBindable = Instance.new("BindableEvent") --coroutine.yield does not work in remote/bindable function callbacks due to an incorrect network optimization implemented by Roblox, so we need to use stupid bindables instead
		local connection
		connection = bindable.Event:Connect(function(topic, id, response)
			if topic == "ProfileLoaded" and id == foundId then
				connection:Disconnect()
				local store, newId = getDataStoreFromPlayer(player)
				stupidBindable:Fire(store, newId, response)
			end
		end)
		bindable:Fire("WaitForProfile", player)
		return stupidBindable.Event:Wait()
	end
end

return {
	GetDataStore = getDataStoreFromPlayer,
	WaitForDataStore = waitForDataStore
}