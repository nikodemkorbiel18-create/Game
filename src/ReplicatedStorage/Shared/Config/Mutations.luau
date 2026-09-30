--!strict
-- Mutations. One per character; stacks multiplicatively with size.

export type Mutation = {
	Id: string,
	DisplayName: string,
	Income: number,
	HatchTime: number,
	Source: "Natural" | "Incubator",
	Chance: number, -- percent (natural spawn roll, or incubator roll)
	Color: string,
	Visual: string,
}

local list: { Mutation } = {
	{ Id = "Silver", DisplayName = "Silver", Income = 1.25, HatchTime = 1.1, Source = "Natural", Chance = 5, Color = "#DCE6F2", Visual = "Chrome" },
	{ Id = "Golden", DisplayName = "Golden", Income = 2.0, HatchTime = 1.25, Source = "Natural", Chance = 2, Color = "#FFD34D", Visual = "Gold" },
	{ Id = "Rainbow", DisplayName = "Rainbow", Income = 2.5, HatchTime = 1.5, Source = "Natural", Chance = 0.5, Color = "#FF6BD6", Visual = "Rainbow" },
	{ Id = "PetalBloom", DisplayName = "Petal Bloom", Income = 1.5, HatchTime = 1.2, Source = "Incubator", Chance = 97.5, Color = "#FFB7D5", Visual = "Petals" },
	{ Id = "KamiBloom", DisplayName = "Kami Bloom", Income = 3.0, HatchTime = 2.0, Source = "Incubator", Chance = 2.5, Color = "#FFE08A", Visual = "KamiHalo" },
}

local byId: { [string]: Mutation } = {}
for _, mutation in list do
	byId[mutation.Id] = mutation
end

local Mutations = {
	List = list,
	ById = byId,
	Natural = { "Silver", "Golden", "Rainbow" },
	Incubator = { "PetalBloom", "KamiBloom" },
}

function Mutations.Get(id: string?): Mutation?
	if id == nil or id == "" or id == "None" then
		return nil
	end
	return byId[id]
end

function Mutations.IncomeMult(id: string?): number
	local mutation = Mutations.Get(id)
	return if mutation then mutation.Income else 1
end

function Mutations.HatchMult(id: string?): number
	local mutation = Mutations.Get(id)
	return if mutation then mutation.HatchTime else 1
end

function Mutations.DisplayName(id: string?): string
	local mutation = Mutations.Get(id)
	return if mutation then mutation.DisplayName else "None"
end

return Mutations
