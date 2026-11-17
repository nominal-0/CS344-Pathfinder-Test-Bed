local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OctreeNode = require(ReplicatedStorage.Classes.OctreeNode)
local Octree = {}

local function isPointBounded(point: Vector3, boundCFrame: CFrame, boundSize: Vector3)
	point = boundCFrame:PointToObjectSpace(point) -- convert to local
	return (math.abs(point.X) <= boundSize.X / 2)
		and (math.abs(point.Y) <= boundSize.Y / 2)
		and (math.abs(point.Z) <= boundSize.Z / 2)
end

local function getCorners(cf, size)
	local corners = {}

	-- helper cframes for intermediate steps
	-- before finding the corners cframes.
	-- With corners I only need cframe.Position of corner cframes.

	-- face centers - 2 of 6 faces referenced
	local frontFaceCenter = (cf + cf.LookVector * size.Z / 2)
	local backFaceCenter = (cf - cf.LookVector * size.Z / 2)

	-- edge centers - 4 of 12 edges referenced
	local topFrontEdgeCenter = frontFaceCenter + frontFaceCenter.UpVector * size.Y / 2
	local bottomFrontEdgeCenter = frontFaceCenter - frontFaceCenter.UpVector * size.Y / 2
	local topBackEdgeCenter = backFaceCenter + backFaceCenter.UpVector * size.Y / 2
	local bottomBackEdgeCenter = backFaceCenter - backFaceCenter.UpVector * size.Y / 2

	-- corners
	corners.topFrontRight = (topFrontEdgeCenter + topFrontEdgeCenter.RightVector * size.X / 2).Position
	corners.topFrontLeft = (topFrontEdgeCenter - topFrontEdgeCenter.RightVector * size.X / 2).Position

	corners.bottomFrontRight = (bottomFrontEdgeCenter + bottomFrontEdgeCenter.RightVector * size.X / 2).Position
	corners.bottomFrontLeft = (bottomFrontEdgeCenter - bottomFrontEdgeCenter.RightVector * size.X / 2).Position

	corners.topBackRight = (topBackEdgeCenter + topBackEdgeCenter.RightVector * size.X / 2).Position
	corners.topBackLeft = (topBackEdgeCenter - topBackEdgeCenter.RightVector * size.X / 2).Position

	corners.bottomBackRight = (bottomBackEdgeCenter + bottomBackEdgeCenter.RightVector * size.X / 2).Position
	corners.bottomBackLeft = (bottomBackEdgeCenter - bottomBackEdgeCenter.RightVector * size.X / 2).Position

	return corners
end

function Octree.new(boundaryPart, depth, overlapParams, Debug)
	local Tree = {}

	Tree.MaxDepth = depth
	Tree.Root = nil
	local rootNode = OctreeNode.new(boundaryPart.CFrame, boundaryPart.Size, Debug)
	rootNode.Depth = 0
	Tree.Root = rootNode
	function Tree.split(node, currentDepth)
		local boundedParts = workspace:GetPartBoundsInBox(node.CFrame, node.Size, overlapParams)

		local canSplit = true

		if #boundedParts == 0 then
			canSplit = false
		else
			node.OccupationLevel = 1
			if Debug then
				node.DebugPart.SelectionBox.Color3 = Color3.new(1, 0.4, 0)
				node.DebugPart.SelectionBox.LineThickness = 0.15
			end

			for _, p in pairs(boundedParts) do
				if (node.Size.X <= p.Size.X) and (node.Size.Y <= p.Size.Y) and (node.Size.Z <= p.Size.Z) then
					local corners = getCorners(node.CFrame, node.Size)
					local cornerCount = 0
					for _, corner in pairs(corners) do
						if isPointBounded(corner, p.CFrame, p.Size) then
							cornerCount += 1
						end
					end
					if cornerCount == 8 then
						node.OccupationLevel = 2
						canSplit = false
						if Debug then
							node.DebugPart.SelectionBox.Color3 = Color3.new(1, 0, 0)
							node.DebugPart.SelectionBox.LineThickness = 0.15
						end

						break
					end
				end
			end
		end

		if currentDepth > Tree.MaxDepth then
			canSplit = false
		end

		if canSplit then
			local size = node.Size / 2
			local offset = node.Size / 4
			local center = node.CFrame.Position
			for i = 0, 7 do
				local x = center.x + offset.x * ((i % 2 == 0) and -1 or 1)
				local y = center.y + offset.y * ((math.floor(i / 2) % 2 == 0) and -1 or 1)
				local z = center.z + offset.z * ((math.floor(i / 4) % 2 == 0) and -1 or 1)

				local newNode = OctreeNode.new(node.CFrame.Rotation + Vector3.new(x, y, z), size, Debug)
				newNode.Depth = depth
				newNode.Parent = node
				node.Children[newNode] = true

				if Debug then
					task.wait()
				end

				Tree.split(newNode, currentDepth + 1)
			end
		end
	end
	Tree.split(Tree.Root, 1)

	return Tree
end

return Octree
