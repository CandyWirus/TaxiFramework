local ServerScriptService = game:GetService("ServerScriptService")

local SaveDataLoader = require(ServerScriptService.SaveDataLoader.Proxy)

return setmetatable(table.clone(SaveDataLoader), {
	__index = function(t, k)
		return require(script[k])
	end
})