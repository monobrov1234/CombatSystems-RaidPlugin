--!strict

local module = {}

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.CombatSystemsShared.Utils.LoggerUtil)
local RaidSystemConfig = require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Configs.RaidSystemConfig)

-- FINALS
local log: Logger.SelfObject = Logger.new("PointStoreService")

-- STATE
export type PointInfo = {
	Name: string,
	Body: BasePart,
	CaptureArea: BasePart,
	OwningTeamProperty: StringValue,
	CapturingTeamProperty: StringValue,
	ProgressProperty: NumberValue,
	PlayersProperty: NumberValue,
	BlockedProperty: BoolValue,
}
export type PointStateInfo = {
	CapturingPlayers: { Player },
	Captured: boolean,
}
export type PointView = {
	Info: PointInfo,
	State: PointStateInfo,
}
local points = {} :: { [BasePart]: PointView }

-- PUBLIC API
-- load all raid points from the folder
function module.loadRaidPoints()
	for _, point: Instance in ipairs(RaidSystemConfig.RaidPointFolder:GetChildren()) do
		assert(point:IsA("BasePart"), "Raid point must be a BasePart")
		local name: string? = point:GetAttribute(RaidSystemConfig.RaidPointNameAttribute)
		assert(name, "Raid point must have a name attribute")

		local captureArea = point:FindFirstChild("Capture") :: BasePart?
		assert(captureArea and captureArea:IsA("BasePart"), "Raid point capture area not found")

		-- clear all old values
		for _, child: Instance in point:GetChildren() do
			if child:IsA("ValueBase") then child:Destroy() end
		end

		-- create properties
		local owningTeamProperty = Instance.new("StringValue")
		owningTeamProperty.Name = "OwningTeam"
		local capturingTeamProperty = Instance.new("StringValue")
		capturingTeamProperty.Name = "CapturingTeam"
		local progressProperty = Instance.new("NumberValue")
		progressProperty.Name = "CaptureProgress"
		local playersProperty = Instance.new("NumberValue")
		playersProperty.Name = "CapturingPlayers"
		local blockedProperty = Instance.new("BoolValue")
		blockedProperty.Name = "Blocked"

		owningTeamProperty.Parent = point
		capturingTeamProperty.Parent = point
		progressProperty.Parent = point
		playersProperty.Parent = point
		blockedProperty.Parent = point

		local info: PointInfo = {
			Name = name,
			Body = point,
			CaptureArea = captureArea,
			OwningTeamProperty = owningTeamProperty,
			CapturingTeamProperty = capturingTeamProperty,
			ProgressProperty = progressProperty,
			PlayersProperty = playersProperty,
			BlockedProperty = blockedProperty,
		}
		local state: PointStateInfo = {
			CapturingPlayers = {},
			Captured = false,
		}

		points[point] = {
			Info = info,
			State = state,
		}
	end
end

function module.getCapturedPoints(teamName: string): { PointView }
	local capturedPoints = {} :: { PointView }
	for _, point in pairs(points) do
		if point.Info.OwningTeamProperty.Value == teamName then table.insert(capturedPoints, point) end
	end
	return capturedPoints
end

function module.getPoints(): typeof(points)
	return points
end

return module