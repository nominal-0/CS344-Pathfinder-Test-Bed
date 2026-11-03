local BakeStar = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VoxelHeap = require(ReplicatedStorage.VoxelHeap)
local VoxelNode = require(ReplicatedStorage.VoxelNode)
print("Testing")
local Debug = false

local RunService = game:GetService("RunService")

function BakeStar.IsInRegion(position: Vector3, brick: BasePart)
	local v3 = brick.CFrame:PointToObjectSpace(position)
	return (math.abs(v3.X) <= brick.Size.X / 2)
		and (math.abs(v3.Y) <= brick.Size.Y / 2)
		and (math.abs(v3.Z) <= brick.Size.Z / 2)
end

function BakeStar.Bake(boundaries, density: number, raycastParams: RaycastParams, grounded: boolean)
	local Grid = {}
	local Cache = {}
	Grid.VersionID = 0
	Grid.Entities = {}
	Grid.UpdateRate = 1 -- in Hz
	Grid.MaxNodeExpansionsPerFrame = 200
	Grid.MaxIterations = 2000
	Grid.MaxUpdateNodesPerFrame = 20
	local i = Vector3.new(1, 0, 0)
	local j = Vector3.new(0, 1, 0)
	local k = Vector3.new(0, 0, 1)

	local accumulator = 0
	local UpdateConnection

	function Grid:IsPointBounded(point: Vector3)
		for _, part in pairs(boundaries) do
			if not BakeStar.IsInRegion(point, part) then
				return false
			end
		end
		return true
	end
	function Grid:IsPointContained(Pos, A, B) -- Credit to unix_system
		return (Pos.X < math.max(A.X, B.X) and Pos.X > math.min(A.X, B.X))
			and (Pos.Y < math.max(A.Y, B.Y) and Pos.Y > math.min(A.Y, B.Y))
			and (Pos.Z < math.max(A.Z, B.Z) and Pos.Z > math.min(A.Z, B.Z))
	end

	function Grid:IsVisible(A, B)
		local R1
		local R2
		R1 = workspace:Raycast(B, A - B, raycastParams)
		R2 = workspace:Raycast(A, B - A, raycastParams)

		if R1 or R2 then
			return false
		end
		return true
	end

	function Grid:SnapToGrid(P0: Vector3, travelCheck, boundBypass)
		if not (self:IsPointBounded(P0) or boundBypass) then
			return
		end

		local Direction = P0
		local c_dX = math.floor(Direction:Dot(i) * density + 0.5)
		local c_dY = math.floor(Direction:Dot(j) * density + 0.5)
		local c_dZ = math.floor(Direction:Dot(k) * density + 0.5)
		local Position = (Vector3.new(c_dX, c_dY, c_dZ) * Vector3.new(1, 1, 1)) / density

		if travelCheck then
			local V, C
			local Original = Position
			local bestDist = math.huge
			local bestPosition
			for y = -1, 1 do
				for z = -1, 1 do
					for x = -1, 1 do
						local offset = Vector3.new(x, y, z) / density
						Position = Original + offset
						V = self:IsVisible(P0, Position)
						C = self:IsPointBounded(Position)
						if V and C then
							local dist = (P0 - Position).Magnitude
							if dist < bestDist then
								bestDist = dist
								bestPosition = Position
							end
						end
					end
				end
			end
			return bestPosition
		end

		return Position
	end

	function Grid:ComputeEdgeValidationSet(point: Vector3)
		local edgeValidationSet = {}
		for dX = -1, 1 do
			for dY = -1, 1 do
				for dZ = -1, 1 do
					if Vector3.new(dX, dY, dZ) == Vector3.zero then
						continue
					end
					local newPoint = Grid:SnapToGrid(point + Vector3.new(dX, dY, dZ) / density)

					if newPoint and Grid:IsVisible(point, newPoint) then
						edgeValidationSet[Vector3.new(dX, dY, dZ)] = newPoint
					end
				end
			end
		end
		return edgeValidationSet
	end

	for _, part in pairs(boundaries) do
		local cframe = part.CFrame
		local halfsize = part.Size / 2
		local corner1 = cframe:ToWorldSpace(CFrame.new(-halfsize)).Position
		local corner2 = cframe:ToWorldSpace(CFrame.new(halfsize)).Position

		for x = math.min(corner1.x, corner2.x), math.max(corner1.x, corner2.x), 1 / density do
			for y = math.min(corner1.y, corner2.y), math.max(corner1.y, corner2.y), 1 / density do
				for z = math.min(corner1.z, corner2.z), math.max(corner1.z, corner2.z), 1 / density do
					local point = Grid:SnapToGrid(Vector3.new(x, y, z))
					if not point then
						continue
					end
					if Grid[point] then
						continue
					end

					-- compute edge direction set
					local edgeValidationSet = Grid:ComputeEdgeValidationSet(point)

					if Debug then
						local A0 = Instance.new("Attachment")
						A0.WorldPosition = point
						A0.Visible = true
						A0.Name = tostring(point)
						A0.Parent = workspace.Terrain
					end

					Grid[point] = { edgeValidationSet, Grid.VersionID }
					Cache[point] = { edgeValidationSet, Grid.VersionID }
				end
			end
		end
	end

	function Grid:SimplifyPath(path)
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

	function Grid:GetPathAsync(A, B, d, greedy)
		if not (self:IsPointBounded(A) and self:IsPointBounded(B)) then
			if Debug then
				Grid:Out("points are not contained")
			end

			return
		end

		local Start = self:SnapToGrid(A, true)

		local Goal = self:SnapToGrid(B, true)

		if not (Start and Goal) then
			if Debug then
				Grid:Out("points can not be resolved", Start, Goal)
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
		local maxIterations = Grid.MaxIterations

		local CurrentNode = nil

		while OpenSet.size ~= 0 and iterations <= maxIterations do
			iterations += 1
			CurrentNode = OpenSet:RemoveMin()
			--
			if self:IsVisible(CurrentNode.Position, GoalNode.Position) then
				GoalNode.From = CurrentNode
				CurrentNode = GoalNode
			end

			if CurrentNode:Equals(GoalNode) then
				if Debug then
					Grid:Out(
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
				self:SimplifyPath(finalNodeSequence)
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
							OpenLookUp[Position] = { Node = NewNode }

							NewNode.From = CurrentNode
						elseif not greedy then
							local focusNode = nil

							if OpenLookUp[Position] then
								focusNode = OpenLookUp[Position].Node
							elseif ClosedLookUp[Position] then
								focusNode = ClosedLookUp[Position]
							end

							if focusNode and potentialG < focusNode.G then
								focusNode.From = CurrentNode
								OpenSet:Update(focusNode, potentialG)
							end
						end
					end
				end
			end
			--
			OpenLookUp[CurrentNode.Position] = nil

			ClosedLookUp[CurrentNode.Position] = CurrentNode

			if iterations % Grid.MaxNodeExpansionsPerFrame == 0 then
				RunService.Heartbeat:Wait()
			end

			CurrentNode = nil
		end
		if Debug then
			Grid:Out(iterations)
		end
		print(iterations)
		return nil
	end

	function Grid:Reset()
		Grid.VersionID += 1
	end
	function Grid:GetExtents(model: Model)
		local ori, size = model:GetBoundingBox()
		local corner1 = ori:ToWorldSpace(CFrame.new(-size)).Position
		local corner2 = ori:ToWorldSpace(CFrame.new(size)).Position

		return { corner1, corner2 }
	end

	function Grid:Out(...)
		if Debug then
			print(...)
		end
	end
	function Grid:AddEntity(ent)
		if Grid.Entities[ent] then
			return
		end

		Grid:Out("Adding entity", ent)

		Grid.Entities[ent] = {}
	end

	local UpdateFinished = true

	function Grid:ManangeEntities()
		if not UpdateFinished then
			return
		end
		UpdateFinished = false
		Grid:Out("Started Updates")
		local nodesProcessed = 0
		for ent, t in pairs(Grid.Entities) do
			local RemoveAfter = false
			if not (ent and ent.Parent) then
				Grid:Out("Removing entity", ent.Name)
				RemoveAfter = true
				continue
			end
			local newExtents = Grid:GetExtents(ent)

			if newExtents[1] ~= Grid.Entities[ent][1] or newExtents[2] ~= Grid.Entities[ent][2] then
				Grid:Out("extents on", ent.Name, "changed, updating grid.")

				local corner1 = Grid:SnapToGrid(newExtents[1], false, true) -- new corners
				local corner2 = Grid:SnapToGrid(newExtents[2], false, true)

				local newMinCorner = Vector3.new(
					math.min(corner1.x, corner2.x),
					math.min(corner1.y, corner2.y),
					math.min(corner1.z, corner2.z)
				) - Vector3.new(1, 1, 1) * 1 / density
				local newMaxCorner = Vector3.new(
					math.max(corner1.x, corner2.x),
					math.max(corner1.y, corner2.y),
					math.max(corner1.z, corner2.z)
				) + Vector3.new(1, 1, 1) * 1 / density

				local corner3 = Grid.Entities[ent][1] -- old corners
				local corner4 = Grid.Entities[ent][2]

				local oldMinCorner
				local oldMaxCorner

				if corner3 and corner4 then
					corner3 = Grid:SnapToGrid(Grid.Entities[ent][1], false, true) -- old corners
					corner4 = Grid:SnapToGrid(Grid.Entities[ent][2], false, true)
					oldMinCorner = Vector3.new(
						math.min(corner3.x, corner4.x),
						math.min(corner3.y, corner4.y),
						math.min(corner3.z, corner4.z)
					) - Vector3.new(1, 1, 1) * 1 / density
					oldMaxCorner = Vector3.new(
						math.max(corner3.x, corner4.x),
						math.max(corner3.y, corner4.y),
						math.max(corner3.z, corner4.z)
					) + Vector3.new(1, 1, 1) * 1 / density
				end

				for x = newMinCorner.X, newMaxCorner.X, 1 / density do
					for y = newMinCorner.Y, newMaxCorner.Y, 1 / density do
						for z = newMinCorner.Z, newMaxCorner.Z, 1 / density do
							nodesProcessed += 1
							if nodesProcessed % Grid.MaxUpdateNodesPerFrame == 0 then
								Grid:Out("Yielding!")
								RunService.Heartbeat:Wait()
							end
							local point = Grid:SnapToGrid(Vector3.new(x, y, z))
							if not point then
								continue
							end
							if not Grid[point] then
								continue
							end
							local edgeValidationSet = Grid:ComputeEdgeValidationSet(point)
							--
							Grid[point][1] = edgeValidationSet
						end
					end
				end
				-- any points now checked in the old boundary should be reset to baseline
				if oldMinCorner and oldMaxCorner then
					for x = oldMinCorner.X, oldMaxCorner.X, 1 / density do
						for y = oldMinCorner.Y, oldMaxCorner.Y, 1 / density do
							for z = oldMinCorner.Z, oldMaxCorner.Z, 1 / density do
								nodesProcessed += 1
								if nodesProcessed % Grid.MaxUpdateNodesPerFrame == 0 then
									Grid:Out("Yielding!")
									RunService.Heartbeat:Wait()
								end
								local point = Grid:SnapToGrid(Vector3.new(x, y, z))
								if not point then
									continue
								end
								if not Grid[point] then
									continue
								end
								-- resetting the points

								local edgeValidationSet = Grid:ComputeEdgeValidationSet(point)
								--
								Grid[point][1] = edgeValidationSet
							end
						end
					end
				end
			end
			if RemoveAfter then
				Grid.Entities[ent] = nil
			else
				Grid.Entities[ent] = newExtents
			end
		end

		UpdateFinished = true
		Grid:Out("Finished Updates")
	end

	UpdateConnection = RunService.Heartbeat:Connect(function(delta)
		accumulator += delta
		if accumulator >= 1 / Grid.UpdateRate then
			accumulator = 0
			Grid:ManangeEntities()
		end
	end)
	function Grid:Destroy()
		if UpdateConnection then
			UpdateConnection:Disconnect()
		end
		table.clear(Grid)
	end
	return Grid
end

return BakeStar
