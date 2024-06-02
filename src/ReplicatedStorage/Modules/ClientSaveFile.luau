local Players = game:GetService("Players")
local player = Players.LocalPlayer

local actor = player.PlayerScripts.SaveDataClient

local queryBindable = actor.Query
local changedBindable = actor.FileChanged

local get = function(...)
	return queryBindable:Invoke(false, ...)
end

local iter = function(...)
	return queryBindable:Invoke(true, ...)
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
	table.insert(boundFunctions, args)
	return args
end

return {
	BindToChanged = bindToChanged,
	Get = get,
	Iter = iter
}