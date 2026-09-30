--!strict
-- CollectionService tags and instance names the code relies on.
-- docs/STUDIO_SETUP.md explains where each one goes in the map.

local Tags = {
	Plot = "Plot", -- Model per base. Attributes: PlotId (number)
	PlotFloor = "PlotFloor", -- the base's floor Part (defines the plot boundary)
	PenSlot = "PenSlot", -- pedestal Part. Attributes: PlotId, SlotIndex
	CashRegister = "CashRegister", -- Part inside the plot
	CollectPlate = "CollectPlate", -- Part inside the plot
	Treadmill = "Treadmill", -- Model inside the plot (Belt part required)
	BarrierButton = "BarrierButton", -- Part inside the plot
	BarrierField = "BarrierField", -- ForceField Part covering the plot
	PlotSign = "PlotSign", -- Part with the owner sign
	PlotSpawn = "PlotSpawn", -- where the owner respawns

	Zone = "Zone", -- invisible Part covering a zone's area. Attributes: ZoneId
	Nest = "Nest", -- center Part of a zone's nest. Attributes: ZoneId
	EggPedestal = "EggPedestal", -- Attributes: ZoneId, PedestalIndex
	GuardianWaypoint = "GuardianWaypoint", -- Attributes: ZoneId, Order
	GuardianSpawn = "GuardianSpawn", -- Attributes: ZoneId, Index
	ZoneGate = "ZoneGate", -- torii gate sign part. Attributes: ZoneId

	FestivalPedestal = "FestivalPedestal", -- Attributes: PedestalIndex
	TrailShop = "TrailShop",
	ItemShop = "ItemShop",
	FusionPod = "FusionPod",
	SellCounter = "SellCounter",
	CodesBoard = "CodesBoard",
	EventStage = "EventStage",
	Leaderboard = "Leaderboard", -- Part with SurfaceGui. Attributes: Board ("TotalEarned" | "Rebirths" | "HighestIncome")

	GauntletStart = "GauntletStart",
	GauntletFinish = "GauntletFinish",
	GauntletArea = "GauntletArea", -- Attributes: Phase (1..3)
	GauntletBoss = "GauntletBoss",
	HeavenGate = "HeavenGate", -- blocks zone 11 until the gauntlet is cleared
	SacredIncubator = "SacredIncubator",
	PetalField = "PetalField",

	-- Runtime tags (added by the server)
	WorldEgg = "WorldEgg", -- egg sitting on a pedestal / ground
	PenItem = "PenItem", -- egg or character in a pen slot
	CarriedItem = "CarriedItem",
	Guardian = "Guardian",
	Trap = "OfudaTrap",
}

return Tags
