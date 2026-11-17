local OctreeNode = {}

function OctreeNode.new(nodeCFrame, nodeSize, Debug)
	local Node = {}
	Node.OccupationLevel = 0 -- 0 = Free, 1 = Partially Occupied , 2 = Fully Occupied
	Node.ID = -1
	Node.Depth = -1
	Node.Parent = nil
	Node.Children = {}
	Node.CFrame = nodeCFrame
	Node.Size = nodeSize

	Node.DebugPart = nil

	if Debug then
		local part = Instance.new("Part")
		Node.DebugPart = part
		part.Transparency = 1
		local SelectionBox = Instance.new("SelectionBox")
		SelectionBox.Parent = part
		SelectionBox.Color3 = Color3.new(0, 1, 0)
		SelectionBox.LineThickness = 0.05
		SelectionBox.Adornee = part
		part.Parent = workspace.Debug.OctreeNodes
		part.CFrame = Node.CFrame
		part.Size = Node.Size
		part.CanCollide = false
		part.Anchored = true
	end
	return Node
end
return OctreeNode
