return {
	RaidPointFolder = workspace:WaitForChild("RaidPoints"),
	RaidPointNameAttribute = "RaidPointName", -- used to specify name of the point

	TeamScoreConfig = {
		ScoreToWin = 4000, -- the team that first reaches this score value will win the raid
		IncomePerPoint = 4, -- how much score per second will be awarded to a team per one captured point
	},

	-- CAPTURE
	CaptureConfig = {
		PercentPerSecond = 10, -- capture percent per second speed
		AllySpeedMultiplier = 1, -- how much will other people increase capture speed, final speed is calculated using formula PercentPerSecond * (1 + (peopleCount - 1) * AllySpeedMultiplier
	},
}
