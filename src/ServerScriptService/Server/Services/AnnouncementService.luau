--!strict
-- Toasts for one player and banner announcements for the whole server (or every server).

local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

local Remote = require(script.Parent.Parent.Lib.Remote)

local AnnouncementService = {}

local TOPIC = "StealAChibi_Announce"

export type Kind = "Info" | "Success" | "Error" | "Warning" | "Theft" | "Reward"

function AnnouncementService.Notify(player: Player, text: string, kind: Kind?, duration: number?)
	Remote.Fire("Notify", player, { Text = text, Kind = kind or "Info", Duration = duration or 3 })
end

function AnnouncementService.Error(player: Player, text: string)
	AnnouncementService.Notify(player, text, "Error", 2.5)
end

-- Banner across the top of every player's screen in this server.
function AnnouncementService.Announce(text: string, color: string?, kind: string?)
	Remote.FireAll("Announce", { Text = text, Color = color or "#FFD34D", Kind = kind or "Banner" })
end

-- Banner in every server (admin events, global drops).
function AnnouncementService.AnnounceGlobal(text: string, color: string?)
	AnnouncementService.Announce(text, color, "Global")
	if RunService:IsStudio() then
		return
	end
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(TOPIC, { Text = text, Color = color, Server = game.JobId })
		end)
	end)
end

function AnnouncementService.Init() end

function AnnouncementService.Start()
	if RunService:IsStudio() then
		return
	end
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if type(data) == "table" and data.Server ~= game.JobId and type(data.Text) == "string" then
					AnnouncementService.Announce(data.Text, data.Color, "Global")
				end
			end)
		end)
	end)
end

return AnnouncementService
