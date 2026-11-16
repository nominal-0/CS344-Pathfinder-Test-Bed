local AdjGrid = {}

function AdjGrid.new(boundaries, density: number, raycastParams: RaycastParams, Debug: boolean)
	local Grid = {}
	local Cache = {}
	Grid.VersionID = 0
	Debug = false -- For control
	local i = Vector3.new(1, 0, 0)
	local j = Vector3.new(0, 1, 0)
	local k = Vector3.new(0, 0, 1)

	function Grid.IsInRegion(position: Vector3, brick: BasePart)
		local v3 = brick.CFrame:PointToObjectSpace(position)
		return (math.abs(v3.X) <= brick.Size.X / 2)
			and (math.abs(v3.Y) <= brick.Size.Y / 2)
			and (math.abs(v3.Z) <= brick.Size.Z / 2)
	end

	function Grid:IsPointBounded(point: Vector3)
		for _, part in pairs(boundaries) do
			if not Grid.IsInRegion(point, part) then
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

	function Grid:Reset()
		Grid.VersionID += 1
	end
	function Grid:GetExtents(model: Model)
		local ori, size = model:GetBoundingBox()
		local corner1 = ori:ToWorldSpace(CFrame.new(-size)).Position
		local corner2 = ori:ToWorldSpace(CFrame.new(size)).Position

		return { corner1, corner2 }
	end

	function Grid:Destroy()
		table.clear(Grid)
	end
	return Grid, Cache
end

return AdjGrid
