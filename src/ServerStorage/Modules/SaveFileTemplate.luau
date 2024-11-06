return setmetatable({
	0 --Starting money, for example. This value (wrapper[1]) must always be present and client-readable for compatibility with the SaveDataClient Actor.
}, {
	index = function(t, k) --See documentation on TaxiFramework's save file template
		return k == 1
	end
})