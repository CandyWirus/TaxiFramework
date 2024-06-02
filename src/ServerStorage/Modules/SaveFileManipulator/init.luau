return setmetatable({}, {
	__index = function(t, k)
		return require(script[k])
	end
})