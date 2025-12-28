-- code by @CCG1234hello / lian_stillhere
-- sorry bad english

local player = game.Players.LocalPlayer

local runService = game:GetService("RunService")

local npcsFolder = workspace:WaitForChild("NPCS", 15)

local replicatedModules = game.ReplicatedStorage:WaitForChild("Modules", 15)
local npcHandler = require(replicatedModules.NPCHandler)
local taskHandler = require(replicatedModules.TaskHandler)

local npcs = {}

local function NPCAdded(npcPart)
	-- if there is npc part added then just make client sided npc
	if(npcPart:IsA("BasePart")) then
		local newNpc = npcHandler.new(npcPart)
		newNpc:Wander(.2)
		table.insert(npcs, newNpc)
	end
end

local function NPCVisibleChange()
	-- change npc visible from client to server and vice versa
	local currentNPCVisible = player:GetAttribute("NPCVisible") or "Client"
	
	for i, npc in npcs do
		npc:Visible(currentNPCVisible == "Client")
	end
end

-- npc added event
npcsFolder.ChildAdded:Connect(NPCAdded)
-- npcvisible change event
player:GetAttributeChangedSignal("NPCVisible"):Connect(NPCVisibleChange)

-- checking if there are npcs that already added before player join
for i, npcPart in npcsFolder:GetChildren() do
	NPCAdded(npcPart)
end