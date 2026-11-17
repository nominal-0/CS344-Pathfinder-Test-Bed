local LocalStorageService = game:GetService("LocalStorageService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GridSolver = require(ReplicatedStorage.Solvers.GridSolver)
local OctreeSolver = require(ReplicatedStorage.Solvers.OctreeSolver)

local boundaries = ReplicatedStorage.TestRegion:GetChildren()
local boundaryPart = ReplicatedStorage.TestRegion.TestRegion

local density = 1 / 16

local RCP = RaycastParams.new()
RCP.FilterType = Enum.RaycastFilterType.Exclude
RCP.FilterDescendantsInstances = { workspace.Debug, workspace.Start, workspace.Goal }

local OP = OverlapParams.new()
OP.FilterType = Enum.RaycastFilterType.Exclude
OP.FilterDescendantsInstances = { workspace.Debug, workspace.Start, workspace.Goal }
local Solver = OctreeSolver.new(boundaryPart, 5, OP, true)
print(Solver.Tree)
--[[
local Solver = GridSolver.new(boundaries, density, RCP, true)

Solver.MaxIterations *= 2
local function dist(A, B)
	return (math.abs(A.X - B.X) + workspace.Gravity * math.abs(A.Y - B.Y) ^ 2 + math.abs(A.Z - B.Z))
end

local lastGridPosition = nil

local function pathlogic()
	local gridPosition = workspace.Goal.Position
	if gridPosition == lastGridPosition then
		return
	end

	workspace.Debug.PathNodes:ClearAllChildren()
	lastGridPosition = gridPosition
	local path = Solver:GetPath(workspace.Start.Position, workspace.Goal.Position, dist, false)

	if not path then
		--print("Path too expensive...")
	else
		local Parts = {}
		for _, v in pairs(path) do
			local P0 = ReplicatedStorage.VisPart:Clone()
			P0.Parent = workspace.Debug.PathNodes
			P0.Position = v.Position
			table.insert(Parts, P0)
			local A0 = Instance.new("Attachment")
			A0.Name = "PathAtt"
			A0.Parent = P0
			local Beam = Instance.new("Beam")
			Beam.Parent = P0
			Beam.FaceCamera = true
			Beam.Brightness = 10
			Beam.LightInfluence = 0
			Beam.Width0 = 0.25
			Beam.Width1 = 0.25
		end
		for i = 1, #path - 1 do
			--print(i)
			local P0 = Parts[i]
			local P1 = Parts[i + 1]
			local Beam: Beam = P0.Beam
			Beam.Attachment0 = P0.PathAtt
			Beam.Attachment1 = P1.PathAtt
			task.wait(0.1)
		end
	end
end
--]]

--[[
while true do
	pathlogic()

	task.wait(10)
end
game:GetService("RunService").Heartbeat:Connect(function()
	if #game.Players:GetPlayers() > 0 and game.Players:GetPlayers()[1].Character then
		local part = game.Players:GetPlayers()[1].Character:FindFirstChild("Head")
		if part then
			--workspace.Goal.Position = part.Position +Vector3.yAxis*2
		end
	end
end)
-]]
--[[  

for _,b in pairs(workspace.TeamBeacons:GetChildren()) do
	Grid:AddEntity(b)
end

Grid:AddEntity(workspace["Rotating Obby Part"])
while true do
	if #game.Players:GetPlayers() > 0 and game.Players:GetPlayers()[1].Character then
		Grid:AddEntity(game.Players:GetPlayers()[1].Character)
	end
	
	pathlogic()

	task.wait(0.1)
end


]]
