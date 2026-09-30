--!strict
-- Sound effects and zone music. Volumes follow the player's settings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local Sound = {}

local sfxVolume = 0.8
local musicVolume = 0.6
local cache: { [string]: Sound } = {}
local currentMusic: Sound? = nil
local currentMusicKey = ""

local function get(key: string): Sound?
	local spec = Sounds.Sfx[key]
	if not spec or spec.Id == "" then
		return nil
	end
	local sound = cache[key]
	if not sound then
		local created = Instance.new("Sound")
		created.Name = "Sfx_" .. key
		created.SoundId = spec.Id
		created.Parent = SoundService
		cache[key] = created
		sound = created
	end
	return sound
end

function Sound.Play(key: string, pitch: number?)
	local spec = Sounds.Sfx[key]
	local sound = get(key)
	if not sound or not spec or sfxVolume <= 0 then
		return
	end
	local clone = sound:Clone()
	clone.Volume = spec.Volume * sfxVolume
	clone.PlaybackSpeed = (pitch or 1) * spec.Pitch
	clone.Parent = SoundService
	clone:Play()
	clone.Ended:Once(function()
		clone:Destroy()
	end)
	task.delay(6, function()
		if clone.Parent then
			clone:Destroy()
		end
	end)
end

function Sound.SetMusic(key: string)
	if key == currentMusicKey then
		return
	end
	currentMusicKey = key
	local id = Sounds.Music[key] or ""
	local old = currentMusic
	if old then
		local fade = TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 })
		fade:Play()
		fade.Completed:Once(function()
			old:Destroy()
		end)
		currentMusic = nil
	end
	if id == "" then
		return
	end
	local music = Instance.new("Sound")
	music.Name = "Music_" .. key
	music.SoundId = id
	music.Looped = true
	music.Volume = 0
	music.Parent = SoundService
	music:Play()
	TweenService:Create(music, TweenInfo.new(1.5), { Volume = Sounds.MusicVolume * musicVolume }):Play()
	currentMusic = music
end

function Sound.Init()
	UI.SetClickSound(function(key)
		Sound.Play(key)
	end)
end

function Sound.Start()
	State.OnChange("Settings", function(settings)
		if type(settings) == "table" then
			sfxVolume = settings.Sfx or 0.8
			musicVolume = settings.Music or 0.6
			if currentMusic then
				currentMusic.Volume = Sounds.MusicVolume * musicVolume
			end
		end
	end)
	Net.Event("Effect").OnClientEvent:Connect(function(effect)
		if type(effect) ~= "table" then
			return
		end
		if effect.Type == "Collect" then
			Sound.Play("CashDing")
		elseif effect.Type == "Deliver" then
			Sound.Play("Purchase")
		elseif effect.Type == "Slap" then
			Sound.Play("Slap")
		elseif effect.Type == "Drop" then
			Sound.Play("Whoosh")
		end
	end)
end

return Sound
