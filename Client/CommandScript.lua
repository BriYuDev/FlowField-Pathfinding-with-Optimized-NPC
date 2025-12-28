-- code by @CCG1234hello / lian_stillhere
-- sorry bad english

-- this script is for ui

local player = game.Players.LocalPlayer

local commandUI = script.Parent

local frame = commandUI.Frame
local infoFrame = commandUI.InfoFrame

local events = game.ReplicatedStorage:WaitForChild("Events", 15)


-- wait until game loaded and player charcter loaded
repeat task.wait(.1)
	
until game:IsLoaded() and player.Character


local function ButtonClick(button)
	
	-- just normal button click function
	if(button.Name == "GridVisualButton") then
		
		local newText = nil
		local newColor = nil
		if(button.Text == "On") then
			newText = "Off"
			newColor = Color3.fromRGB(170, 0, 0)
		else
			newText = "On"
			newColor = Color3.fromRGB(85, 255, 0)
		end
		
		button.Text = newText
		button.BackgroundColor3 = newColor
		
		events.ServerClient:FireServer({Type = "ToggleVisual", Status = (newText == "On")})
	end
	
	if(button.Name == "NPCVisibleButton") then
		local newText = nil
		local newColor = nil
		if(button.Text == "Client") then
			newText = "Server"
			newColor = Color3.fromRGB(0, 170, 255)
		else
			newText = "Client"
			newColor = Color3.fromRGB(85, 255, 0)
		end
		
		button.Text = newText
		button.BackgroundColor3 = newColor
		
		player:SetAttribute("NPCVisible", newText)
	end
end

-- if all loaded then its time to start the algorithm
events.ServerClient:FireServer({Type = "StartAlgorithm"})

-- counting down from 10 to 0, before algorithm start
local num = 10
infoFrame.Label.Text = "Algorithm Start in : "..num
repeat task.wait(1)
	num -= 1
	infoFrame.Label.Text = "Algorithm Start in : "..num
until num <= 0

infoFrame.Visible = false

-- checking every button and then connect click event
for i, button in frame:GetChildren() do
	if(button:IsA("GuiButton")) then
		button.MouseButton1Click:Connect(function() ButtonClick(button) end)
	end
end