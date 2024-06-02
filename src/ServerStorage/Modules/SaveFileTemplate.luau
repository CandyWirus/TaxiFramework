return setmetatable({
	0 --Starting money, for example. This value must always be present and client-readable for compatibility.
}, {
	index = function(t, k) --See documentation on TaxiFramework's save file template
		return k == 1
	end
})