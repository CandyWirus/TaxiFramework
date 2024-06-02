local ReplicatedStorage = game:GetService("ReplicatedStorage")

local actor = script.Parent

local remote = ReplicatedStorage.Remotes.QuerySaveFile
local bindable = actor.Query
local changedBindable = actor.FileChanged
local Enum_NilValue = newproxy()

local cache = {}

--Invalid arguments to these functions WILL cause a cache desync and potentially a ban!

local get = function(...)
	local args = {...}
	local length = #args
	local currentValue = cache
	for i, v in args do
		local newValue = currentValue[v]

		if i == length then
			if newValue == Enum_NilValue then
				return nil
			elseif newValue ~= nil then
				return newValue
			else
				local value = remote:InvokeServer(false, ...)
				if value == nil then
					newValue = Enum_NilValue
				else
					newValue = value
				end
				currentValue[v] = newValue
			end
		elseif newValue == nil then
			newValue = {}
			currentValue[v] = newValue
		end

		currentValue = newValue
	end
	return currentValue
end

local iter = function(...)
	local value = remote:InvokeServer(true, ...)
	if value then
		local currentValue = cache
		for i, v in {...} do
			local newValue = currentValue[v]
			if newValue == nil then
				newValue = {}
				currentValue[v] = newValue
			end
			currentValue = newValue
		end
		for i, v in value do
			currentValue[i] = v
		end
		return currentValue
	end
end

bindable.OnInvoke = function(isIter, ...)
	if isIter then
		return iter(...)
	else
		return get(...)
	end
end

remote.OnClientInvoke = function(value, ...)
	local args = {...}
	local length = #args
	local currentValue = cache

	for i, v in args do
		local newValue = currentValue[v]
		if i == length then
			currentValue[v] = value
			break
		elseif typeof(newValue) ~= "table" then
			newValue = {}
			currentValue[v] = newValue
		end
		currentValue = newValue
	end

	changedBindable:Fire(...)
end

get(1) --Ensure save file is loaded before marking as loaded. Side effect: The value at the path [1] (because the sole argument is 1) must be valid and accessible, otherwise the client will be banned.
actor:SetAttribute("Loaded", true)