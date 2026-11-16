local VoxelHeap = {} -- many credits to lolekic (Suphi Kaner disc server) for his heap script, from which this is basically inspired from

function VoxelHeap.new(greedy)
	local Heap = {}

	Heap.Greedy = greedy
	Heap.data = {}
	Heap.size = 0

	function Heap:AddNode(newNode)
		--("Adding node",newNode.Position)
		self.size += 1
		self.data[self.size] = newNode
		newNode.HeapIndex = self.size
		self:UpHeap(newNode)

		return Heap
	end

	function Heap:RemoveMin()
		if self.size <= 0 then
			return
		end

		local minNode = self.data[1]
		local lastNode = self.data[self.size]
		self:Swap(minNode, lastNode)
		self.data[self.size] = nil
		self.size -= 1

		self:DownHeap(lastNode)

		minNode.HeapIndex = -1

		return minNode
	end

	function Heap:Update(node, newG)
		node.G = newG

		if node.HeapIndex > 0 then
			self:UpHeap(node)
		end
	end

	function Heap:Swap(node1, node2)
		self.data[node1.HeapIndex], self.data[node2.HeapIndex] = node2, node1
		node1.HeapIndex, node2.HeapIndex = node2.HeapIndex, node1.HeapIndex
	end

	function Heap:DownHeap(newNode) -- impose heap order, aka after a node has been removed.
		while true do
			local left = newNode.HeapIndex * 2
			local right = left + 1

			if left <= self.size then
				local toSwap = left

				if right <= self.size and self.data[right]:Compare(self.data[left], self.Greedy) < 0 then
					toSwap = right
				end

				if newNode:Compare(self.data[toSwap], self.Greedy) >= 0 then
					self:Swap(newNode, self.data[toSwap])
				else
					break
				end
			else
				break
			end
		end
	end

	function Heap:UpHeap(newNode) -- impose heap order, aka after a node has been updated, this happens if and only if the F cost is reduced.
		while newNode.HeapIndex > 1 do
			local parentNode = self.data[math.floor(newNode.HeapIndex / 2)]

			if newNode:Compare(parentNode, self.Greedy) < 0 then
				self:Swap(newNode, parentNode)
			else
				break
			end
		end
	end

	function Heap:Heapify(newNode)
		for i = (self.size // 2), 1, -1 do
			self:DownHeap(self.data[i])
		end
	end

	function Heap:Compare(otherHeap)
		if (otherHeap.data[1] == nil and self.data[1]) or (otherHeap.data[1] == nil and self.data[1] == nil) then
			-- aka if we have data but they dont, or we both dont have data, dont swap.
			return -1
		elseif otherHeap.data[1] and self.data[1] == nil then
			-- aka if we dont have data, but they do, swap us
			return 1
		else
			-- else directly compare minimum elements.
			return self.data[1]:Compare(otherHeap.data[1], self.Greedy)
		end
	end

	return Heap
end
return VoxelHeap
