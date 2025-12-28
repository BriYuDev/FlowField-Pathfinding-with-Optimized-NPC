-- code by @CCG1234hello / lian_stillhere
-- sorry bad english

local replicatedModules = script.Parent
local pathfindingCalc = require(replicatedModules.PathfindingCalculator)
local taskHandler = require(replicatedModules.TaskHandler)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local runService = game:GetService("RunService")

local npc = {}

npc.__index = npc

-- Make New NPC Object
function npc.new(...)
	local self = setmetatable({}, npc)
	local args = {...}
	
	-- server side will be the main movement calculation part
	if(runService:IsServer()) then
		local gridTable : {{Vector3}} = args[1]
		local position : {number} = args[2]
		local actorHigh : number = args[3]
		local ground : Folder = args[4]
		
		if(not gridTable or not position or not actorHigh or not ground) then return end
		
		local npcFolder = workspace:FindFirstChild("NPCS")
		
		-- just inserting the needed property
		self.Part = game.ReplicatedStorage.NPCPART:Clone()
		self.Part.Parent = npcFolder

		self.High = actorHigh

		self.Ground = ground
		self.GridTable = gridTable
		self.State = "Running"
		self.UpForce = 0

		rayParams.FilterDescendantsInstances = {ground}
		
		-- finding ground y point from init position
		local origin = Vector3.new(position[1], 200, position[2])
		local direction = Vector3.new(0, -400, 0)
		local ray = workspace:Raycast(origin, direction, rayParams)

		if(not ray) then return end

		self.Position = Vector3.new(position[1], ray.Position.Y + actorHigh, position[2])

		self.Part.Position = self.Position
		
		-- finding nearest grid pos from init pos
		local x, y = pathfindingCalc.FindNearestGridToTarget(gridTable, self.Position)
		self.GridPos = {x, y} 
	else
		-- client side will just npc model that follow the server side part
		local npcPart = args[1]
		
		-- find npc folder or create it
		local npcFolder = workspace:FindFirstChild("NPCS_CLIENT")
		if(not npcFolder) then
			npcFolder = Instance.new("Folder")
			npcFolder.Parent = workspace
			npcFolder.Name = "NPCS_CLIENT"
		end
		
		-- make server side part invisible
		npcPart.Transparency = 1
		for i, obj in npcPart:GetChildren() do
			if(obj:IsA("Decal")) then
				obj.Transparency = 1
			end
		end
		
		-- cloning npc model which is GOJOOOOO
		self.NPCPart = npcPart
		self.NPCModel = game.ReplicatedStorage.Gojo:Clone()
		self.NPCModel.Parent = npcFolder
		
		-- change model position to part position
		self.NPCModel:PivotTo(npcPart.CFrame)
		
	end
	
	return self
end

