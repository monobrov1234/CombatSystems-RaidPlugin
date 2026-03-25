export type StarterTeamType = {
	Name: string,
	Color: Color3, -- color of the team
	ImageAssetId: number, -- team image
	StartPoints: number, -- team initial points
}
local starterTeams = {} :: { StarterTeamType }

starterTeams[1] = {
	Name = "3ND",
	LayoutOrder = 0,
	Color = Color3.new(0, 1, 0.2),
	ImageAssetId = 5205790785,
	StartPoints = 0,
}

starterTeams[2] = {
	Name = "Raiders",
	LayoutOrder = 1,
	Color = Color3.new(1, 0.184314, 0.184314),
	ImageAssetId = 6244717634,
	StartPoints = 0,
}

return {
	MaxTeams = 4, -- overall max team count on the battlefield
	StarterTeams = starterTeams, -- initial team configuration, the game need a minimum of 2 teams to start, otherwise teams will need to be added through admin console
}
