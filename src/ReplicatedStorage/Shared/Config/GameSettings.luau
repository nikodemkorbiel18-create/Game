--!strict
-- Global tuning constants. Every gameplay number that is not tied to a specific
-- character, zone, rarity or shop item lives here.

local GameSettings = {
	GameName = "Steal a Chibi!",
	DataVersion = 1,
	DataStoreName = "StealAChibi_Profiles_v1",
	AutosaveInterval = 60, -- seconds between profile autosaves

	-- Server / map
	MaxPlayers = 5, -- one per base in the current map
	EggResetInterval = 300, -- seconds, synced to os.time() across servers
	PedestalsPerNest = 8,

	-- Interaction timings (seconds) and ranges (studs)
	GrabHoldTime = 0.5,
	SnatchHoldTime = 1.0,
	RaidHoldTime = 1.5,
	OwnerPickupHoldTime = 0.25,
	InteractRange = 8,
	InteractRangeTolerance = 4, -- extra slack for latency when validating on the server
	DroppedItemLifetime = 10,

	-- Harisen (paper-fan slap)
	Slap = {
		Cooldown = 4,
		Stun = 0.75,
		Range = 7,
		ConeDot = 0.2, -- target must be roughly in front of the slapper
	},

	-- Guardians
	Guardian = {
		SpeedFactor = 0.8, -- Guardian WalkSpeed = PlayerWalkSpeed(recommended Speed) * this
		AlertWindup = 0.4,
		CatchRadius = 4,
		NestRadius = 18,
		ReturnDistance = 40, -- studs beyond the zone boundary before giving up
		MaxChaseTime = 25,
		RepathBlockedTime = 0.5,
		ChaseTick = 0.1,
		PatrolPause = 1.5,
		RagdollTime = 1.5,
		CatchGrace = 4, -- seconds a caught player is ignored by every Guardian
		KnockbackForce = 60,
		MinWalkSpeed = 12.8,
	},

	-- Speed -> WalkSpeed: min(Max, Base + PerLog * log10(1 + Speed))
	WalkSpeed = {
		Base = 16,
		PerLog = 7,
		Max = 100,
	},

	-- Treadmill
	TreadmillUnlockPrice = 1000,

	-- Economy
	InventoryCapacity = 50,
	PhysicalPenSlots = 40, -- pedestals built into each base (24 max level + 6 pass + rebirth slots)
	SellMultiplier = 30, -- sell price = effective $/s * this
	SellConfirmRank = 5, -- Legendary and above ask for confirmation
	Offline = {
		Rate = 0.25,
		CapHours = 8,
		VipRate = 0.5,
		VipCapHours = 12,
		MinSecondsForPopup = 60,
	},
	WelcomeGiftCash = 1000, -- granted by the tutorial so a new player can unlock the treadmill
	TutorialHatchCap = 12, -- the very first egg a player ever places hatches in at most this many seconds

	-- Protection & barrier
	NewPlayerProtection = 600, -- seconds of total playtime
	Barrier = {
		BaseDuration = 60,
		Cooldown = 90,
		PushInterval = 0.15,
	},

	-- Luck
	LuckyHatchPerRebirth = 0.10,
	LuckBoostBonus = 0.25, -- 15-minute Luck Boost product
	LuckCap = 0.9,

	-- Server-wide announcements for spawns/hatches at or above this rarity rank (8 = Secret)
	AnnounceRank = 8,

	-- Roblox group (0 = disabled). Joining grants a one-time Speed bonus.
	GroupId = 0,
	GroupSpeedReward = 10000,

	-- Admins: the place owner (or group owner) is always an admin. Add extra UserIds here.
	AdminUserIds = {} :: { number },

	-- Anti-exploit
	AntiExploit = {
		CheckInterval = 0.5,
		SpeedTolerance = 1.6, -- allowed multiple of WalkSpeed
		FlatAllowance = 12, -- studs per check for knockbacks, conveyors, latency
		StrikesBeforeRubberband = 2,
		RemoteRateLimit = 12, -- calls per second per remote per player
	},

	-- Leaderboards
	Leaderboard = {
		RefreshInterval = 120,
		Size = 10,
	},
}

return GameSettings
