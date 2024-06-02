--See ReplicatedFirst.Loader.Callback

local onGameLoaded = function(elapsed: number)
	print(`Game server loaded in {string.format("%.2f", elapsed)} seconds.`)
end

return onGameLoaded