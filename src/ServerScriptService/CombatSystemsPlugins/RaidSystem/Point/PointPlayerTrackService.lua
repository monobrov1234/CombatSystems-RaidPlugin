-- This service is responsible for tracking players who are currently capturing points, and updating point states accordingly.
--!strict

local module = {}
local funcs = {}

-- SERVICES
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PointStoreService = require(script.Parent.PointStoreService)
local Logger = require(ReplicatedStorage.CombatSystemsShared.Utils.LoggerUtil)
local TeamStoreService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.Team.TeamStoreService)

-- FINALS
local log: Logger.SelfObject = Logger.new("PointPlayerTrackService")

-- STATE
local trackThread: thread?
local running = false

function module.start()
	if running then return end
	running = true
	funcs.startTrackLoop()
end

function module.stop()
	if not running then return end
	running = false
	if trackThread then task.cancel(trackThread) end
	trackThread = nil
end

function funcs.startTrackLoop()
	trackThread = task.spawn(function()
		while running do
			funcs.updateCapturingPlayers()
			funcs.updatePointStates()
			task.wait(0.5)
		end
	end)
end

function funcs.updateCapturingPlayers()
	-- add new players
	for _, player: Player in ipairs(Players:GetPlayers()) do
		for _, point: PointStoreService.PointView in pairs(PointStoreService.getPoints()) do
			if table.find(point.State.CapturingPlayers, player) == nil then continue end -- already capturing
			if not funcs.isPlayerCanCapture(player, point) then continue end -- invalid state

			log:debug("Player {} entered the point {}", player.Name, point.Info.Name)
			table.insert(point.State.CapturingPlayers, player)
		end
	end

	-- clear old players (not in area, dead, kicked, not in any team)
	for _, point: PointStoreService.PointView in pairs(PointStoreService.getPoints()) do
		local invalidPlayers = {} :: { Player }
		for _, player: Player in ipairs(point.State.CapturingPlayers) do
			if not funcs.isPlayerCanCapture(player, point) then continue end
			table.insert(invalidPlayers, player)
		end

		for _, player in ipairs(invalidPlayers) do
			log:debug("Player {} left the point {}", player.Name, point.Info.Name)
			table.remove(point.State.CapturingPlayers, table.find(point.State.CapturingPlayers, player))
		end
	end
end

function funcs.updatePointStates()
	for _, point: PointStoreService.PointView in pairs(PointStoreService.getPoints()) do
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
end

function funcs.isPointInsidePart(part: BasePart, worldPos: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(worldPos)
	local halfSize = part.Size * 0.5
	return math.abs(localPos.X) <= halfSize.X and math.abs(localPos.Y) <= halfSize.Y and math.abs(localPos.Z) <= halfSize.Z
end

function funcs.isPlayerCanCapture(player: Player, point: PointStoreService.PointView): boolean
	if not player.Parent then return false end -- kicked?
	if not TeamStoreService.getPlayerTeam(player) then return false end -- doesn't have team?

	local character: Model? = player.Character
	if not character then return false end -- not loaded?
	local humanoid: Humanoid? = character:FindFirstChildOfClass("Humanoid")
	local rootPart: BasePart? = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart or humanoid:GetState() == Enum.HumanoidStateType.Dead then return false end -- dead?

	local isInArea = funcs.isPointInsidePart(point.Info.CaptureArea, rootPart.Position)
	if not isInArea then return false end -- not in point area

	return true
end

return module