local sethiddenproperty = sethiddenproperty or set_hidden_property or set_hidden_prop
local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildOfClass("Terrain")
local decalsyeeted = true  -- 贴图清除控制开关

-- 等待游戏加载
if not game:IsLoaded() then
    game.Loaded:Wait()
end
wait(0.1)

-- 设置渲染参数
if settings then
    local RenderSettings = settings():GetService("RenderSettings")
    RenderSettings.EagerBulkExecution = false
    RenderSettings.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
    workspace.InterpolationThrottling = Enum.InterpolationThrottlingMode.Enabled
end

-- 设置光照和地形属性
if sethiddenproperty then
    pcall(sethiddenproperty, Lighting, "Technology", Enum.Technology.Compatibility)  -- 兼容模式
    pcall(sethiddenproperty, workspace, "MeshPartHeads", Enum.MeshPartHeads.Disabled)
    if Terrain then
        pcall(sethiddenproperty, Terrain, "Decoration", false)
    end
end

workspace.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled
setsimulationradius(0, 0)

-- 设置地形属性
if Terrain then
    Terrain.WaterWaveSize = 0
    Terrain.WaterWaveSpeed = 0
    Terrain.WaterReflectance = 0
    Terrain.WaterTransparency = 0
    Terrain.Elasticity = 0
end

-- 遍历所有对象进行优化
for _, obj in ipairs(game:GetDescendants()) do
    if obj:IsA("Sky") then
        -- 天空盒优化
        obj.StarCount = 0
        obj.CelestialBodiesShown = false
        
    elseif obj:IsA("DataModelMesh") then
        -- 网格细节优化
        if sethiddenproperty then
            pcall(sethiddenproperty, obj, "LODX", Enum.LevelOfDetailSetting.Low)
            pcall(sethiddenproperty, obj, "LODY", Enum.LevelOfDetailSetting.Low)
        end
        obj.CollisionFidelity = "Hull"
        
    elseif obj:IsA("UnionOperation") then
        -- 联合体碰撞优化
        obj.CollisionFidelity = "Hull"
        
    elseif obj:IsA("Model") then
        -- 模型LOD优化
        if sethiddenproperty then
            pcall(sethiddenproperty, obj, "LevelOfDetail", 1)
        end
        
    elseif obj:IsA("BasePart") then
        -- 基础部件优化
        obj.Reflectance = 0
        obj.CastShadow = false
        obj.Material = "SmoothPlastic"
        
    elseif obj:IsA("MeshPart") then
        -- 网格部件特殊优化
        obj.Material = "Plastic"
        obj.Reflectance = 0
        obj.CastShadow = false
        
    elseif obj:IsA("Atmosphere") then
        -- 大气效果优化
        obj.Density = 0
        obj.Offset = 0
        obj.Glare = 0
        obj.Haze = 0
        
    elseif obj:IsA("SurfaceAppearance") then
        -- 表面效果移除
        obj:Destroy()
        
    elseif (obj:IsA("Decal") or obj:IsA("Texture")) and decalsyeeted then
        -- 贴图透明度处理（保留头部贴图）
        if string.lower(obj.Parent.Name) ~= "head" then
            obj.Transparency = 1
        end
        
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
        -- 粒子和轨迹效果优化
        obj.Lifetime = NumberRange.new(0)
        
    elseif obj:IsA("Explosion") then
        -- 爆炸效果优化
        obj.BlastPressure = 1
        obj.BlastRadius = 1
        
    elseif obj:IsA("Fire") or obj:IsA("SpotLight") or obj:IsA("Smoke") then
        -- 环境效果关闭
        obj.Enabled = false
        
    elseif obj:IsA("PostEffect") or 
           obj:IsA("ColorCorrectionEffect") or 
           obj:IsA("DepthOfFieldEffect") or 
           obj:IsA("SunRaysEffect") or 
           obj:IsA("BloomEffect") or 
           obj:IsA("BlurEffect") then
        -- 后期处理效果关闭
        obj.Enabled = false
    end
end

-- 确保关闭所有光照效果
for _, effect in ipairs(Lighting:GetChildren()) do
    if effect:IsA("PostEffect") then
        effect.Enabled = false
    end
end