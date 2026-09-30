--!strict
-- Sound slots. SFX use sounds that ship with the Roblox client (rbxasset://) so they work
-- with no uploads. Music slots are empty until you add royalty-free Creator Store tracks
-- (paste "rbxassetid://<id>"). See docs/ART_SPEC.md for the music direction per zone.

local Sounds = {
	Sfx = {
		Whistle = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.6 },
		Alert = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Pitch = 0.8 },
		EggCrack = { Id = "rbxasset://sounds/snap.wav", Volume = 0.8, Pitch = 1 },
		Whoosh = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.7, Pitch = 1 },
		CashDing = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Pitch = 2.2 },
		Slap = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.9, Pitch = 1.8 },
		Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Pitch = 1 },
		Grab = { Id = "rbxasset://sounds/button.wav", Volume = 0.6, Pitch = 1.2 },
		Caught = { Id = "rbxasset://sounds/swoosh.wav", Volume = 1, Pitch = 0.6 },
		Reveal = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Pitch = 1.2 },
		Error = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.6, Pitch = 0.6 },
		Purchase = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.4 },
	} :: { [string]: { Id: string, Volume: number, Pitch: number } },
	Music = {
		Home = "",
		Zone1 = "", -- school chime lo-fi
		Zone2 = "", -- synthwave city
		Zone3 = "", -- koto / shakuhachi forest
		Zone4 = "", -- surf-pop beach
		Zone5 = "", -- taiko ninja
		Zone6 = "", -- pop idol
		Zone7 = "", -- industrial mecha
		Zone8 = "", -- orchestral fantasy
		Zone9 = "", -- pipe organ castle
		Zone10 = "", -- ethereal spirit
		Zone11 = "", -- choir celestial
		Matsuri = "",
	} :: { [string]: string },
	MusicVolume = 0.35,
}

return Sounds
