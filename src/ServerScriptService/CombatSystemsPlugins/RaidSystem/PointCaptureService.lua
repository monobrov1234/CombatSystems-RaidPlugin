--!strict

local module = {}
local funcs = {}

-- SERVICES
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Logger = require(ReplicatedStorage.CombatSystemsShared.Utils.LoggerUtil)
local RaidSystemConfig = require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Configs.RaidSystemConfig)
local TeamService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.TeamService)

-- FINALS
local log: Logger.SelfObject = Logger.new("PointCaptureService")

-- STATE
local captureProgressLoopThread: thread?
local captureDetectLoopThread: thread?
local running = false

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
local points = {} :: {
	[BasePart]: PointView,
}

-- PUBLIC API
function module.init()
	funcs.resetLoadRaidPoints()
end

function module.start()
	if running then return end
	running = true
	funcs.captureDetectLoop()
	funcs.captureProgressLoop()
end

function module.stop()
	if not running then return end
	running = false
	if captureProgressLoopThread then task.cancel(captureProgressLoopThread) end
	if captureDetectLoopThread then task.cancel(captureDetectLoopThread) end
	captureProgressLoopThread = nil
	captureDetectLoopThread = nil
	funcs.resetLoadRaidPoints()
end

function module.getCapturedPoints(teamName: string): { PointView }
	local capturedPoints = {} :: { PointView }
	for _, point in pairs(points) do
		if point.Info.OwningTeamProperty.Value == teamName then table.insert(capturedPoints, point) end
	end
	return capturedPoints
end

