return {
	RaidPointFolder = workspace:WaitForChild("RaidPoints"),
	RaidPointNameAttribute = "RaidPointName", -- used to specify name of the point

	TeamScoreConfig = {
		ScoreToWin = 4000, -- the team that first reaches this score value will win the raid
		IncomePerPoint = 4, -- how much score per second will be awarded to a team per one captured point
	},

	CaptureConfig = {
		PercentPerSecond = 10, -- point capture speed
		AllySpeedMultiplier = 1, -- how much will other people increase capture speed, final speed is calculated using (PercentPerSecond * (1 + (peopleCount - 1) * AllySpeedMultiplier)
		-- 0 = no increase, >0 = each player adds N * PercentPerSecond linearly
	},
}
