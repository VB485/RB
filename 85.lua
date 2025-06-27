-- 🔧 SERVICES
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- ⚙️ SETTINGS
local showHitbox = true  -- 默认启用Hitbox
local fullBrightEnabled = true
local noFogEnabled = true
local headSize = 10      -- NPC头部大小设置
local npcResizeEnabled = true -- NPC尺寸调整开关
local npcHighlightEnabled = true -- NPC高亮开关
local playerESPEnabled = true -- 玩家ESP开关
local showPlayerNames = true -- 显示玩家名字
local showPlayerOutline = true -- 显示玩家轮廓
local noRecoilEnabled = true -- 去除后坐力和镜头晃动开关
local removeBodiesEnabled = true -- 死亡角色清理开关

-- 🔁 VARIABLES
local cachedNPCs = {}
local originalSizes = {}  -- 存储原始Hitbox大小
local originalFogEnd = Lighting.FogEnd
local originalAtmospheres = {}
local createdESP = {}
local brightLoop = nil
local rainbowHighlights = {}  -- 存储所有高亮对象
local rainbowESP = {}         -- 存储所有ESP对象
local adjustedNPCs = {}       -- 记录已调整的NPC
local playerESPCache = {}     -- 存储玩家ESP对象
local trackedHumanoids = {}   -- 存储追踪的Humanoid对象

-- 后坐力控制变量
local recoilRenderConnection = nil
local recoilCharacterConnection = nil
local originalPitch = 0
local originalYaw = 0

-- 性能优化变量
local lastRainbowUpdate = 0
local rainbowUpdateInterval = 0.2  -- 降低彩虹效果更新频率
local lastCacheUpdate = 0
local cacheUpdateInterval = 3  -- 降低NPC缓存更新频率

-- 🎯 ALLOWED NPC WEAPONS
local allowedWeapons = {
    ["AI_AK"] = true, ["igla"] = true, ["AI_RPD"] = true, ["AI_PKM"] = true,
    ["AI_SVD"] = true, ["rpg7v2"] = true, ["AI_PP19"] = true, ["AI_RPK"] = true,
    ["AI_SAIGA"] = true, ["AI_MAKAROV"] = true, ["AI_PPSH"] = true, ["AI_DB"] = true,
    ["AI_MOSIN"] = true, ["AI_VZ"] = true, ["AI_6B47_Rifleman"] = true,
    ["AI_6B45_Commander"] = true, ["AI_6B47_Commander"] = true, ["AI_6B45_Rifleman"] = true,
    ["AI_KSVK"] = true, ["AI_Chicom"] = true, ["AI_6B26"] = true, ["AI_6B3M"] = true, 
    ["Machete"] = true, ["AI_Beanie"] = true, ["AI_FaceCover"] = true
}

-- 🛠️ HELPER FUNCTIONS
local function hasAllowedWeapon(npc)
    for weaponName in pairs(allowedWeapons) do
        if npc:FindFirstChild(weaponName) then 
            return true 
        end
    end
    return false
end

local function isAlive(npc)
    if npc:GetAttribute("IsAlive") ~= nil then
        return npc:GetAttribute("IsAlive")
    end
    
    local alive = true
    for _, d in ipairs(npc:GetDescendants()) do
        if d:IsA("BallSocketConstraint") then 
            alive = false
            break
        end
    end
    npc:SetAttribute("IsAlive", alive)
    return alive
end

-- ===== 死亡角色清理功能 =====
local function handleDeath(humanoid)
    if not removeBodiesEnabled then return end
    
    local character = humanoid.Parent
    if not character or not character:IsA("Model") then return end
    
    -- 等待一帧确保死亡动画开始
    RunService.Heartbeat:Wait()
    
    -- 销毁所有身体部件
    for _, child in ipairs(character:GetDescendants()) do
        if child:IsA("BasePart") then
            child:Destroy()
        end
    end
    
    -- 销毁模型本身
    character:Destroy()
end

-- 追踪Humanoid对象
local function trackHumanoid(humanoid)
    if trackedHumanoids[humanoid] then return end
    
    -- 连接死亡事件
    local diedConnection = humanoid.Died:Connect(function()
        handleDeath(humanoid)
    end)
    
    -- 记录连接
    trackedHumanoids[humanoid] = diedConnection
end

-- 初始扫描工作区
local function scanWorkspace()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("Humanoid") then
            trackHumanoid(descendant)
        end
    end
end