-- INTERNAL FUNCTIONS
-- will update capture percent on points
function funcs.captureProgressLoop()
	local speed = 0.1
	captureProgressLoopThread = task.spawn(function()
		while running do
			for _, point: PointView in pairs(points) do
				-- if no one is capturing - no progress changes
				if #point.State.CapturingPlayers == 0 then continue end
				-- if blocked - no progress changes
				if point.Info.BlockedProperty.Value then continue end

				local capturingTeam = point.Info.CapturingTeamProperty.Value -- initially, can be "" (no capturer) or a team value
				-- if the capturing team is empty, no progress changes
				if capturingTeam == "" then continue end
				-- now the capturing team is guaranteed to be non-empty

				local owningTeam = point.Info.OwningTeamProperty.Value -- initially, can be "" (no owner) or a team value
				-- if the owningTeam is empty, its value will be set to the capturing team value
				if owningTeam == "" then
					point.Info.OwningTeamProperty.Value = capturingTeam
					owningTeam = capturingTeam
				end
				-- now the owning team is guaranteed to be non-empty

				-- capturing team IS THE owning team, keep increasing progress to 100
				if capturingTeam == owningTeam and not point.State.Captured then -- if it's captured (full 100% progress, do nothing)
					point.Info.ProgressProperty.Value += funcs.calculatePercentPerSecond(#point.State.CapturingPlayers) * speed

					if point.Info.ProgressProperty.Value >= 100 then
						point.Info.ProgressProperty.Value = 100
						point.State.Captured = true
						log:debug("Point {} was captured by the team {}", point.Info.Name, owningTeam)
					end
				elseif capturingTeam ~= owningTeam then -- capturing team IS NOT the owning team - point needs to be cleared off from the owners first, decrease progress to 0
					point.Info.ProgressProperty.Value -= funcs.calculatePercentPerSecond(#point.State.CapturingPlayers) * speed
					point.State.Captured = false -- it's no longer captured

					if point.Info.ProgressProperty.Value <= 0 then
						point.Info.ProgressProperty.Value = 0

						-- make point neutral, reset the owning team
						point.Info.OwningTeamProperty.Value = ""
						log:debug("Point {} is now neutral by the team {}", point.Info.Name, capturingTeam)
					end
				end
			end

			task.wait(speed)
		end
	end)
end

-- will determine what players are currently capturing points, and update point states
function funcs.captureDetectLoop()
	captureDetectLoopThread = task.spawn(function()
		while running do
			for _, player: Player in ipairs(Players:GetPlayers()) do
				if not TeamService.getPlayerTeam(player) then continue end -- if the player has no team then he can't capture anything

				local character: Model? = player.Character
				local humanoid: Humanoid?
				local rootPart: BasePart?
				if character then
					humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
					rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				end

				-- check whether player is within any point's capture area
				for _, point: PointView in pairs(points) do
					local capturingIndex: number? = table.find(point.State.CapturingPlayers, player)

					-- validate player state
					local isInArea = humanoid
						and rootPart
						and humanoid:GetState() ~= Enum.HumanoidStateType.Dead
						and funcs.isPointInsidePart(point.Info.CaptureArea, rootPart.Position)

					if
						capturingIndex == nil -- ensure that the player is not capturing this point already
						and isInArea
					then -- ensure that the player is within the capture area
						-- player entered the capturing area
						log:debug("Player {} entered the point {}", player.Name, point.Info.Name)
						table.insert(point.State.CapturingPlayers, player)
					elseif capturingIndex ~= nil and not isInArea then
						-- player left from the capturing area
						log:debug("Player {} left the point {}", player.Name, point.Info.Name)
						table.remove(point.State.CapturingPlayers, capturingIndex)
					end
				end
			end

			for _, point: PointView in pairs(points) do
				-- ensure delete invalid players
				local invalidPlayers = {} :: { Player }
				for _, player: Player in ipairs(point.State.CapturingPlayers) do
					if player.Parent and TeamService.getPlayerTeam(player) and player.Character then continue end
					table.insert(invalidPlayers, player)
				end

				for _, player in ipairs(invalidPlayers) do
					log:debug("Player (invalid) {} left the point {}", player.Name, point.Info.Name)
					table.remove(point.State.CapturingPlayers, table.find(point.State.CapturingPlayers, player))
				end

				-- update point state
				funcs.updatePointState(point)
			end

			task.wait(0.5)
		end
	end)
end

function funcs.updatePointState(point: PointView)
	-- update player count
	point.Info.PlayersProperty.Value = #point.State.CapturingPlayers

	-- check that all players in the list are in a same team
	local foundSameTeam = ""
	local sameTeam = true
	for _, otherPlayer: Player in ipairs(point.State.CapturingPlayers) do
		local otherTeam = otherPlayer.Team :: Team -- guaranteed in captureDetectLoop
		if foundSameTeam == "" then foundSameTeam = otherTeam.Name end

		if otherTeam.Name ~= foundSameTeam then
			sameTeam = false
			break
		end
	end

	if sameTeam then -- if every player capturing this point are in a same team OR there is no players, unblock the point and set the capturing team to that team
		point.Info.BlockedProperty.Value = false
		point.Info.CapturingTeamProperty.Value = foundSameTeam -- here it can be either "" (empty) or a team name
	else -- if players capturing this point have different teams, point can't be captured
		point.Info.BlockedProperty.Value = true
		point.Info.CapturingTeamProperty.Value = "" -- empty string, no one is capturing now
	end
end

function funcs.calculatePercentPerSecond(peopleCount: number)
	if peopleCount <= 0 then return 0 end
	return RaidSystemConfig.CaptureConfig.PercentPerSecond * (1 + (peopleCount - 1) * RaidSystemConfig.CaptureConfig.AllySpeedMultiplier)
end

function funcs.isPointInsidePart(part: BasePart, worldPos: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(worldPos)
	local halfSize = part.Size * 0.5
	return math.abs(localPos.X) <= halfSize.X and math.abs(localPos.Y) <= halfSize.Y and math.abs(localPos.Z) <= halfSize.Z
end

-- load all raid points from the folder
function funcs.resetLoadRaidPoints()
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

return module
