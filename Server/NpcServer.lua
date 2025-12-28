-- code by @CCG1234hello / lian_stillhere
-- sorry bad english

local runService = game:GetService("RunService")

local replicatedModules = game.ReplicatedStorage:WaitForChild("Modules", 15)
local events = game.ReplicatedStorage:WaitForChild("Events", 15)

local gridCalculator = require(replicatedModules.GridCalculator)
local pathfindCalculator = require(replicatedModules.PathfindingCalculator)
local npcHandler = require(replicatedModules.NPCHandler)

local lastPosition = Vector3.zero
local lastNearestX = nil
local lastNearestY = nil

local gridVisual = true

local function StartAlgorithm()
	
	-- wait 10 seconds before start
	task.wait(10)
	
	-- init grid 40x40 with size 400x400 and on (0, 0, 0) position
	local gridTable = gridCalculator.new(40, {0, 0}, {400, 400}, workspace.Ground)

	local gridCost = nil
	local gridDirection = nil

	local updateDelay = 0
	local wanderDelay = 0

	local npcs = {}
	
	-- init npc on random position
	for i = 1, 100 do
		local newNpc = npcHandler.new(gridTable, {math.random(-200, 200), math.random(-200, 200)}, 4, workspace.Ground)

		table.insert(npcs, newNpc)
	end


	-- main loop here
	local function Update(dt)
		-- for updating flow field pathfinding
		if(updateDelay <= 0) then
			updateDelay = (1/2)
			-- get player
			local player = game.Players:GetPlayers()[1]
			if(not player) then return end
			local character = player.Character
			
			-- character not moving then just skip
			if(lastPosition ~= character.HumanoidRootPart.Position) then
				lastPosition = character.HumanoidRootPart.Position
				
				-- if move then find nearest grid from character position
				-- if nearest grid is difference from last nearest grid
				-- then calculate new cost with the goal is new nearest grid
				local newNearestX, newNearestY = pathfindCalculator.FindNearestGridToTarget(gridTable, lastPosition)
				if(lastNearestX ~= newNearestX or lastNearestY ~= newNearestY) then
					lastNearestX = newNearestX
					lastNearestY = newNearestY
					
					-- calculate cost
					gridCost = pathfindCalculator.CalculateFlowFieldFromGrid(gridTable, newNearestX, newNearestY)
					task.wait()
					-- calculate direction
					gridDirection = pathfindCalculator.CalculateGridDirection(gridTable, gridCost, workspace.Ground)
					
					-- visualize grid
					if(gridVisual) then
						gridCalculator.VisualizeGrid(gridTable, gridCost, gridDirection)
					else
						gridCalculator.RemoveVisual()
					end
				end
			end
			
			-- checking grid visual
			-- if there are grid visual parts while gridVisual is false then remove it and
			-- if there are not grid visual parts while gridVisual is true then add it
			if(gridDirection and gridCost) then
				if(gridVisual and not workspace:FindFirstChild("VisualFolder")) then
					gridCalculator.VisualizeGrid(gridTable, gridCost, gridDirection)
				end
			end
			if(not gridVisual and workspace:FindFirstChild("VisualFolder")) then
				gridCalculator.RemoveVisual()
			end
		end
		
		if(wanderDelay <= 0) then
			-- for updating npc movement
			wanderDelay = (1/12) -- npc move in 12 hertz
			if(gridDirection) then
				-- just call wander function on every npc objects
				for i, npc in npcs do
					npc:Wander(gridDirection, wanderDelay, 9, 40)
				end
			end
		end
		
		-- deacresing the delay with delta time
		if(updateDelay > 0) then updateDelay -= dt end
		if(wanderDelay > 0) then wanderDelay -= dt end
	end

	runService.Heartbeat:Connect(Update)
	
	
end

local function OnServer(player, any)
	-- for toggle grid visualization
	if(any.Type == "ToggleVisual") then
		local status = any.Status
		
		gridVisual = status
	end
	
	-- for starting the algorithm
	if(any.Type == "StartAlgorithm") then
		StartAlgorithm()
	end
end

-- connecting remote event
events.ServerClient.OnServerEvent:Connect(OnServer)