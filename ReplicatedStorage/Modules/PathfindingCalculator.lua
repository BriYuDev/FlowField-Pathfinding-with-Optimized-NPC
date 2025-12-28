-- code by @CCG1234hello / lian_stillhere
-- sorry bad english


local replicatedModules = script.Parent
-- init taskhandler for threads pooling
local taskHandler = require(replicatedModules.TaskHandler)

local config = {
	["JumpDistance"] = 12
}

local pathfinding = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

-- Find Nearest Grid x, y from Current Position
function pathfinding.FindNearestGridToTarget(gridTable : {{Vector3}}, targetPosition : Vector3)
	local x = 0
	local y = 0
	local nearestGrid = nil
	
	-- loop over grid table which is 2D table
	for i, jt in gridTable do
		for j, value in jt do
			-- check if there is no nearest grid yet
			if(not nearestGrid) then
				nearestGrid = value
				x = i
				y = j
			else
				-- if there is nearest grid that already selected
				-- then compare it with current grid
				local nearestToTarget = (targetPosition - nearestGrid).Magnitude
				local currentToTarget = (targetPosition - value).Magnitude
				
				if(nearestToTarget > currentToTarget) then
					nearestGrid = value
					x = i
					y = j
				end
			end
		end
	end
	
	-- return nearest grid x,y
	return x, y
end

