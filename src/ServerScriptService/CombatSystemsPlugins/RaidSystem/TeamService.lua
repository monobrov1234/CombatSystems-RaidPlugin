--!strict

local module = {}
local funcs = {}

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local Signal = require(ReplicatedStorage.CombatSystemsShared.Utils.Signal)
local Logger = require(ReplicatedStorage.CombatSystemsShared.Utils.LoggerUtil)
local TeamsConfig = require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Configs.TeamsConfig)
type TeamInfo = typeof(require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Modules.SharedEntities.TeamInfo))

-- ROBLOX OBJECTS
local teamsInfoRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.TeamService.ServerToClient.InitTeamsInfo
local teamAddedRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.TeamService.ServerToClient.TeamAdded
local teamRemovedRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.TeamService.ServerToClient.TeamRemoved

-- FINALS
local log: Logger.SelfObject = Logger.new("TeamService")
local teams = {} :: { [string]: TeamInfo }

-- PUBLIC EVENTS
module.TeamAdded = Signal.new() -- function(info: TeamInfo)
module.TeamRemoved = Signal.new() -- function(info: TeamInfo)

-- PUBLIC API
function module.init()
	funcs.loadTeams()

	for _, player: Player in ipairs(Players:GetPlayers()) do
		funcs.handlePlayerJoined(player)
	end
	Players.PlayerAdded:Connect(funcs.handlePlayerJoined)

	module.TeamAdded:connect(funcs.handleTeamAdd)
	module.TeamRemoved:connect(funcs.handleTeamRemove)

	-- TEMPORARY TODO: DELETE
	task.delay(2, function()
		local team3ND = module.getTeam("3ND")
		assert(team3ND)
		for _, player: Player in ipairs(game:GetService("Players"):GetPlayers()) do
			module.addPlayerToTeam(player, team3ND)
		end
	end)
end

function module.addTeam(team: TeamInfo)
	assert(team.Name ~= "", "Empty team name unsupported")
	assert(teams[team.Name] == nil, "Team already exists")

	local linkedTeam = Instance.new("Team")
	linkedTeam.Name = team.Name
	linkedTeam.TeamColor = BrickColor.new(team.Color)
	linkedTeam.AutoAssignable = false
	linkedTeam.Parent = Teams

	team.LinkedTeam = linkedTeam
	teams[team.Name] = team
	module.TeamAdded:fire(team)
end

function module.removeTeam(team: TeamInfo)
	assert(teams[team.Name])
	assert(team.LinkedTeam)

	team.LinkedTeam:Destroy()
	teams[team.Name] = nil
	module.TeamRemoved:fire(team)
end

function module.addPlayerToTeam(player: Player, team: TeamInfo)
	assert(team.LinkedTeam)
	player.Team = team.LinkedTeam
end

function module.removePlayerFromTeam(player: Player)
	player.Team = nil
end

function module.getPlayerTeam(player: Player): TeamInfo?
	local team: Team? = player.Team
	if not team then return nil end
	local info = teams[team.Name]
	if not info or info.LinkedTeam ~= team then return nil end
	return info
end

function module.getTeam(name: string): TeamInfo?
	return teams[name]
end

function module.getTeams(): { [string]: TeamInfo }
	return teams
end

-- INTERNAL FUNCTIONS
function funcs.handlePlayerJoined(player: Player)
	teamsInfoRemote:FireClient(player, teams)
end

function funcs.handleTeamAdd(team: TeamInfo)
	teamAddedRemote:FireAllClients(team)
end

function funcs.handleTeamRemove(team: TeamInfo)
	teamRemovedRemote:FireAllClients(team)
end

function funcs.loadTeams()
	local count = 0
	for i: number, starterTeam: TeamsConfig.StarterTeamType in pairs(TeamsConfig.StarterTeams) do
		module.addTeam({
			Name = starterTeam.Name,
			LayoutOrder = i,
			Color = starterTeam.Color,
			ImageAssetId = starterTeam.ImageAssetId,
			StartPoints = starterTeam.StartPoints,
		})

		log:info("Loaded team {}", starterTeam.Name)
		count += 1
	end

	log:info("Loaded {} teams", count)
end

return module
