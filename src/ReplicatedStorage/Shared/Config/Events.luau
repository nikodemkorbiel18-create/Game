--!strict
-- Live events. Schedules are computed from os.time() (UTC) so every server agrees
-- without talking to each other. Admins can also start any event (see AdminService).

export type EventDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Kind: "Weekly" | "Hourly" | "Manual",
	-- Weekly: os.date("!*t") weekday (1 = Sunday ... 7 = Saturday), hour and minute in UTC
	Weekday: number?,
	Hour: number?,
	Minute: number?,
	-- Hourly: chance that the event happens in a given UTC hour
	Chance: number?,
	Duration: number,
	Color: string,
	Effects: { [string]: number },
}

local list: { EventDef } = {
	{
		Id = "Matsuri",
		DisplayName = "Matsuri Nights",
		Description = "Lanterns, fireworks and Festival Eggs on the Station Plaza stage!",
		Kind = "Weekly",
		Weekday = 7,
		Hour = 18,
		Minute = 0,
		Duration = 1800,
		Color = "#FF9F1C",
		Effects = { FestivalEggs = 1 },
	},
	{
		Id = "SakuraStorm",
		DisplayName = "Sakura Storm",
		Description = "Petals everywhere! Natural mutation chances are doubled.",
		Kind = "Hourly",
		Chance = 0.6,
		Duration = 600,
		Color = "#FFB7C5",
		Effects = { MutationChance = 2 },
	},
	{
		Id = "EclipseHour",
		DisplayName = "Eclipse Hour",
		Description = "The sky turns red-violet. Secret eggs are 3x more likely in zones 9 and 10.",
		Kind = "Hourly",
		Chance = 0.2,
		Duration = 600,
		Color = "#9D4EDD",
		Effects = { SecretChance = 3 },
	},
	{
		Id = "DoubleGrowth",
		DisplayName = "Double Growth",
		Description = "Eggs hatch twice as fast!",
		Kind = "Weekly",
		Weekday = 1,
		Hour = 17,
		Minute = 0,
		Duration = 3600,
		Color = "#80ED99",
		Effects = { HatchSpeed = 2 },
	},
}

local byId: { [string]: EventDef } = {}
for _, event in list do
	byId[event.Id] = event
end

local Events = {
	List = list,
	ById = byId,
	EclipseZones = { 9, 10 },
	FestivalPedestals = 4,
	FestivalRarityWeights = { Legendary = 80, Mythic = 17, Cosmic = 3 },
}

return Events
