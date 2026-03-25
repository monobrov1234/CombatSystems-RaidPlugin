local module = {}
local funcs = {}

-- IMPORTS
local Players = game:GetService("Players")
local player = Players.LocalPlayer :: Player
local PlayerScripts = player.PlayerScripts :: typeof(game:GetService("StarterPlayer").StarterPlayerScripts)
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamController = require(PlayerScripts.CombatSystemsPlugins.RaidSystem.TeamGuiController)
type TeamInfo = typeof(require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Modules.SharedEntities.TeamInfo))

-- ROBLOX OBJECTS
local playerGui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()
local teamStatGui = playerGui:WaitForChild("CombatSystemsPluginsGui"):WaitForChild("RaidSystemGui"):WaitForChild("TeamStatGui"):WaitForChild("ScrollingFrame")
local teamTemplate = teamStatGui:WaitForChild("TeamTemplate")

local teamScoresInfoRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.TeamScoreService.ServerToClient.InitTeamScoresInfo
local teamScoreUpdated = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.TeamScoreService.ServerToClient.TeamScoreUpdated

-- STATE
local teamScores = {} :: { [string]: number }

-- INTERNAL FUNCTIONS
function funcs.handleHeartbeat()
	for teamName: string, score: number in pairs(teamScores) do
		local foundTemplate = teamStatGui:FindFirstChild(teamName) :: typeof(teamTemplate)?
		if foundTemplate then foundTemplate.InfoContainer.TeamPoints.Text = tostring(math.round(score)) .. "P" end
	end
end

function funcs.handleInitTeamScoresInfo(newTeamScores: typeof(teamScores))
	teamScores = newTeamScores
	for teamName: string, score: number in pairs(teamScores) do
		funcs.handleTeamScoreUpdated(teamName, score)
	end
end

function funcs.handleTeamScoreUpdated(teamName: string, score: number)
	teamScores[teamName] = score
end

function funcs.handleTeamRemoved(team: TeamInfo)
	teamScores[team.Name] = nil
end

-- if player respawns, these values will become invalid
player.CharacterAdded:Connect(function(newCharacter: Model)
	character = newCharacter
	teamStatGui = playerGui:WaitForChild("CombatSystemsPluginsGui"):WaitForChild("RaidSystemGui"):WaitForChild("TeamStatGui"):WaitForChild("ScrollingFrame")
	teamTemplate = teamStatGui:WaitForChild("TeamTemplate")
end)

teamScoresInfoRemote.OnClientEvent:Connect(funcs.handleInitTeamScoresInfo)
teamScoreUpdated.OnClientEvent:Connect(funcs.handleTeamScoreUpdated)
TeamController.TeamRemoved:connect(funcs.handleTeamRemoved)

RunService.Heartbeat:Connect(funcs.handleHeartbeat)

return module
