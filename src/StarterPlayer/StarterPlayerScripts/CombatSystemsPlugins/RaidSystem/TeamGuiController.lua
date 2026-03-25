--!strict

local module = {}
local funcs = {}

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.CombatSystemsShared.Utils.Signal)
type TeamInfo = typeof(require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Modules.SharedEntities.TeamInfo))

-- ROBLOX OBJECTS
local player = Players.LocalPlayer :: Player
local playerGui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()
local teamStatGui = playerGui:WaitForChild("CombatSystemsPluginsGui"):WaitForChild("RaidSystemGui"):WaitForChild("TeamStatGui"):WaitForChild("ScrollingFrame")
local teamTemplate = teamStatGui:WaitForChild("TeamTemplate")

local teamsInfoRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.TeamService.ServerToClient.InitTeamsInfo
local teamAddedRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.TeamService.ServerToClient.TeamAdded
local teamRemovedRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.TeamService.ServerToClient.TeamRemoved

-- STATE
local teams = {} :: { [string]: TeamInfo }

-- PUBLIC EVENTS
module.TeamAdded = Signal.new() -- function(info: TeamInfo)
module.TeamRemoved = Signal.new() -- function(info: TeamInfo)

-- INTERNAL FUNCTIONS
function funcs.handleInitTeamsInfo(newTeams: { [string]: TeamInfo })
	teams = newTeams
	for name: string, team: TeamInfo in pairs(teams) do
		funcs.handleTeamAdded(team)
	end
end

function funcs.handleTeamAdded(team: TeamInfo)
	teams[team.Name] = team
	funcs.createTemplateForTeam(team)
	module.TeamAdded:fire(team)
end

function funcs.handleTeamRemoved(team: TeamInfo)
	teams[team.Name] = nil
	module.TeamRemoved:fire(team)

	local foundTemplate = teamStatGui:FindFirstChild(team.Name) :: Frame?
	if foundTemplate then foundTemplate:Destroy() end
end

function funcs.createTemplateForTeam(team: TeamInfo)
	local newTeamTemplate = teamTemplate:Clone()
	newTeamTemplate.Name = team.Name
	newTeamTemplate.LayoutOrder = team.LayoutOrder
	newTeamTemplate.TeamIcon.Image = "rbxassetid://" .. tostring(team.ImageAssetId)
	newTeamTemplate.InfoContainer.TeamName.Text = team.Name
	newTeamTemplate.Visible = true
	newTeamTemplate.Parent = teamStatGui
end

-- if player respawns, these values will become invalid
player.CharacterAdded:Connect(function(newCharacter: Model)
	character = newCharacter
	teamStatGui = playerGui:WaitForChild("CombatSystemsPluginsGui"):WaitForChild("RaidSystemGui"):WaitForChild("TeamStatGui"):WaitForChild("ScrollingFrame")
	teamTemplate = teamStatGui:WaitForChild("TeamTemplate")

	-- readd the team templates
	for _, team: TeamInfo in pairs(teams) do
		funcs.createTemplateForTeam(team)
	end
end)

teamsInfoRemote.OnClientEvent:Connect(funcs.handleInitTeamsInfo)
teamAddedRemote.OnClientEvent:Connect(funcs.handleTeamAdded)
teamRemovedRemote.OnClientEvent:Connect(funcs.handleTeamRemoved)

return module
