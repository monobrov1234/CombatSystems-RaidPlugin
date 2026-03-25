--!strict

local module = {}
local funcs = {}

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Signal = require(ReplicatedStorage.CombatSystemsShared.Utils.Signal)
local RaidSystemConfig = require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Configs.RaidSystemConfig)
local TeamsConfig = require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Configs.TeamsConfig)
local TeamService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.TeamService)
local PointCaptureService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.PointCaptureService)
type TeamInfo = typeof(require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Modules.SharedEntities.TeamInfo))

-- ROBLOX OBJECTS
local teamScoresInfoRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.TeamScoreService.ServerToClient.InitTeamScoresInfo
local teamScoreUpdated = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.TeamScoreService.ServerToClient.TeamScoreUpdated

-- FINALS
local scoreMap = {} :: { [string]: number }

-- STATE
local running = false
local scoreIncrementLoopThread: thread?

-- PUBLIC EVENTS
module.TeamScoreUpdated = Signal.new()

-- PUBLIC API
function module.init()
	module.resetTeamScores()

	TeamService.TeamAdded:connect(funcs.handleTeamAdded)
	TeamService.TeamRemoved:connect(funcs.handleTeamRemoved)

	for _, player: Player in ipairs(Players:GetPlayers()) do
		funcs.handlePlayerJoined(player)
	end
	Players.PlayerAdded:Connect(funcs.handlePlayerJoined)

	module.TeamScoreUpdated:connect(funcs.handleScoreUpdated)
end

function module.start()
	if running then return end
	running = true
	funcs.scoreIncrementLoop()
end

function module.stop()
	if not running then return end
	running = false
	if scoreIncrementLoopThread then task.cancel(scoreIncrementLoopThread) end
	module.resetTeamScores()
end

function module.resetTeamScores()
	table.clear(scoreMap)
	local teams = TeamService.getTeams()
	for _, team: TeamInfo in pairs(teams) do
		scoreMap[team.Name] = 0

		-- reset start points
		for _, starterTeam: TeamsConfig.StarterTeamType in pairs(TeamsConfig.StarterTeams) do
			if starterTeam.Name == team.Name then module.setTeamScore(team.Name, starterTeam.StartPoints) end
		end
	end
end

function module.getTeamScore(teamName: string): number
	return scoreMap[teamName]
end

function module.addTeamScore(teamName: string, score: number)
	assert(scoreMap[teamName])
	scoreMap[teamName] += score
	module.TeamScoreUpdated:fire(teamName, scoreMap[teamName])
end

function module.setTeamScore(teamName: string, score: number)
	assert(scoreMap[teamName])
	scoreMap[teamName] = score
	module.TeamScoreUpdated:fire(teamName, score)
end

-- INTERNAL FUNCTIONS
function funcs.handlePlayerJoined(player: Player)
	teamScoresInfoRemote:FireClient(player, scoreMap)
end

function funcs.handleScoreUpdated(teamName: string, score: number)
	teamScoreUpdated:FireAllClients(teamName, score)
end

function funcs.handleTeamAdded(team: TeamInfo)
	scoreMap[team.Name] = 0
	module.setTeamScore(team.Name, team.StartPoints)
end

function funcs.handleTeamRemoved(team: TeamInfo)
	scoreMap[team.Name] = nil
end

function funcs.scoreIncrementLoop()
	scoreIncrementLoopThread = task.spawn(function()
		while running do
			for name: string, score: number in pairs(scoreMap) do
				local totalIncome = 0
				for _, point: PointCaptureService.PointView in ipairs(PointCaptureService.getCapturedPoints(name)) do
					totalIncome += RaidSystemConfig.TeamScoreConfig.IncomePerPoint * point.Info.ProgressProperty.Value / 100
				end

				module.addTeamScore(name, totalIncome)
			end

			task.wait(1)
		end
	end)
end

return module
