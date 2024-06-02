local ServerScriptService = game:GetService("ServerScriptService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local actor = script.Parent
local saveManagerSettings = require(actor.Settings)

local storeName = saveManagerSettings.StoreName
local scope = saveManagerSettings.Scope
local keyFormat = saveManagerSettings.KeyFormat

local bindable = actor.Echo

local string_format = string.format

local baseId = `{storeName}/{scope}/`

local sharedTable = SharedTableRegistry:GetSharedTable("SaveFiles")

local changedBindable = ServerScriptService.SaveDataReplicator.FileChanged
local unloadedBindable = actor.Unloaded

local getDataStore = function(player: Player | string)
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
	local found, foundId = getDataStore(player)
	if found then
		return found, foundId, "Success"
	else
		local stupidBindable = Instance.new("BindableEvent") --coroutine.yield does not work in remote/bindable function callbacks due to an incorrect network optimization implemented by Roblox, so we need to use stupid bindables instead
		local connection
		connection = bindable.Event:Connect(function(topic, id, response)
			if topic == "ProfileLoaded" and id == foundId then
				connection:Disconnect()
				local store, newId = getDataStore(player)
				stupidBindable:Fire(store, newId, response)
			end
		end)
		bindable:Fire("WaitForProfile", player)
		return stupidBindable.Event:Wait()
	end
end


local metatable
metatable = {
	__index = function(t, k)
		local raw = t._RAW
		local value = raw[k]

		local valueType = typeof(value)
		if valueType == "table" or valueType == "SharedTable" then
			local hierarchy = table.clone(t._HIERARCHY)
			table.insert(hierarchy, k)
			return table.freeze(setmetatable({_RAW = value, _HIERARCHY = hierarchy}, metatable))
		end
		return value
	end,
	__newindex = function(t, k, v)
		local raw = t._RAW
		local hierarchy = table.clone(t._HIERARCHY)

		table.insert(hierarchy, k) --for some reason tuple `(unpack(hierarchy), k)` does not work as expected. archaic black magic

		local rawType = typeof(raw)
		local valType = typeof(v)

		changedBindable:Fire(unpack(hierarchy))

		if rawType == "SharedTable" and valType == "table" then
			v = SharedTable.new(v)
		end

		raw[k] = v
	end,
	__iter = function(t)
    	local raw = t._RAW
		local keys = {}

		return function()
			for i, v in raw do --this isn't very clean or fast code but it's the only accurate way to make __iter work considering there is no `next` for sharedtables
				if not keys[i] then
					keys[i] = true
					return i, v
				end
			end
		end
	end,
	__tostring = function(t)
		local raw = t._RAW
		return tostring(raw)
	end
}

local createWrapper = function(file, id)
	return table.freeze(setmetatable({_RAW = file, _HIERARCHY = {id}}, metatable))
end

local waitForWrapper = function(player: Player)
	local playerSharedTable, id, success = waitForDataStore(player)

	if not playerSharedTable then
		return nil, success
	end

	return createWrapper(playerSharedTable, id), id, success
end

local boundFunctions = {}

changedBindable.Event:Connect(function(...)
	local hierarchy = {...}
	local hierarchyLength = #hierarchy
	for _, boundHierarchy in boundFunctions do
		local boundLength = #boundHierarchy
		if boundLength - 1 == hierarchyLength then
			local match = true
			for i = 1, boundLength - 1 do
				if boundHierarchy[i] ~= hierarchy[i] then
					match = false
					break
				end
			end
			if match then
				local boundFunction = boundHierarchy[boundLength]
				boundFunction()
				break
			end
		end
	end
end)

unloadedBindable.Event:Connect(function(storeId)
	for i, v in boundFunctions do
		if v[1] == storeId then
			table.remove(boundFunctions, i)
		end
	end
end)

local connectionMetatable = {
	__index = {
		Disconnect = function(self)
			local key = table.find(boundFunctions, self)
			if key then
				table.remove(boundFunctions, key)
			end
		end
	},
	__call = function(t, ...)
		local fun = t[#t]
		return fun(...)
	end
}

local bindToChanged = function(...)
	local args = setmetatable({...}, connectionMetatable)

	local principle = args[1]
	if typeof(principle) ~= "string" then
		args[1] = principle._HIERARCHY[1]
	end

	table.insert(boundFunctions, args)

	return args[#args]
end


return {
	WaitForWrapper = waitForWrapper,
	CreateWrapper = createWrapper,
	WaitRawDataStore = waitForDataStore,
	GetRawStore = getDataStore,
	BindToChanged = bindToChanged
}