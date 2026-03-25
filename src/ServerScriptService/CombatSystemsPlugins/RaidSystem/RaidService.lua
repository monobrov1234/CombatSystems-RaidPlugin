--!strict

local module = {}
local funcs = {}

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Logger = require(ReplicatedStorage.CombatSystemsShared.Utils.LoggerUtil)
local TeamService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.TeamService)
local TeamScoreService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.TeamScoreService)
local PointCaptureService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.PointCaptureService)
type TeamInfo = typeof(require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Modules.SharedEntities.TeamInfo))

-- ROBLOX OBJECTS
local configSetRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.RaidService.ClientToServer.ConfigSet
local startStopRaidRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.RaidService.ClientToServer.StartStopRaid

-- FINALS
local log: Logger.SelfObject = Logger.new("TeamService")

-- STATE
local raidRunning = false

-- PUBLIC API
function module.startRaid()
	if raidRunning then return end
	raidRunning = true
	TeamScoreService.start()
	PointCaptureService.start()
	log:info("Raid started")
end

function module.stopRaid()
	if not raidRunning then return end
	raidRunning = false
	TeamScoreService.stop()
	PointCaptureService.stop()
	log:info("Raid stopped")
end

-- INTERNAL FUNCTIONS
function funcs.handleConfigSet(player: Player, defenderTeamName: string, defenderTeamIconId: string, raiderTeamName: string, raiderTeamIconId: string)
	assert(
		typeof(defenderTeamName) == "string"
			and typeof(defenderTeamIconId) == "string"
			and typeof(raiderTeamName) == "string"
			and typeof(raiderTeamIconId) == "string"
	)

	for name: string, team: TeamInfo in pairs(TeamService.getTeams()) do
		TeamService.removeTeam(team)
	end

	TeamService.addTeam({
		Name = defenderTeamName,
		LayoutOrder = 1,
		Color = Color3.new(0, 1, 0.2),
		ImageAssetId = tonumber(defenderTeamIconId) or 0,
		StartPoints = 0,
	})

	TeamService.addTeam({
		Name = raiderTeamName,
		LayoutOrder = 2,
		Color = Color3.new(1, 0.184314, 0.184314),
		ImageAssetId = tonumber(raiderTeamIconId) or 0,
		StartPoints = 0,
	})
end

function funcs.handleStartStopRaid(player: Player)
	if raidRunning then
		module.stopRaid()
	else
		module.startRaid()
	end
end

function funcs.init()
	-- team service should be first
	TeamService.init()
	TeamScoreService.init()
	PointCaptureService.init()
end
funcs.init()

configSetRemote.OnServerEvent:Connect(funcs.handleConfigSet)
startStopRaidRemote.OnServerEvent:Connect(funcs.handleStartStopRaid)

return module