-- 监听新Humanoid
local function setupDescendantListener()
    Workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Humanoid") then
            trackHumanoid(descendant)
        end
    end)
end

-- 玩家角色处理
local function setupPlayer(player)
    player.CharacterAdded:Connect(function(character)
        RunService.Heartbeat:Wait() -- 确保角色加载
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            trackHumanoid(humanoid)
        end
    end)
    
    -- 处理初始角色
    if player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            trackHumanoid(humanoid)
        end
    end
end

-- 🔲 NPC ESP
local function createNpcHeadESP(npc)
    if createdESP[npc] then return end
    
    local head = npc:FindFirstChild("Head")
    if head and not head:FindFirstChild("HeadESP") then
        local esp = Instance.new("BoxHandleAdornment")
        esp.Name = "HeadESP"
        esp.Adornee = head
        esp.AlwaysOnTop = true
        esp.ZIndex = 5
        esp.Size = head.Size
        esp.Transparency = 0.3
        esp.Color3 = Color3.fromRGB(220, 20, 60)
        esp.Parent = head
        createdESP[npc] = true
        rainbowESP[esp] = true

        npc:GetPropertyChangedSignal("Parent"):Connect(function()
            if not npc.Parent then
                if esp and esp.Parent then 
                    rainbowESP[esp] = nil
                    esp:Destroy()
                end
                createdESP[npc] = nil
            end
        end)
    end
end

-- 👤 PLAYER ESP
local function createPlayerESP(player)
    if playerESPCache[player] or player == Player then return end
    
    local esp = {
        Highlight = Instance.new("Highlight"),
        NameLabel = Drawing.new("Text"),
        Connection = nil
    }
    
    esp.Highlight.FillTransparency = 1  -- 透明填充
    esp.Highlight.OutlineTransparency = 1
    esp.Highlight.Parent = player.Character or player.CharacterAdded:Wait()
    
    esp.NameLabel.Visible = false
    esp.NameLabel.Center = true
    esp.NameLabel.Outline = true
    esp.NameLabel.Font = 2
    
    playerESPCache[player] = esp
    
    esp.Connection = RunService.RenderStepped:Connect(function()
        if not playerESPEnabled then
            esp.Highlight.Enabled = false
            esp.NameLabel.Visible = false
            return
        end
        
        if not player.Character then return end
        local humanoid = player.Character:FindFirstChild("Humanoid")
        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart then
            -- 头部位置计算
            local head = player.Character:FindFirstChild("Head")
            if not head then return end
            local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position)
            
            -- 更新高亮
            esp.Highlight.Enabled = true
            esp.Highlight.OutlineTransparency = showPlayerOutline and 0 or 1
            
            -- 距离颜色计算
            local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
            local color = Color3.fromHSV(
                math.clamp(distance / 500, 0, 1),
                0.75,
                1
            )
            esp.Highlight.OutlineColor = color
            
            -- 更新名字
            esp.NameLabel.Visible = showPlayerNames and headOnScreen
            if esp.NameLabel.Visible then
                esp.NameLabel.Position = Vector2.new(headPos.X, headPos.Y + 30)
                esp.NameLabel.Text = player.Name
                esp.NameLabel.Color = color
                esp.NameLabel.Size = 18
            end
        end
    end)
end

local function removePlayerESP(player)
    if playerESPCache[player] then
        playerESPCache[player].Connection:Disconnect()
        playerESPCache[player].Highlight:Destroy()
        playerESPCache[player].NameLabel:Remove()
        playerESPCache[player] = nil
    end
end

-- 🔥 VISUAL EFFECTS
local function LoopFullBright()
    if brightLoop then return end
    
    Lighting.Brightness = 1
    Lighting.GlobalShadows = false
    Lighting.ShadowSoftness = 0
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    Lighting.Ambient = Color3.fromRGB(200, 200, 200)
    
    brightLoop = RunService.RenderStepped:Connect(function()
        Lighting.Brightness = 1
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
    end)
end

local function applyNoFog()
    originalFogEnd = Lighting.FogEnd
    Lighting.FogEnd = 100000
    
    originalAtmospheres = {}
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") then
            table.insert(originalAtmospheres, v:Clone())
            v:Destroy()
        end
    end
    
    task.spawn(function()
        while noFogEnabled do
            Lighting.FogEnd = 100000
            task.wait(0.5)
        end
    end)
end

