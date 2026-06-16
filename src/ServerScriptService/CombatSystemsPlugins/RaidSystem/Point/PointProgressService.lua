-- This service is responsible for the percent progress logic of the points.
--!strict

local module = {}
local funcs = {}

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PointService = require(script.Parent.PointService)
local Logger = require(ReplicatedStorage.CombatSystemsShared.Utils.LoggerUtil)
local RaidSystemConfig = require(ReplicatedStorage.CombatSystemsPlugins.RaidSystem.Configs.RaidSystemConfig)

-- FINALS
local log: Logger.SelfObject = Logger.new("PointProgressService")

-- STATE
local progressLoopThread: thread?
local running = false

-- PUBLIC API
function module.start()
	if running then return end
	running = true
	funcs.startProgressLoop()
end

function module.stop()
	if not running then return end
	running = false
	if progressLoopThread then task.cancel(progressLoopThread) end
	progressLoopThread = nil
end

-- INTERNAL FUNCTIONS
-- will update capture percent on points
function funcs.startProgressLoop()
	local speed = 0.1
	progressLoopThread = task.spawn(function()
		while running do
			for _, point: PointService.PointView in pairs(PointService.getPoints()) do
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

function funcs.calculatePercentPerSecond(peopleCount: number)
	if peopleCount <= 0 then return 0 end
	return RaidSystemConfig.CaptureConfig.PercentPerSecond * (1 + (peopleCount - 1) * RaidSystemConfig.CaptureConfig.AllySpeedMultiplier)
end

return module