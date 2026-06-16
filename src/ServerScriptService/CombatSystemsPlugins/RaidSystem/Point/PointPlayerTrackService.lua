-- This service is responsible for tracking players who are currently capturing points, and updating point states accordingly.
--!strict

local module = {}
local funcs = {}

-- SERVICES
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PointService = require(script.Parent.PointService)
local Logger = require(ReplicatedStorage.CombatSystemsShared.Utils.LoggerUtil)
local TeamService = require(ServerScriptService.CombatSystemsPlugins.RaidSystem.TeamService)

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
				for _, point: PointService.PointView in pairs(PointService.getPoints()) do
					local capturingIndex: number? = table.find(point.State.CapturingPlayers, player)

					-- validate player state
					local isInArea = humanoid
						and rootPart
						and humanoid:GetState() ~= Enum.HumanoidStateType.Dead
						and funcs.isPointInsidePart(point.Info.CaptureArea, rootPart.Position)

					if
						capturingIndex == nil -- ensure that the player is not capturing this point already
						and isInArea -- ensure that the player is within the capture area
					then
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

			for _, point: PointService.PointView in pairs(PointService.getPoints()) do
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

function funcs.updatePointState(point: PointService.PointView)
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

function funcs.isPointInsidePart(part: BasePart, worldPos: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(worldPos)
	local halfSize = part.Size * 0.5
	return math.abs(localPos.X) <= halfSize.X and math.abs(localPos.Y) <= halfSize.Y and math.abs(localPos.Z) <= halfSize.Z
end

return module