-- 增强的NPC识别函数
local function isNPCCharacter(npc)
    -- 检查关键身体部位
    local hasTorso = npc:FindFirstChild("UpperTorso") or npc:FindFirstChild("Torso")
    local hasHead = npc:FindFirstChild("Head")
    local hasHumanoid = npc:FindFirstChildOfClass("Humanoid")
    local hasLimbs = npc:FindFirstChild("Left Arm") or npc:FindFirstChild("Right Arm") or 
                     npc:FindFirstChild("Left Leg") or npc:FindFirstChild("Right Leg")
    
    -- 检查是否包含标准角色组件
    local isCharacter = hasTorso and hasHead and hasHumanoid
    
    -- 检查是否是NPC（非玩家角色）
    local isNPC = false
    
    -- 方法1: 检查是否有允许的武器
    if hasAllowedWeapon(npc) then
        isNPC = true
    end
    
    -- 方法2: 检查名称模式
    if not isNPC and (npc.Name:match("Male") or npc.Name:match("NPC") or 
                     npc.Name:match("Enemy") or npc.Name:match("Bot")) then
        isNPC = true
    end
    
    -- 方法3: 检查是否有标准身体部位且不是玩家角色
    if not isNPC and isCharacter and not Players:GetPlayerFromCharacter(npc) then
        isNPC = true
    end
    
    -- 方法4: 检查是否有肢体部件
    if not isNPC and hasLimbs and not Players:GetPlayerFromCharacter(npc) then
        isNPC = true
    end
    
    return isNPC, isCharacter
end

-- 👤 NPC尺寸调整和高亮
local function updateNPC(npc)
    -- 确保是有效的模型
    if not npc:IsA("Model") then return end
    
    -- 识别是否是NPC角色
    local isNPC, isCharacter = isNPCCharacter(npc)
    
    -- 应用高亮效果
    if npcHighlightEnabled and isNPC and not rainbowHighlights[npc] then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = npc
        highlight.Parent = npc
        highlight.FillTransparency = 0.9
        highlight.OutlineTransparency = 0
        rainbowHighlights[npc] = highlight
        
        npc.AncestryChanged:Connect(function()
            if not npc.Parent and rainbowHighlights[npc] then
                rainbowHighlights[npc]:Destroy()
                rainbowHighlights[npc] = nil
            end
        end)
    end
    
    -- 应用尺寸调整
    if npcResizeEnabled and isNPC and not adjustedNPCs[npc] then
        local rootPart = npc:FindFirstChild("HumanoidRootPart")
        if rootPart then
            pcall(function()
                if not originalSizes[rootPart] then
                    originalSizes[rootPart] = rootPart.Size
                end
                
                rootPart.Size = Vector3.new(headSize, headSize, headSize)
                rootPart.Transparency = 0.7
                rootPart.BrickColor = BrickColor.new("Really blue")
                rootPart.Material = Enum.Material.Neon
                rootPart.CanCollide = false
                
                adjustedNPCs[npc] = true
            end)
        end
    end
    
    -- 应用Hitbox调整
    if showHitbox and isNPC then
        local root = npc:FindFirstChild("Root") or npc:FindFirstChild("HumanoidRootPart")
        if root then
            if not originalSizes[root] then
                originalSizes[root] = root.Size
            end
            root.Size = Vector3.new(20, 20, 20)
            root.Transparency = 0.85
            root.Material = Enum.Material.Neon
            root.Color = Color3.fromRGB(255, 0, 0)
        end
        
        -- 为所有NPC创建头部ESP
        createNpcHeadESP(npc)
    end
end

-- 批量更新所有NPC
local function updateAllNPCs()
    for _, npc in ipairs(Workspace:GetChildren()) do
        if npc:IsA("Model") then
            updateNPC(npc)
        end
    end
end

