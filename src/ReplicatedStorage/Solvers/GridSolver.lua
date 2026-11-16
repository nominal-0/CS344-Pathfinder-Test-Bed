local GridSolver = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VoxelHeap = require(ReplicatedStorage.Classes.VoxelHeap)
local VoxelNode = require(ReplicatedStorage.Classes.VoxelNode)
local AdjacencyGrid = require(ReplicatedStorage.Preprocessors.AdjacencyGrid)
print("Testing")

local RunService = game:GetService("RunService")

local i = Vector3.new(1, 0, 0)
local j = Vector3.new(0, 1, 0)
local k = Vector3.new(0, 0, 1)

function GridSolver:SimplifyPath(path)
	local i = 1
	while i + 2 <= #path do
		local P0 = path[i].Position
		local P1 = path[i + 1].Position
		local P2 = path[i + 2].Position

		if (P0 - P1).Unit == (P1 - P2).Unit then
			table.remove(path, i + 1)
		else
			i += 1
		end
	end
end

function GridSolver.new(boundaries, density: number, raycastParams: RaycastParams, Debug: boolean)
	local Solver = {}
	Solver.MaxNodeExpansionsPerFrame = 200
	Solver.MaxIterations = 2000

	local Grid, Cache = AdjacencyGrid.new(boundaries, density, raycastParams, Debug)

	Solver.Grid = Grid
	Solver.Cache = Cache

	function Solver:GetPath(A, B, d, greedy)
		if not (Grid:IsPointBounded(A) and Grid:IsPointBounded(B)) then
			if Debug then
				Solver:Out("points are not contained")
			end
			return
		end

		local Start = Grid:SnapToGrid(A, true)
		local Goal = Grid:SnapToGrid(B, true)

		if not (Start and Goal) then
			if Debug then
				Solver:Out("points can not be resolved", Start, Goal)
			end

			return
		end

		local StartingNode = VoxelNode.new(Start, 0, d(Start, Goal))
		local GoalNode = VoxelNode.new(Goal, d(Goal, Start), 0)

		local OpenSet = VoxelHeap.new(greedy)
		OpenSet:AddNode(StartingNode)

		local OpenLookUp = {}
		local ClosedLookUp = {}

		local iterations = 0
		local timeStart = os.clock()
		local maxIterations = Solver.MaxIterations

		local CurrentNode = nil

		while OpenSet.size ~= 0 and iterations <= maxIterations do
			iterations += 1
			CurrentNode = OpenSet:RemoveMin()
			--
			if Grid:IsVisible(CurrentNode.Position, GoalNode.Position) then
				GoalNode.From = CurrentNode
				CurrentNode = GoalNode
			end

			if CurrentNode:Equals(GoalNode) then
				if Debug then
					Solver:Out(
						"Path found in",
						os.clock() - timeStart,
						"seconds with",
						iterations,
						"iterations",
						"Open set had",
						OpenSet.size,
						"candidates"
					)
				end

				local finalNodeSequence = {}
				repeat
					table.insert(finalNodeSequence, CurrentNode)
					CurrentNode = CurrentNode.From
				until not CurrentNode

				for i = 1, math.floor(#finalNodeSequence / 2) do
					local j = #finalNodeSequence - i + 1
					finalNodeSequence[i], finalNodeSequence[j] = finalNodeSequence[j], finalNodeSequence[i]
				end
				GridSolver:SimplifyPath(finalNodeSequence)
				return finalNodeSequence
			end

			-- A* Implementation

			for y = -1, 1 do
				for z = -1, 1 do
					for x = -1, 1 do
						if Vector3.new(x, y, z) == Vector3.zero then
							continue
						end

						local DIR = Vector3.new(x, y, z) * (i + j + k)

						if Grid[CurrentNode.Position][2] ~= Grid.VersionID then
							Grid[CurrentNode.Position][2] = Grid.VersionID
							Grid[CurrentNode.Position][1] = Cache[CurrentNode.Position][1]
						end

						if not Grid[CurrentNode.Position][1][Vector3.new(x, y, z)] then
							continue
						end

						local Position = Grid[CurrentNode.Position][1][Vector3.new(x, y, z)]
						local potentialG = CurrentNode.G + d(Position, CurrentNode.Position)
						local potentialH = d(Position, Goal)

						if not (ClosedLookUp[Position] or OpenLookUp[Position]) then
							local NewNode = VoxelNode.new(Position, potentialG, potentialH)
							OpenSet:AddNode(NewNode)
							OpenLookUp[Position] = NewNode

							NewNode.From = CurrentNode
						elseif not greedy then
							local focusNode = nil

							if OpenLookUp[Position] then
								focusNode = OpenLookUp[Position]
								if focusNode and potentialG < focusNode.G then
									focusNode.From = CurrentNode
									OpenSet:Update(focusNode, potentialG)
								end
							end
						end
					end
				end
			end
			--
			OpenLookUp[CurrentNode.Position] = nil

			ClosedLookUp[CurrentNode.Position] = CurrentNode

			if iterations % Solver.MaxNodeExpansionsPerFrame == 0 then
				RunService.Heartbeat:Wait()
			end

			CurrentNode = nil
		end
		if Debug then
			Solver:Out(iterations)
		end

		return nil
	end

	function Solver:Out(...)
		if Debug then
			print(...)
		end
	end

	return Solver
end

return GridSolver
