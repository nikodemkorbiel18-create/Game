--!strict
-- Fusion Pod (Station Plaza).

export type Recipe = {
	Id: string,
	DisplayName: string,
	Inputs: { string }, -- one of each character is consumed
	Result: string, -- character id hatched from the egg
	Price: number,
	EggModel: string,
}

local Fusion = {
	Copies = 3, -- same character x3 -> 1 Awakened
	Duration = 120,
	AwakenedIncome = 4,
	KeepMutationChance = 0.10, -- when the three mutations differ
	Recipes = {
		{ Id = "DuetEgg", DisplayName = "Duet Egg", Inputs = { "StarlightSeira", "Lumi" }, Result = "TwinStarUnit", Price = 250e6, EggModel = "Egg_Duet" },
		{ Id = "RivalEgg", DisplayName = "Rival Egg", Inputs = { "BraveHeroYuki", "MaoChan" }, Result = "HeroAndHeir", Price = 1.5e9, EggModel = "Egg_Rival" },
		{ Id = "EclipseEgg", DisplayName = "Eclipse Egg", Inputs = { "DemonLordVorthax", "Azrielle" }, Result = "EclipseSovereign", Price = 50e9, EggModel = "Egg_Eclipse" },
	} :: { Recipe },
}

function Fusion.GetRecipe(id: string): Recipe?
	for _, recipe in Fusion.Recipes do
		if recipe.Id == id then
			return recipe
		end
	end
	return nil
end

return Fusion
