local VoxelNode = {}

function VoxelNode.new(P: Vector3, G: number, H: number)
	local Node = {}
	G = G or -1
	H = H or -1
	local Node = {}
	Node.Position = P
	Node.Visited = -1
	Node.From = nil
	Node.G = G
	Node.H = H
	Node.HeapIndex = -1
	Node.Traversible = true
	Node.LinearReach = {} -- To reduce raycasting, we scan a node for a line, all visible nodes on that line can be computed quickly.

	-- eg {[Vector3.new(1,1,1)] = {StartingNode,50}}, where the second number is how far could have been scanned.
	function Node:GetF()
		return (Node.G + Node.H)
	end

	function Node:Equals(OtherNode)
		if Node.Position == OtherNode.Position or (Node.Position - OtherNode.Position).Magnitude < 0.001 then
			return true
		end
	end

	function Node:Compare(OtherNode, greedy) -- positive (or 0)  means >= 0 , negative means < 0
		local result

		if not greedy then
			result = Node:GetF() - OtherNode:GetF()
		else
			result = Node.H - OtherNode.H
		end

		if result == 0 then
			result = Node.H - OtherNode.H
		end

		return result
	end

	return Node
end
return VoxelNode
