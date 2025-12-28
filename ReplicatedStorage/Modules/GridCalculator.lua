-- code by @CCG1234hello / lian_stillhere
-- sorry bad english

local grid = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

-- Calculating Grid
function grid.new(step : number, position : {number}, size : {number}, ground : Folder)
	local gridTable = {}
	
	-- x, y increment for every grid steps
	local xIncrement = size[1] / step
	local yIncrement = size[2] / step
	
	-- finding start position
	-- which is offseting center pos to edge by half of size
	local startPos = Vector3.new(position[1] - (size[1]/2), 100, position[2] - (size[2]/2))
	
	-- main grid calculation
	for x = 1, step, 1 do
		-- make 2D table
		gridTable[x] = {}
		for y = 1, step, 1 do
			-- calculating grid position by adding increment to start position
			gridTable[x][y] = startPos + Vector3.new(xIncrement * (x-1), 0, yIncrement * (y-1))
			
			-- raycasting ground
			-- to make grid position exacly on top of ground object
			rayParams.FilterDescendantsInstances = {ground}
			
			local origin = gridTable[x][y]
			local distance = origin + Vector3.new(0, -300, 0)
			
			local ray = workspace:Raycast(origin, (distance - origin), rayParams)
			if(not ray) then continue end
			if(not ray.Position) then continue end
			
			-- updating grid position with new y point
			gridTable[x][y] = Vector3.new(origin.X, ray.Position.Y, origin.Z)
		end 
	end
	
	return gridTable
end


-- Visualize Calculated Grid
function grid.VisualizeGrid(gridTable : {{Vector3}}, gridCost : {{number}}, gridDirection : {{{number} | boolean}})
	
	-- initialize visual folder
	local visualFolder = workspace:FindFirstChild("VisualFolder") or Instance.new("Folder")
	if(visualFolder.Parent ~= workspace) then
		visualFolder.Parent = workspace
		visualFolder.Name = "VisualFolder"
	end
	
	-- loop over grid table which is 2D table
	for i, jt in gridTable do
		for j, value in jt do
			-- get grid direction and jumpstatus
			local gridDir = gridDirection[i][j]
			local dir = gridDir["Direction"]
			local jumpStatus = gridDir["JumpStatus"]
			
			local dirPos = gridTable[dir[1]][dir[2]]
			
			local newPart = if(visualFolder:FindFirstChild(i.."|"..j)) then visualFolder:FindFirstChild(i.."|"..j) else game.ReplicatedStorage.Grid:Clone()
			newPart.Size = Vector3.new(.5, .5, .5)
			-- locating visual part on grid position and facing to grid direction
			newPart.CFrame = CFrame.new(value, dirPos)
			newPart.Parent = visualFolder
			newPart.Anchored = true
			newPart.CanCollide = false
			newPart.CanQuery = false
			newPart.Name = i.."|"..j
			-- more cost more darker the color
			-- if grid have to jump then color will be red or yellow
			newPart.Color = Color3.fromRGB(if(jumpStatus) then 255 else 0, 255 - (gridCost[i][j] * 2), 0)
		end
	end
end

-- Removing Visual Part
function grid.RemoveVisual()
	local visualFolder = workspace:FindFirstChild("VisualFolder")
	if(visualFolder) then
		visualFolder:Destroy()
	end
end

return grid
