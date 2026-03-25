--!strict

local module = {}
local funcs = {}

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local RaidSystemConfig = require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Configs.RaidSystemConfig)

-- ROBLOX OBJECTS
local player = Players.LocalPlayer :: Player
local playerGui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()

local raidSystemGui = playerGui:WaitForChild("CombatSystemsPluginsGui"):WaitForChild("RaidSystemGui")
local raidStatGui = raidSystemGui:WaitForChild("RaidStatGui")
local pointGui = raidStatGui:WaitForChild("CapturePoints")
local pointTemplate = pointGui:WaitForChild("PointTemplate")

local raidPointFolder = RaidSystemConfig.RaidPointFolder

-- FINALS
local raidPoints = {} :: { BasePart }

-- PUBLIC API
function module.addPoint(point: BasePart)
	point:WaitForChild("Capture") -- ensure that the capture part is present
	funcs.createTemplateForPoint(point)
	table.insert(raidPoints, point)
end

function module.removePoint(point: BasePart)
	for i, target: BasePart in ipairs(raidPoints) do
		if target ~= point then continue end
		local gui = pointGui:FindFirstChild(point.Name)
		if gui then gui:Destroy() end
		table.remove(raidPoints, i)
		break
	end
end

-- INTERNAL FUNCTIONS
function funcs.handleHeartbeat()
	for _, point: BasePart in ipairs(raidPoints) do
		local captureProgress = point:FindFirstChild("CaptureProgress") :: NumberValue
		local owningTeam = point:FindFirstChild("OwningTeam") :: StringValue
		if not captureProgress or not owningTeam then continue end

		local gui = pointGui:FindFirstChild(point.Name) :: typeof(pointTemplate)?
		if not gui then continue end

		gui.CaptureProgress.Size = UDim2.new(1, 0, captureProgress.Value / 100, 0)

		local owningTeam = Teams:FindFirstChild(owningTeam.Value) :: Team?
		if owningTeam then gui.CaptureProgress.BackgroundColor3 = owningTeam.TeamColor.Color end
	end
end

function funcs.createTemplateForPoint(point: BasePart)
	local templateClone = pointTemplate:Clone()
	templateClone.Name = point.Name
	templateClone.NameLabel.Text = point.Name
	templateClone.CaptureProgress.Size = UDim2.new(1, 0, 0, 0)
	templateClone.Visible = true
	templateClone.Parent = pointGui
end

RunService.Heartbeat:Connect(funcs.handleHeartbeat)

-- scan raid point folder
for _, point: Instance in ipairs(raidPointFolder:GetChildren()) do
	if not point:IsA("BasePart") then continue end
	module.addPoint(point)
end

-- hook childadded and childremoved
raidPointFolder.ChildAdded:Connect(function(point: Instance)
	if not point:IsA("BasePart") then return end
	module.addPoint(point)
end)
raidPointFolder.ChildRemoved:Connect(function(point: Instance)
	if not point:IsA("BasePart") then return end
	module.removePoint(point)
end)

-- if player respawns, these values will become invalid
player.CharacterAdded:Connect(function(newCharacter: Model)
	character = newCharacter
	raidSystemGui = playerGui:WaitForChild("CombatSystemsPluginsGui"):WaitForChild("RaidSystemGui")
	raidStatGui = raidSystemGui:WaitForChild("RaidStatGui")
	pointGui = raidStatGui:WaitForChild("CapturePoints")
	pointTemplate = pointGui:WaitForChild("PointTemplate")

	-- readd the point templates
	for _, point: BasePart in ipairs(raidPoints) do
		funcs.createTemplateForPoint(point)
	end
end)

return module