-- 🔫 后坐力和镜头晃动控制
local function setupNoRecoil(enable)
    -- 清理现有连接
    if recoilRenderConnection then
        recoilRenderConnection:Disconnect()
        recoilRenderConnection = nil
    end
    
    if recoilCharacterConnection then
        recoilCharacterConnection:Disconnect()
        recoilCharacterConnection = nil
    end
    
    -- 重置角度
    originalPitch = 0
    originalYaw = 0
    
    if not enable then return end
    
    -- 获取当前角色
    local character = Player.Character or Player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    
    -- 主循环：移除镜头晃动和后坐力
    recoilRenderConnection = RunService.RenderStepped:Connect(function()
        -- 方法1: 重置镜头偏移 (针对Humanoid.CameraOffset)
        if humanoid and humanoid:IsDescendantOf(workspace) then
            humanoid.CameraOffset = Vector3.new(0, 0, 0) -- 强制归零
        end

        -- 方法2: 锁定摄像机角度 (针对直接修改CameraCFrame的后坐力)
        if Camera then
            -- 获取鼠标移动导致的自然旋转
            local mouseDelta = UserInputService:GetMouseDelta()
            if mouseDelta.X ~= 0 or mouseDelta.Y ~= 0 then
                originalYaw = originalYaw - mouseDelta.X * 0.003
                originalPitch = originalPitch - mouseDelta.Y * 0.003
                originalPitch = math.clamp(originalPitch, -math.rad(70), math.rad(70))
            end
            
            -- 强制应用原始角度（覆盖后坐力效果）
            Camera.CFrame = CFrame.new(Camera.CFrame.Position) 
                * CFrame.Angles(0, originalYaw, 0) 
                * CFrame.Angles(originalPitch, 0, 0)
        end
    end)
    
    -- 角色重新生成时重置角度
    recoilCharacterConnection = Player.CharacterAdded:Connect(function(newChar)
        character = newChar
        humanoid = newChar:WaitForChild("Humanoid")
        originalPitch = 0
        originalYaw = 0
    end)
end

-- 🌈 彩虹效果
task.spawn(function()
    while true do
        local now = tick()
        if now - lastRainbowUpdate >= rainbowUpdateInterval then
            lastRainbowUpdate = now
            local hue = now % 5 / 5
            local color = Color3.fromHSV(hue, 1, 1)
            
            -- 更新高亮
            for npc, highlight in pairs(rainbowHighlights) do
                if highlight and highlight.Parent then
                    highlight.FillColor = color
                    highlight.OutlineColor = color
                else
                    rainbowHighlights[npc] = nil
                end
            end
            
            -- 更新ESP
            for esp in pairs(rainbowESP) do
                if esp and esp.Parent then
                    esp.Color3 = color
                else
                    rainbowESP[esp] = nil
                end
            end
        end
        task.wait()
    end
end)

-- 🔄 主缓存循环
task.spawn(function()
    while true do
        local now = tick()
        if now - lastCacheUpdate >= cacheUpdateInterval then
            lastCacheUpdate = now
            
            -- 更新NPC缓存
            cachedNPCs = {}
            for _, npc in ipairs(workspace:GetChildren()) do
                if npc:IsA("Model") then
                    local isNPC, _ = isNPCCharacter(npc)
                    if isNPC and isAlive(npc) then
                        table.insert(cachedNPCs, npc)
                        updateNPC(npc)
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

-- 🧩 NPC添加处理
workspace.ChildAdded:Connect(function(npc)
    if npc:IsA("Model") then
        task.wait(0.5) -- 确保组件加载
        
        local isNPC, _ = isNPCCharacter(npc)
        if isNPC and isAlive(npc) then
            updateNPC(npc)
        end
    end
end)

-- 🧹 NPC移除清理
workspace.ChildRemoved:Connect(function(npc)
    if npc:IsA("Model") then
        -- 清理高亮
        if rainbowHighlights[npc] then
            rainbowHighlights[npc]:Destroy()
            rainbowHighlights[npc] = nil
        end
        
        -- 清理原始尺寸记录
        originalSizes[npc] = nil
        
        -- 清理ESP
        if createdESP[npc] then
            createdESP[npc] = nil
        end
        
        -- 清理调整记录
        adjustedNPCs[npc] = nil
    end
end)

-- 👥 玩家处理
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        createPlayerESP(player)
    end)
    if player.Character then
        createPlayerESP(player)
    end
    
    -- 设置死亡角色追踪
    if removeBodiesEnabled then
        setupPlayer(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removePlayerESP(player)
end)

-- 🕵️ NPC监控系统
local function monitorNewNPCs()
    -- 处理嵌套NPC
    Workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Model") then
            task.wait(0.3)
            updateNPC(descendant)
        end
    end)
end

-- 🚀 初始化设置
applyNoFog()
LoopFullBright()
updateAllNPCs()
setupNoRecoil(noRecoilEnabled) -- 初始化后坐力控制
monitorNewNPCs()

-- 为现有玩家创建ESP
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= Player then
        createPlayerESP(player)
    end
end

-- 初始化死亡角色清理系统
if removeBodiesEnabled then
    scanWorkspace()
    setupDescendantListener()
    
    -- 为现有玩家设置追踪
    for _, player in ipairs(Players:GetPlayers()) do
        setupPlayer(player)
    end
end