-- Main Movement Calculation
function npc:Wander(...)
	local args = {...}
	if(runService:IsServer()) then
		-- calculating main movement
		local gridDirection : {{{number} | boolean}} = args[1]
		local t : number = args[2]
		local movementSpd : number? = args[3]
		local jumpPwr : number? = args[4]
		
		if(not gridDirection or not t) then return end
		
		local movSpeed = if(movementSpd) then movementSpd elseif(self.MovementSpeed) then self.MovementSpeed else 0
		local jumpPower = if(jumpPwr) then jumpPwr elseif(self.JumpPower) then self.JumpPower else 0

		self.MovementSpeed = movSpeed
		self.JumpPower = jumpPower
		
		-- get current nearest grid from npc position
		local gridPos = self.GridPos
		local gridDir = gridDirection[gridPos[1]][gridPos[2]]
		
		-- checking its direction and jumpstatus
		local dir = gridDir["Direction"]
		local jumpStatus = gridDir["JumpStatus"]

		rayParams.FilterDescendantsInstances = {self.Ground}
		
		-- checking ground
		-- so NPC can't no clip into the ground and for checking if NPC is grounded or not
		local origin = self.Position
		
		-- if upforce is negative it will change the ray range to upforce
		-- so it will prevent npc to go through the ground when falling to fast
		local direction = if(self.UpForce < 0) then Vector3.new(0, self.UpForce - self.High, 0) else Vector3.new(0, -(self.High + 1), 0)

		local groundRay = workspace:Raycast(origin, direction, rayParams)

		local yPos = self.Position.Y
		
		-- calculating gravity force
		-- (workspace.Gravity * (7 / 25)) for converting studs to meters
		-- t is 12 hertz
		local yModifier = math.pow((((workspace.Gravity * (7 / 25)) / 2) * t), 2)
		
		-- checking if npc not jumping and not falling
		-- if so then make npc exactly on top of the ground + npc high
		if(self.State ~= "Jumping" and self.State ~= "Falling") then
			if(groundRay) then
				self.UpForce = 0
				yPos = groundRay.Position.Y + self.High
				self.State = "Running"
			else
				-- if there is not ground detected then npc enter falling state
				if(self.State == "Running") then
					self.State = "Falling"
				end
			end
		end
		
		-- if npc is falling then npc y point will be added by upforce, upforce will be negative now
		if(self.State == "Falling") then
			-- upforce will be decreased by grafity force
			self.UpForce -= yModifier
			-- add current npc y point with current upforce (negative)
			yPos = self.Position.Y + (self.UpForce * t)
			self.State = "Falling"

			if(groundRay) then
				-- if there is ground
				local groundHighPos = groundRay.Position.Y + self.High
				
				-- and current npc y point is below ground y point + npc high
				-- then npc is grounded
				if(yPos <= groundHighPos) then
					yPos = groundHighPos
					self.UpForce = 0
					self.State = "Running"
				end
			end
		end
		
		-- now for moving direction
		local movDir = Vector3.zero
		local faceTo = Vector3.zero
		
		-- get current grid direction position
		local dirPos = self.GridTable[dir[1]][dir[2]]
		
		-- get normalized vector3 of current position to direction position (don't need y point, because we calculate it differently)
		local posToDir = ((dirPos * Vector3.new(1, 0, 1) - self.Position * Vector3.new(1, 0, 1))).Unit
		-- multiply it with (movement speed * t) t = 12hertz
		movDir = posToDir * (movSpeed * t)
		-- little overlap it for part face direction
		faceTo = movDir * 2
		
		-- if grid has jumpstatus true and npc is grounded
		-- then jump
		if(jumpStatus and self.State == "Running") then
			self.UpForce += jumpPower
			self.State = "Jumping"
		end
		
		if(self.UpForce) then
			-- this is just the same as falling code, but now the upforce is positive because it added by jumppower
			if(self.UpForce > 0) then
				yPos = self.Position.Y + (self.UpForce * t)
				self.UpForce -= yModifier
				self.State = "Jumping"
			else
				-- if upforce is below positive then enter falling state
				if(self.State == "Jumping") then
					self.State = "Falling"
				end
				if(self.UpForce < 0) then
					self.State = "Falling"
				end
			end
		end
		
		-- now checking npc movement path so it not just go through an object
		local trackDir = movDir
		-- when falling and jumping it will also checking up and down direction
		if(self.State == "Falling" or self.State == "Jumping") then
			trackDir = movDir + Vector3.new(0, (yPos - self.Position.Y), 0)
		end
		
		-- if there is object then just stop
		local trackRay = workspace:Raycast(self.Position, trackDir, rayParams)
		if(trackRay)  then
			movDir = Vector3.zero
		end
		
		-- applying movement direction and y point to current part position
		self.Part.CFrame = CFrame.new(((self.Position + movDir) * Vector3.new(1, 0, 1)) + Vector3.new(0, yPos, 0), faceTo + ((self.Position * Vector3.new(1, 0, 1)) + Vector3.new(0, yPos, 0)))
		self.Position = self.Part.Position
		
		-- checking if current part position is near grid direction position
		-- if so then find new nearest grid
		local positionToTarget = (dirPos * Vector3.new(1, 0, 1) - self.Position * Vector3.new(1, 0, 1)).Magnitude
		if(positionToTarget <= 1) then
			local x, y = pathfindingCalc.FindNearestGridToTarget(self.GridTable, self.Position)
			self.GridPos = {x, y}
		end
		
		-- if there is object in front of npc but the current nearest grid position is above npc current position
		-- then jump to free from stuck
		if(trackRay) then
			local gridPos = self.GridPos
			local newPos = self.GridTable[gridPos[1]][gridPos[2]]

			if(newPos.Y > self.Position.Y and self.State == "Running") then
				self.UpForce += jumpPower
				self.State = "Jumping"
			end
		end
		
	else
		
		local t = args[1]
		
		-- lerping npc model (GOJOOO) to current part position
		taskHandler:Spawn(function()
			while task.wait() do
				
				local modelCFrame = self.NPCModel.HumanoidRootPart.CFrame
				local partCFrame = self.NPCPart.CFrame
				
				local cframeLerp = modelCFrame:Lerp(partCFrame, t)

				self.NPCModel:PivotTo(cframeLerp)
			end
		end)
		
	end
end

-- Toggle npc visiblity
function npc:Visible(client : boolean)
	if(runService:IsClient()) then
		
		-- if client then just visible the GOJOOO model
		if(client) then
			
			self.NPCPart.Transparency = 1
			for i, obj in self.NPCPart:GetChildren() do
				if(obj:IsA("Decal")) then
					obj.Transparency = 1
				end
			end
			
			for i, part in self.NPCModel:GetDescendants() do
				if(part:IsA("BasePart") or part:IsA("Decal")) then
					part.Transparency = 0
				end
			end
			
		else
			-- if server then just the server part
			self.NPCPart.Transparency = 0
			for i, obj in self.NPCPart:GetChildren() do
				if(obj:IsA("Decal")) then
					obj.Transparency = 0
				end
			end

			for i, part in self.NPCModel:GetDescendants() do
				if(part:IsA("BasePart") or part:IsA("Decal")) then
					part.Transparency = 1
				end
			end
			
		end
		
		
	end
end

return npc
