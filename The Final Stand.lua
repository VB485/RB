-- Made by Error_IDK
--Edited By LK4D4_Cyrax

-- Version: 1

-- Instances:

local ScreenGui = Instance.new("ScreenGui")
local Aimbot = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local Toggle = Instance.new("TextButton")
local Drag = Instance.new("UIDragDetector")
local UICorner = Instance.new("UICorner")

--Properties:

ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

Aimbot.Name = "Aimbot"
Aimbot.Parent = ScreenGui
Aimbot.BackgroundColor3 = Color3.new(0.113725, 0.113725, 0.113725)
Aimbot.Position = UDim2.new(0.0599842146, 0, 0.358722359, 0)
Aimbot.Size = UDim2.new(0, 126, 0, 152)

Title.Name = "Title"
Title.Parent = Aimbot
Title.BackgroundColor3 = Color3.new(0.435294, 0.117647, 0.117647)
Title.Size = UDim2.new(0, 126, 0, 50)
Title.Font = Enum.Font.SpecialElite
Title.Text = "AIM.ASSIST"
Title.TextColor3 = Color3.fromRGB(130, 130, 130)
Title.TextSize = 13.300
Title.TextScaled = true

Toggle.Name = "Toggle"
Toggle.Parent = Aimbot
Toggle.BackgroundColor3 = Color3.fromRGB(52, 52, 39)
Toggle.BorderSizePixel = 0
Toggle.Position = UDim2.new(0, 0, 0.473684222, 0)
Toggle.Size = UDim2.new(0, 126, 0, 50)
Toggle.Font = Enum.Font.SpecialElite
Toggle.Text = "Enable"
Toggle.TextColor3 = Color3.fromRGB(117, 31, 31)
Toggle.TextSize = 40.000
Toggle.TextScaled = true

Drag.Parent = Aimbot
UICorner.Parent = Aimbot

-- Scripts:

local function PNHLOYF_fake_script() -- Toggle.LocalScript 
	local script = Instance.new('LocalScript', Toggle)

	_G.aimbot = false
	local camera = game.Workspace.CurrentCamera
	local localplayer = game:GetService("Players").LocalPlayer

	script.Parent.MouseButton1Click:Connect(function()
		if _G.aimbot == false then
			_G.aimbot = true
			script.Parent.TextColor3 = Color3.fromRGB(81, 117, 31)
			script.Parent.Text = "Enabled"
			
			-- 修改后的closestplayer函数：选择FOV范围内最近的僵尸
			function closestplayer()
				local FOV = math.rad(5)  -- 视野角度(60度)
				local closestTarget = nil
				local shortestDistance = math.huge
				
				for _, zombie in ipairs(game.Workspace.Zombies:GetChildren()) do
					if zombie:FindFirstChild("Head") and zombie.Zombie.Health > 0 then
						local zombieHeadPos = zombie.Head.Position
						local cameraPos = camera.CFrame.Position
						local cameraDirection = camera.CFrame.LookVector
						
						-- 计算僵尸在屏幕中的位置
						local toZombie = (zombieHeadPos - cameraPos).Unit
						local dotProduct = cameraDirection:Dot(toZombie)
						local angle = math.acos(math.clamp(dotProduct, -1, 1))
						
						-- 检查是否在FOV范围内
						if angle <= FOV then
							local distance = (cameraPos - zombieHeadPos).Magnitude
							if distance < shortestDistance then
								shortestDistance = distance
								closestTarget = zombie
							end
						end
					end
				end
				return closestTarget
			end

		else
			_G.aimbot = false
			script.Parent.TextColor3 = Color3.fromRGB(117, 31, 31)
			script.Parent.Text = "Enable"
		end
	end)

	local settings = {
		keybind = Enum.UserInputType.MouseButton2
	}

	local UIS = game:GetService("UserInputService")
	local aiming = false

	UIS.InputBegan:Connect(function(inp)
		if inp.UserInputType == settings.keybind then
			aiming = true
		end
	end)

	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == settings.keybind then
			aiming = false
		end
	end)

	game:GetService("RunService").RenderStepped:Connect(function()
		if aiming and script.Parent.Text == "Enabled" and closestplayer() then
			camera.CFrame = CFrame.new(camera.CFrame.Position, closestplayer().Head.Position)
		end
	end)
end
coroutine.wrap(PNHLOYF_fake_script)()