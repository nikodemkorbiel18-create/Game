--!nocheck
-- Mutable state shared by the emulator modules (contexts, players, settings).
return {
	server = nil, -- server Context
	clients = {}, -- real Player -> client Context
	latency = 1 / 30, -- one-way remote latency in seconds
	isStudio = true,
	defaultViewport = nil, -- Vector2, set in init
	userOwnsPass = {}, -- [userId] = { [passId] = true }
	dataStores = nil, -- persistent across emulated servers (see Services)
	bindToClose = {},
	tweens = {},
}
