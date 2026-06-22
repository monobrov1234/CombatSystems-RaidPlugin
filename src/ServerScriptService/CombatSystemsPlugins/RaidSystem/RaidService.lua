--!strict

local module = {}
local funcs = {}

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PointPlayerTrackService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.Point.PointPlayerTrackService)
local PointProgressService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.Point.PointProgressService)
local PointStoreService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.Point.PointStoreService)
local Logger = require(ReplicatedStorage.CombatSystemsShared.Utils.LoggerUtil)
local TeamStoreService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.Team.TeamStoreService)
local TeamScoreService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.Team.TeamScoreService)
type TeamInfo = typeof(require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Modules.SharedEntities.TeamInfo))

-- ROBLOX OBJECTS
local configSetRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.RaidService.ClientToServer.ConfigSet
local startStopRaidRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.RaidService.ClientToServer.StartStopRaid

-- FINALS
local log: Logger.SelfObject = Logger.new("RaidService")

-- STATE
local raidRunning = false

-- PUBLIC API
function module.startRaid()
	if raidRunning then return end
	raidRunning = true
	TeamScoreService.start()
	PointPlayerTrackService.start()
	PointProgressService.start()
	log:info("Raid started")
end

function module.stopRaid()
	if not raidRunning then return end
	raidRunning = false
	TeamScoreService.stop()
	PointPlayerTrackService.stop()
	PointProgressService.stop()
	PointStoreService.loadRaidPoints()
	log:info("Raid stopped")
end

-- INTERNAL FUNCTIONS
function funcs.handleConfigSet(player: Player, defenderTeamName: string, defenderTeamIconId: string, raiderTeamName: string, raiderTeamIconId: string)
	assert(typeof(defenderTeamName) == "string"
			and typeof(defenderTeamIconId) == "string"
			and typeof(raiderTeamName) == "string"
			and typeof(raiderTeamIconId) == "string")

	for name: string, team: TeamInfo in pairs(TeamStoreService.getTeams()) do
		TeamStoreService.removeTeam(team)
	end

	TeamStoreService.addTeam({
		Name = defenderTeamName,
		LayoutOrder = 1,
		Color = Color3.new(0, 1, 0.2),
		ImageAssetId = tonumber(defenderTeamIconId) or 0,
		StartPoints = 0,
	})

	TeamStoreService.addTeam({
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
	TeamStoreService.init() -- init order is important!
	TeamScoreService.init()
	PointStoreService.loadRaidPoints()
end
funcs.init()

configSetRemote.OnServerEvent:Connect(funcs.handleConfigSet)
startStopRaidRemote.OnServerEvent:Connect(funcs.handleStartStopRaid)

return module
