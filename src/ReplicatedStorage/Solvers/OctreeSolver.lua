local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Octree = require(ReplicatedStorage.Preprocessors.Octree)
local OctreeSolver = {}

function OctreeSolver.new(boundaryPart, depth, overlapParams, Debug)
	local Solver = {}
	local Tree = Octree.new(boundaryPart, depth, overlapParams, Debug)
	Solver.Tree = Tree
	return Solver
end

return OctreeSolver
