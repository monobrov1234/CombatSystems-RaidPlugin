--!strict

local module = {}
local funcs = {}

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamsConfig = require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Configs.TeamsConfig)

-- ROBLOX OBJECTS
local player = Players.LocalPlayer :: Player
local playerGui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()

local raidSystemGui = playerGui:WaitForChild("CombatSystemsPluginsGui"):WaitForChild("RaidSystemGui")
local raidConfigGui = raidSystemGui:WaitForChild("RaidConfigGui")
local configPanel = raidConfigGui:WaitForChild("ConfigPanel")
local infoContainer = configPanel:WaitForChild("InfoContainer")

local defenderTeamNameField = infoContainer:WaitForChild("DefenderTeamName")
local defenderTeamIconIdField = infoContainer:WaitForChild("DefenderTeamIconId")
local raiderTeamNameField = infoContainer:WaitForChild("RaiderTeamName")
local raiderTeamIconIdField = infoContainer:WaitForChild("RaiderTeamIconId")
local setButton = infoContainer:WaitForChild("ButtonsContainer"):WaitForChild("SetButton")
local startStopButton = infoContainer:WaitForChild("ButtonsContainer"):WaitForChild("StartStopButton")

local hideButton = configPanel:WaitForChild("HideButton")
local showButton = raidConfigGui:WaitForChild("ShowButton")

-- remotes
local configSetRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.RaidService.ClientToServer.ConfigSet
local startStopRaidRemote = ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Events.RaidService.ClientToServer.StartStopRaid

function funcs.handleSetButtonClick()
	configSetRemote:FireServer(defenderTeamNameField.Text, defenderTeamIconIdField.Text, raiderTeamNameField.Text, raiderTeamIconIdField.Text)
end

function funcs.handleStartStopButtonClick()
	startStopRaidRemote:FireServer()
end

function funcs.handleHideButtonClick()
	configPanel.Visible = false
	showButton.Visible = true
end

function funcs.handleShowButtonClick()
	configPanel.Visible = true
	showButton.Visible = false
end

-- set initial values for easier use
function funcs.setDefaultValues()
	local defenderTeam = TeamsConfig.StarterTeams[1]
	defenderTeamNameField.Text = defenderTeam.Name
	defenderTeamIconIdField.Text = tostring(defenderTeam.ImageAssetId)

	local raiderTeam = TeamsConfig.StarterTeams[2]
	raiderTeamNameField.Text = raiderTeam.Name
	raiderTeamIconIdField.Text = tostring(raiderTeam.ImageAssetId)
end

function funcs.hookButtons()
	hideButton.MouseButton1Click:Connect(funcs.handleHideButtonClick)
	showButton.MouseButton1Click:Connect(funcs.handleShowButtonClick)
	setButton.MouseButton1Click:Connect(funcs.handleSetButtonClick)
	startStopButton.MouseButton1Click:Connect(funcs.handleStartStopButtonClick)
end
funcs.hookButtons()

-- if player respawns, these values will become invalid
player.CharacterAdded:Connect(function(newCharacter: Model)
	character = newCharacter
	raidSystemGui = playerGui:WaitForChild("CombatSystemsPluginsGui"):WaitForChild("RaidSystemGui")
	raidConfigGui = raidSystemGui:WaitForChild("RaidConfigGui")
	configPanel = raidConfigGui:WaitForChild("ConfigPanel")
	infoContainer = configPanel:WaitForChild("InfoContainer")

	defenderTeamNameField = infoContainer:WaitForChild("DefenderTeamName")
	defenderTeamIconIdField = infoContainer:WaitForChild("DefenderTeamIconId")
	raiderTeamNameField = infoContainer:WaitForChild("RaiderTeamName")
	raiderTeamIconIdField = infoContainer:WaitForChild("RaiderTeamIconId")
	setButton = infoContainer:WaitForChild("ButtonsContainer"):WaitForChild("SetButton")
	startStopButton = infoContainer:WaitForChild("ButtonsContainer"):WaitForChild("StartStopButton")

	hideButton = configPanel:WaitForChild("HideButton")
	showButton = raidConfigGui:WaitForChild("ShowButton")
	funcs.hookButtons()
	funcs.setDefaultValues()
end)

funcs.setDefaultValues()

return module