-- Find Every Grid Direction
function pathfinding.CalculateGridDirection(gridTable : {{Vector3}}, gridCost : {{number}}, ground : Folder)
	
	-- for debuging (measure operation time)
	local firstTime = DateTime.now()
	
	local gridDirection = {}
	
	for x = 1, #gridTable, 1 do
		-- make new 2D table
		gridDirection[x] = {}
		for y = 1, #gridTable[1], 1 do
			taskHandler:Spawn(function()
				
				local lowestX = x
				local lowestY = y
				local lowestCost = gridCost[x][y]
				local jumpstatus = false

				local currentPos = gridTable[x][y]
				
				-- loop over grid neighbour (horizontal, vertical, diagonal)
				for i = -1, 1, 1 do
					for j = -1, 1, 1 do
						if (i == 0 and j == 0) then continue end

						local xi = x+i
						local yj = y+j
						
						-- check if the neighbour x, y not out bound
						if((xi >= 1 and xi <= #gridTable) and (yj >= 1 and yj <= #gridTable[1])) then
							local neighbourCost = gridCost[xi][yj]
							local neighbourPos = gridTable[xi][yj]
							
							-- checking if neighbour y point is higher than current grid y point
							-- then jumpstatus is true
							local js = (neighbourPos.Y - currentPos.Y) > 1
							local highDifference = (neighbourPos.Y - currentPos.Y)

							if(js) then
								-- if neighbour position is too high then skip
								if(highDifference > config["JumpDistance"]) then
									continue
								else
									-- if not too high then can be traversed but with jump
										
									-- if neighbourCost is lower than current lowest cost
									if(neighbourCost < lowestCost) then
										
										-- checking if there is no object that blocking the path
										-- checking with higher y point which is neighbour y point
										-- because if there is object that is blocking path from higher y point then NPC can't jump over it
										local origin = Vector3.new(currentPos.X, neighbourPos.Y+1, currentPos.Z)
										local distance = neighbourPos + Vector3.new(0, 1, 0)

										local direction = (distance - origin)

										local ray = workspace:Raycast(origin, direction, rayParams)

										if(ray) then continue end
										
										-- check if neighbour grid direction is current grid
										-- if yes then skip to prevent stuck
										local neighbourDirection = if(gridDirection[xi]) then gridDirection[xi][yj] else nil
										if(neighbourDirection) then
											if(neighbourDirection["Direction"][1] == x and neighbourDirection["Direction"][2] == y) then continue end
										end

										lowestCost = neighbourCost
										lowestX = xi
										lowestY = yj
										jumpstatus = true
									end
								end
							else
								-- if not have to jump
								if(neighbourCost < lowestCost) then
									rayParams.FilterDescendantsInstances = {ground}
									
									-- checking if there is no object that blocking the path
									-- here we use current pos y point because we dont have to check too specific
									local distance = Vector3.new(neighbourPos.X, currentPos.Y+1, neighbourPos.Z)
									local origin = currentPos + Vector3.new(0, 1, 0)

									local direction = (distance - origin)

									local ray = workspace:Raycast(origin, direction, rayParams)

									if(ray) then continue end
									
									-- check if neighbour grid direction is current grid
									-- if yes then skip to prevent stuck
									local neighbourDirection = if(gridDirection[xi]) then gridDirection[xi][yj] else nil
									if(neighbourDirection) then
										if(neighbourDirection["Direction"][1] == x and neighbourDirection["Direction"][2] == y) then continue end
									end

									lowestCost = neighbourCost
									lowestX = xi
									lowestY = yj
									jumpstatus = false
								end
							end

						end
					end
				end
				
				-- add direction
				gridDirection[x][y] = {Direction = {lowestX, lowestY}, JumpStatus = jumpstatus}
				
			end)
			
		end
	end
	
	-- for debuging (measure operation time)
	local lastTime = DateTime.now()

	print("TIMEELAPSED DIRECTION : "..((lastTime.UnixTimestampMillis - firstTime.UnixTimestampMillis)/ 1000).."s")
	
	return gridDirection
end

function pathfinding.CalculateFlowFieldFromGrid(gridTable : {{Vector3}}, x : number, y : number)
	
	-- for debuging (measure operation time)
	local firstTime = DateTime.now()
	
	-- check if there is goal pos
	if(not x or not y) then return end
	
	local gridCost = {}
	
	-- initialize 2D table cost with highest cost
	for i = 1, #gridTable, 1 do
		gridCost[i] = {}
		for j = 1, #gridTable[1], 1 do
			gridCost[i][j] = 255
		end
	end
	
	-- change goal cost to 0
	gridCost[x][y] = 0
	
	-- making FIFO (First In First Out) queue
	local queue = {}
	
	-- add goal pos to queue to start the loop
	table.insert(queue, {x, y})
	
	while(#queue > 0) do
		-- get first element inside queue
		local first = table.remove(queue, 1)
		local fx = first[1]
		local fy = first[2]
		
		local currentPos = gridTable[fx][fy]
		local currentCost = gridCost[fx][fy]
		
		taskHandler:Spawn(function()
			-- checking grid neighbour and updating its cost (horizontally)
			for i = -1, 1, 2 do
				local fxi = fx+i
				if(fxi <= #gridTable and fxi >= 1) then
					local neighbourPos = gridTable[fxi][fy]
					local highDifference = math.abs(currentPos.Y - neighbourPos.Y)
					
					-- prevent higher y point grid to calculate lower y point neighbour grid
					if(highDifference > config["JumpDistance"]) then continue end
					
					-- neighbour cost which is current grid cost + 1 + (grid y point difference * 2)
					local newCost = currentCost + 1 + highDifference * 2
					if(newCost >= 255) then continue end
					
					-- checking if new cost is lower than current neighbour cost
					-- so it will guarantee the neighbour cost will be the lowest possible
					if(newCost < gridCost[fxi][fy]) then
						gridCost[fxi][fy] = newCost
						table.insert(queue, {fxi, fy})
					end

				end
			end

		end)
		
		taskHandler:Spawn(function()
			-- checking grid neighbour and updating its cost (vertically)
			-- same calculation as the horizontal one
			for i = -1, 1, 2 do
				local fyi = fy+i
				if(fyi <= #gridTable[1] and fyi >= 1) then
					local neighbourPos = gridTable[fx][fyi]
					local highDifference = math.abs(currentPos.Y - neighbourPos.Y)
					
					if(highDifference > config["JumpDistance"]) then continue end

					local newCost = currentCost + 1 + highDifference * 2
					
					if(newCost >= 255) then continue end

					if(newCost < gridCost[fx][fyi]) then
						gridCost[fx][fyi] = math.min(newCost, gridCost[fx][fyi])
						table.insert(queue, {fx, fyi})
					end

				end
			end
		end)
	end
	
	-- unreference the queue table
	queue = nil
	
	-- for debuging (measure operation time)
	local lastTime = DateTime.now()
	
	print("TIMEELAPSED COST : "..((lastTime.UnixTimestampMillis - firstTime.UnixTimestampMillis)/ 1000).."s")
	
	return gridCost
end


return pathfinding
