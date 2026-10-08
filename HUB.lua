--[[ DELTA HUB MOBILE | Адаптация под телефон ]]

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UIS             = game:GetService("UserInputService")
local SoundService    = game:GetService("SoundService")
local TweenService    = game:GetService("TweenService")
local Lighting        = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser     = game:GetService("VirtualUser")
local CoreGui         = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LP:GetMouse()

-- Где размещаем GUI (пробуем CoreGui, иначе PlayerGui)
local GUI_PARENT
pcall(function()
    if CoreGui and CoreGui.Parent then GUI_PARENT = CoreGui end
end)
if not GUI_PARENT then
    GUI_PARENT = LP:WaitForChild("PlayerGui")
end

local State = {
    AimBot=false, ESP=false, ESPBox=true, ESPName=true, ESPHP=true,
    InfJump=false, Fly=false, Noclip=false, ClickTP=false, SpinBot=false,
    Fullbright=false, AntiFling=false, AntiAFK=false, AutoCollect=false,
    RainbowChar=false, GodMode=false,
}

local Config = {
    AimSmoothness=1.0, AimFOV=2000, DefaultMusic="81458780462068",
    FlySpeed=100, TP_RADIUS=400, FlingPower=500000,
}

local Connections, ESPObjects = {}, {}
local MusicSound, FlyBV, FlyBG
local FlyConn, NoclipConn, SpinConn, RainbowConn
local OriginalLight = {}
local ScreenGuiRef

-- УТИЛИТЫ
local function getChar(p) return p and p.Parent and p.Character or nil end
local function getHum(p) local c=getChar(p) return c and c:FindFirstChildOfClass("Humanoid") or nil end
local function getHRP(p) local c=getChar(p) return c and c:FindFirstChild("HumanoidRootPart") or nil end
local function getLocalPos()
    local r=getHRP(LP); return r and r.Position or Camera.CFrame.Position
end
local function isValid(plr)
    if plr==LP then return false end
    local h,r=getHum(plr),getHRP(plr)
    return h and r and h.Health>0
end
local function getNearest(maxD)
    maxD=maxD or Config.AimFOV
    local my=getLocalPos(); local best,bd=nil,maxD
    for _,p in ipairs(Players:GetPlayers()) do
        if isValid(p) then
            local r=getHRP(p); local d=(r.Position-my).Magnitude
            if d<bd then best,bd=p,d end
        end
    end
    return best,bd
end
local function disc(c) if c and typeof(c)=="RBXScriptConnection" then pcall(function() c:Disconnect() end) end end

local function notify(text, dur, color)
    dur=dur or 2.5; color=color or Color3.fromRGB(0,220,255)
    local p = ScreenGuiRef or GUI_PARENT
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(0,260,0,36)
    l.Position=UDim2.new(0.5,-130,0,10)
    l.BackgroundColor3=Color3.fromRGB(15,15,20)
    l.BorderSizePixel=0
    l.Text="⚡ "..text; l.TextColor3=color
    l.Font=Enum.Font.GothamBold; l.TextSize=13; l.TextWrapped=true
    l.ZIndex=999; l.Parent=p
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=l
    local s=Instance.new("UIStroke"); s.Color=color; s.Thickness=1; s.Parent=l
    task.delay(dur,function()
        if l and l.Parent then
            TweenService:Create(l,TweenInfo.new(0.4),{BackgroundTransparency=1,TextTransparency=1}):Play()
            task.wait(0.5); if l then l:Destroy() end
        end
    end)
end

-- AIMBOT
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not State.AimBot then return end
    local t=getNearest(); if not t then return end
    local hrp=getHRP(t); if not hrp then return end
    local pos=hrp.Position
    local v=hrp.AssemblyLinearVelocity
    if v.Magnitude>1 then pos=pos+v*0.1 end
    Camera.CFrame=Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position,pos),Config.AimSmoothness)
end))

-- ESP
local function removeESP(plr)
    local d=ESPObjects[plr]; if not d then return end
    for _,o in pairs(d) do if o and o.Parent then pcall(function() o:Destroy() end) end end
    ESPObjects[plr]=nil
end
local function clearESP() for p in pairs(ESPObjects) do removeESP(p) end ESPObjects={} end
local function makeESP(plr)
    if ESPObjects[plr] then return end
    local char=getChar(plr); local hrp=getHRP(plr)
    if not char or not hrp then return end
    local d={}
    local hl=Instance.new("Highlight")
    hl.Adornee=char
    hl.FillColor=Color3.fromRGB(255,30,30)
    hl.OutlineColor=Color3.fromRGB(255,80,80)
    hl.FillTransparency=0.5
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent=char; d.HL=hl
    if State.ESPBox then
        local bx=Instance.new("BoxHandleAdornment")
        bx.Adornee=hrp; bx.AlwaysOnTop=true; bx.ZIndex=5
        bx.Size=hrp.Size+Vector3.new(0.3,0.3,0.3)
        bx.Transparency=0.5; bx.Color3=Color3.fromRGB(255,30,30)
        bx.Parent=hrp; d.Box=bx
    end
    local head=char:FindFirstChild("Head")
    if head and (State.ESPName or State.ESPHP) then
        local bb=Instance.new("BillboardGui")
        bb.Adornee=head; bb.Size=UDim2.new(0,240,0,60)
        bb.StudsOffset=Vector3.new(0,3,0); bb.AlwaysOnTop=true
        bb.Parent=head
        if State.ESPName then
            local n=Instance.new("TextLabel")
            n.Size=UDim2.new(1,0,0,22); n.BackgroundTransparency=1
            n.Text=plr.Name; n.TextColor3=Color3.fromRGB(255,80,80)
            n.TextStrokeTransparency=0; n.Font=Enum.Font.GothamBold
            n.TextSize=16; n.Parent=bb
        end
        if State.ESPHP then
            local dl=Instance.new("TextLabel")
            dl.Name="Dist"; dl.Size=UDim2.new(1,0,0,18)
            dl.Position=UDim2.new(0,0,0,22); dl.BackgroundTransparency=1
            dl.TextColor3=Color3.fromRGB(255,200,100)
            dl.TextStrokeTransparency=0; dl.Font=Enum.Font.GothamBold
            dl.TextSize=13; dl.Parent=bb
        end
        d.BB=bb
    end
    ESPObjects[plr]=d
end
task.spawn(function()
    while task.wait(0.2) do
        if State.ESP then
            for _,p in ipairs(Players:GetPlayers()) do
                if isValid(p) and not ESPObjects[p] then pcall(makeESP,p) end
            end
            for p in pairs(ESPObjects) do
                if not isValid(p) then pcall(removeESP,p) end
            end
            local my=getLocalPos()
            for p,d in pairs(ESPObjects) do
                if d.BB then
                    local r,h=getHRP(p),getHum(p)
                    if r and h then
                        local dl=d.BB:FindFirstChild("Dist")
                        if dl then dl.Text=string.format("%dм | HP: %d",math.floor((r.Position-my).Magnitude),math.floor(h.Health)) end
                    end
                end
            end
        elseif next(ESPObjects) then clearESP() end
    end
end)
Players.PlayerRemoving:Connect(removeESP)

-- INF JUMP
table.insert(Connections, UIS.JumpRequest:Connect(function()
    if not State.InfJump then return end
    local hum=getHum(LP)
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping); hum.Jump=true end
end))

-- SPEED
local function setSpeed(v)
    local hum=getHum(LP); if not hum then return false end
    v=math.clamp(tonumber(v) or 16,16,500); hum.WalkSpeed=v; return true
end

-- MUSIC
local function playMusic(id)
    if MusicSound then pcall(function() MusicSound:Stop() MusicSound:Destroy() end) MusicSound=nil end
    id=tostring(id or Config.DefaultMusic):gsub("%D","")
    if id=="" then notify("Некорректный ID",2,Color3.fromRGB(255,80,80)) return end
    MusicSound=Instance.new("Sound")
    MusicSound.SoundId="rbxassetid://"..id
    MusicSound.Volume=0.5; MusicSound.Looped=false
    MusicSound.Parent=SoundService
    pcall(function() MusicSound:Play() end)
    notify("Играет: "..id,2)
end
local function stopMusic()
    if MusicSound then pcall(function() MusicSound:Stop() MusicSound:Destroy() end) MusicSound=nil; notify("Стоп",1.5) end
end

-- FLY
local function startFly()
    if FlyConn then return end
    local hrp=getHRP(LP); if not hrp then return end
    FlyBV=Instance.new("BodyVelocity")
    FlyBV.MaxForce=Vector3.new(9e9,9e9,9e9)
    FlyBV.Velocity=Vector3.new(0,0,0); FlyBV.P=1250; FlyBV.Parent=hrp
    FlyBG=Instance.new("BodyGyro")
    FlyBG.MaxTorque=Vector3.new(9e9,9e9,9e9)
    FlyBG.P=1000; FlyBG.D=50; FlyBG.CFrame=hrp.CFrame; FlyBG.Parent=hrp
    FlyConn=RunService.Heartbeat:Connect(function()
        if not State.Fly then return end
        local h=getHRP(LP)
        if not h or not FlyBV or not FlyBG then return end
        local cam=workspace.CurrentCamera
        local mv=Vector3.new(0,0,0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then mv+=cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then mv-=cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then mv-=cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then mv+=cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then mv+=Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then mv-=Vector3.new(0,1,0) end
        if mv.Magnitude>0 then mv=mv.Unit end
        FlyBV.Velocity=mv*Config.FlySpeed; FlyBG.CFrame=cam.CFrame
    end)
    table.insert(Connections,FlyConn)
end
local function stopFly()
    disc(FlyConn); FlyConn=nil
    if FlyBV then FlyBV:Destroy() FlyBV=nil end
    if FlyBG then FlyBG:Destroy() FlyBG=nil end
end

-- NOCLIP
local function startNoclip()
    if NoclipConn then return end
    NoclipConn=RunService.Stepped:Connect(function()
        if not State.Noclip then return end
        local char=getChar(LP); if not char then return end
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end
        end
    end)
    table.insert(Connections,NoclipConn)
end
local function stopNoclip()
    disc(NoclipConn); NoclipConn=nil
    local char=getChar(LP)
    if char then
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() p.CanCollide=true end) end
        end
    end
end

-- CLICK TP
Mouse.Button1Down:Connect(function()
    if not State.ClickTP then return end
    local hrp=getHRP(LP)
    if hrp and Mouse.Hit then hrp.CFrame=CFrame.new(Mouse.Hit.Position+Vector3.new(0,3,0)) end
end)

-- SPIN
local function startSpin()
    if SpinConn then return end
    SpinConn=RunService.Heartbeat:Connect(function(dt)
        if not State.SpinBot then return end
        local hrp=getHRP(LP)
        if hrp then hrp.CFrame=hrp.CFrame*CFrame.Angles(0,math.rad(360)*dt*10,0) end
    end)
    table.insert(Connections,SpinConn)
end
local function stopSpin() disc(SpinConn); SpinConn=nil end

-- FULLBRIGHT
local function enableFB()
    OriginalLight.B=Lighting.Brightness; OriginalLight.A=Lighting.Ambient
    OriginalLight.OA=Lighting.OutdoorAmbient; OriginalLight.C=Lighting.ClockTime
    OriginalLight.F=Lighting.FogEnd
    Lighting.Brightness=5; Lighting.Ambient=Color3.fromRGB(255,255,255)
    Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
    Lighting.ClockTime=12; Lighting.FogEnd=100000
end
local function disableFB()
    if OriginalLight.B then Lighting.Brightness=OriginalLight.B end
    if OriginalLight.A then Lighting.Ambient=OriginalLight.A end
    if OriginalLight.OA then Lighting.OutdoorAmbient=OriginalLight.OA end
    if OriginalLight.C then Lighting.ClockTime=OriginalLight.C end
    if OriginalLight.F then Lighting.FogEnd=OriginalLight.F end
end

-- ANTI
LP.Idled:Connect(function()
    if not State.AntiAFK then return end
    VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new())
end)
table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not State.AntiFling then return end
    local hrp=getHRP(LP); if not hrp then return end
    for _,o in ipairs(hrp:GetChildren()) do
        if o:IsA("BodyVelocity") and o.Name~="DeltaFly" then o:Destroy() end
        if o:IsA("BodyAngularVelocity") then o:Destroy() end
    end
end))
table.insert(Connections, RunService.Heartbeat:Connect(function()
    if not State.GodMode then return end
    local hum=getHum(LP)
    if hum and hum.Health>0 then hum.MaxHealth=math.huge; hum.Health=math.huge end
end))

-- AUTO-COLLECT
task.spawn(function()
    while task.wait(0.3) do
        if not State.AutoCollect then continue end
        local hrp=getHRP(LP); if not hrp then continue end
        for _,o in ipairs(workspace:GetDescendants()) do
            if o:IsA("BasePart") and o:FindFirstChild("TouchInterest") then
                if (o.Position-hrp.Position).Magnitude<100 then
                    pcall(function() firetouchinterest(hrp,o,0); task.wait(); firetouchinterest(hrp,o,1) end)
                end
            end
        end
    end
end)

-- RAINBOW
local function startRainbow()
    if RainbowConn then return end
    RainbowConn=RunService.Heartbeat:Connect(function()
        if not State.RainbowChar then return end
        local char=getChar(LP); if not char then return end
        local c=Color3.fromHSV(tick()%5/5,1,1)
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then
                pcall(function() p.Color=c end)
            end
        end
    end)
    table.insert(Connections,RainbowConn)
end
local function stopRainbow() disc(RainbowConn); RainbowConn=nil end

-- FLING
local function flingPlayer(plr)
    if not plr or plr==LP then return false end
    local hrp=getHRP(plr); if not hrp then return false end
    local dir=hrp.Position
    if dir.Magnitude<1 then dir=Vector3.new(math.random(-1,1),5,math.random(-1,1)) end
    dir=dir.Unit
    local bv=Instance.new("BodyVelocity")
    bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge)
    bv.Velocity=dir*Config.FlingPower+Vector3.new(0,Config.FlingPower,0)
    bv.P=math.huge; bv.Parent=hrp
    local bg=Instance.new("BodyAngularVelocity")
    bg.AngularVelocity=Vector3.new(Config.FlingPower,Config.FlingPower,Config.FlingPower)
    bg.MaxTorque=Vector3.new(math.huge,math.huge,math.huge)
    bg.P=math.huge; bg.Parent=hrp
    pcall(function() hrp.CFrame=CFrame.new(dir*50000+Vector3.new(0,5000,0)) end)
    task.delay(1,function()
        if bv and bv.Parent then pcall(function() bv:Destroy() end) end
        if bg and bg.Parent then pcall(function() bg:Destroy() end) end
    end)
    return true
end
local function flingAll()
    local n=0
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and pcall(flingPlayer,p) then n+=1 end
    end
    return n
end
local function flingRadius(rad)
    rad=rad or Config.TP_RADIUS
    local my=getLocalPos(); local n=0
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            local r,h=getHRP(p),getHum(p)
            if r and h and h.Health>0 then
                if (r.Position-my).Magnitude<=rad then
                    if pcall(flingPlayer,p) then n+=1 end
                end
            end
        end
    end
    return n
end

-- FPS / SIZE / TP
local function fpsBoost()
    for _,o in ipairs(game:GetDescendants()) do
        pcall(function()
            if o:IsA("Decal") or o:IsA("Texture") then o.Transparency=1
            elseif o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Smoke") or o:IsA("Fire") then o.Enabled=false end
        end)
    end
    notify("FPS Booster ON",2,Color3.fromRGB(0,255,130))
end
local function setSize(s)
    s=math.clamp(tonumber(s) or 1,0.1,10)
    local char=getChar(LP)
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for _,n in ipairs({"BodyDepthScale","BodyWidthScale","BodyHeightScale","HeadScale"}) do
        local o=hum:FindFirstChild(n)
        if o then pcall(function() o.Value=s end) end
    end
end
local function tpToPlayer(plr)
    local hrp=getHRP(plr); local my=getHRP(LP)
    if hrp and my then my.CFrame=hrp.CFrame+Vector3.new(0,3,0); notify("ТП к "..plr.Name,1.5) end
end

-- ============================================================
-- UI ПОД ТЕЛЕФОН
-- ============================================================
if GUI_PARENT:FindFirstChild("DeltaHubUI") then
    GUI_PARENT.DeltaHubUI:Destroy()
end

local SG = Instance.new("ScreenGui")
SG.Name="DeltaHubUI"
SG.ResetOnSpawn=false
SG.IgnoreGuiInset=true
SG.DisplayOrder=100
SG.Parent=GUI_PARENT
ScreenGuiRef=SG

local C = {
    Bg=Color3.fromRGB(12,12,18), Panel=Color3.fromRGB(22,22,32),
    Panel2=Color3.fromRGB(30,30,44), Accent=Color3.fromRGB(0,220,255),
    Accent2=Color3.fromRGB(180,0,255), Green=Color3.fromRGB(0,255,130),
    Red=Color3.fromRGB(255,60,80), Orange=Color3.fromRGB(255,165,0),
    Text=Color3.fromRGB(230,230,245), Sub=Color3.fromRGB(140,140,170),
}

-- МАЛЕНЬКОЕ МЕНЮ ПОД ТЕЛЕФОН: 260×380, слева сверху
local MainFrame = Instance.new("Frame")
MainFrame.Name="MainFrame"
MainFrame.Size=UDim2.new(0,260,0,380)
MainFrame.Position=UDim2.new(0,10,0,60)
MainFrame.BackgroundColor3=C.Bg
MainFrame.BorderSizePixel=0
MainFrame.Active=true
MainFrame.Draggable=true
MainFrame.Parent=SG
local mfc=Instance.new("UICorner"); mfc.CornerRadius=UDim.new(0,12); mfc.Parent=MainFrame
local mfs=Instance.new("UIStroke"); mfs.Color=C.Accent; mfs.Thickness=2; mfs.Parent=MainFrame

-- ШАПКА
local Header=Instance.new("Frame")
Header.Size=UDim2.new(1,0,0,36)
Header.BackgroundColor3=C.Panel
Header.BorderSizePixel=0
Header.Parent=MainFrame
local hdc=Instance.new("UICorner"); hdc.CornerRadius=UDim.new(0,12); hdc.Parent=Header
local HeaderTitle=Instance.new("TextLabel")
HeaderTitle.Size=UDim2.new(1,-10,1,0)
HeaderTitle.Position=UDim2.new(0,10,0,0)
HeaderTitle.BackgroundTransparency=1
HeaderTitle.Text="⚡ DELTA HUB (MOBILE)"
HeaderTitle.TextColor3=C.Accent
HeaderTitle.Font=Enum.Font.GothamBold
HeaderTitle.TextSize=13
HeaderTitle.TextXAlignment=Enum.TextXAlignment.Left
HeaderTitle.Parent=Header

-- СКРОЛЛ
local Container=Instance.new("ScrollingFrame")
Container.Size=UDim2.new(1,-10,1,-90)
Container.Position=UDim2.new(0,5,0,42)
Container.BackgroundTransparency=1
Container.BorderSizePixel=0
Container.ScrollBarThickness=4
Container.ScrollBarImageColor3=C.Accent
Container.CanvasSize=UDim2.new(0,0,0,0)
Container.AutomaticCanvasSize=Enum.AutomaticSize.Y
Container.Parent=MainFrame
local Layout=Instance.new("UIListLayout")
Layout.Padding=UDim.new(0,6)
Layout.SortOrder=Enum.SortOrder.LayoutOrder
Layout.Parent=Container
local Pad=Instance.new("UIPadding")
Pad.PaddingTop=UDim.new(0,4); Pad.PaddingBottom=UDim.new(0,4)
Pad.PaddingLeft=UDim.new(0,2); Pad.PaddingRight=UDim.new(0,2)
Pad.Parent=Container

-- ФУТЕР С КНОПКАМИ (всегда виден внизу меню)
local Footer=Instance.new("Frame")
Footer.Size=UDim2.new(1,-10,0,44)
Footer.Position=UDim2.new(0,5,1,-50)
Footer.BackgroundColor3=C.Panel
Footer.BorderSizePixel=0
Footer.ZIndex=10
Footer.Parent=MainFrame
local ftc=Instance.new("UICorner"); ftc.CornerRadius=UDim.new(0,10); ftc.Parent=Footer

-- КНОПКА СВЕРНУТЬ (слева)
local MinBtn=Instance.new("TextButton")
MinBtn.Size=UDim2.new(0.5,-4,1,0)
MinBtn.Position=UDim2.new(0,2,0,0)
MinBtn.BackgroundColor3=C.Orange
MinBtn.BorderSizePixel=0
MinBtn.Text="СВЕРНУТЬ"
MinBtn.TextColor3=Color3.fromRGB(0,0,0)
MinBtn.Font=Enum.Font.GothamBold
MinBtn.TextSize=13
MinBtn.ZIndex=11
MinBtn.Parent=Footer
local mbc=Instance.new("UICorner"); mbc.CornerRadius=UDim.new(0,8); mbc.Parent=MinBtn

-- КНОПКА ЗАКРЫТЬ (справа)
local CloseBtn=Instance.new("TextButton")
CloseBtn.Size=UDim2.new(0.5,-4,1,0)
CloseBtn.Position=UDim2.new(0.5,2,0,0)
CloseBtn.BackgroundColor3=C.Red
CloseBtn.BorderSizePixel=0
CloseBtn.Text="ЗАКРЫТЬ"
CloseBtn.TextColor3=Color3.fromRGB(255,255,255)
CloseBtn.Font=Enum.Font.GothamBold
CloseBtn.TextSize=13
CloseBtn.ZIndex=11
CloseBtn.Parent=Footer
local cbc=Instance.new("UICorner"); cbc.CornerRadius=UDim.new(0,8); cbc.Parent=CloseBtn

-- ФАБРИКИ (уменьшенные под телефон)
local function createSection(t)
    local S=Instance.new("Frame")
    S.Size=UDim2.new(1,0,0,60)
    S.AutomaticSize=Enum.AutomaticSize.Y
    S.BackgroundColor3=C.Panel
    S.BorderSizePixel=0
    S.Parent=Container
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=S
    local st=Instance.new("UIStroke"); st.Color=C.Accent2; st.Thickness=1; st.Transparency=0.6; st.Parent=S
    local tl=Instance.new("TextLabel")
    tl.Size=UDim2.new(1,-16,0,22); tl.Position=UDim2.new(0,8,0,5)
    tl.BackgroundTransparency=1; tl.Text=t
    tl.TextColor3=C.Accent; tl.Font=Enum.Font.GothamBold; tl.TextSize=12
    tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Parent=S
    local I=Instance.new("Frame")
    I.Size=UDim2.new(1,-16,0,0); I.Position=UDim2.new(0,8,0,28)
    I.AutomaticSize=Enum.AutomaticSize.Y
    I.BackgroundTransparency=1; I.Parent=S
    local il=Instance.new("UIListLayout")
    il.Padding=UDim.new(0,4); il.SortOrder=Enum.SortOrder.LayoutOrder; il.Parent=I
    return S,I
end

local function createToggle(p,txt,cb)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,0,0,30)
    b.BackgroundColor3=C.Bg; b.BorderSizePixel=0
    b.TextColor3=C.Text; b.Font=Enum.Font.GothamBold; b.TextSize=11
    b.Text="  "..txt.." : ВЫКЛ"
    b.TextXAlignment=Enum.TextXAlignment.Left
    b.Parent=p
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=b
    local s=Instance.new("UIStroke"); s.Color=C.Red; s.Thickness=1; s.Parent=b
    local on=false
    b.MouseButton1Click:Connect(function()
        on=not on
        if on then b.Text="  "..txt.." : ВКЛ"; b.TextColor3=C.Green; s.Color=C.Green
        else b.Text="  "..txt.." : ВЫКЛ"; b.TextColor3=C.Text; s.Color=C.Red end
        if cb then pcall(cb,on) end
    end)
    return b,function(state)
        on=state
        if on then b.Text="  "..txt.." : ВКЛ"; b.TextColor3=C.Green; s.Color=C.Green
        else b.Text="  "..txt.." : ВЫКЛ"; b.TextColor3=C.Text; s.Color=C.Red end
        if cb then pcall(cb,on) end
    end
end

local function createInputRow(p,ph,dt,btnText,cb)
    local r=Instance.new("Frame")
    r.Size=UDim2.new(1,0,0,30); r.BackgroundTransparency=1; r.Parent=p
    local i=Instance.new("TextBox")
    i.Size=UDim2.new(1,-70,1,0); i.BackgroundColor3=C.Bg
    i.BorderSizePixel=0; i.TextColor3=C.Text
    i.PlaceholderText=ph; i.PlaceholderColor3=C.Sub
    i.Font=Enum.Font.Gotham; i.TextSize=11
    i.Text=dt or ""; i.ClearTextOnFocus=false; i.Parent=r
    local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,6); ic.Parent=i
    local is=Instance.new("UIStroke"); is.Color=C.Accent; is.Thickness=1; is.Transparency=0.5; is.Parent=i
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(0,64,1,0); b.Position=UDim2.new(1,-64,0,0)
    b.BackgroundColor3=C.Accent; b.BorderSizePixel=0
    b.TextColor3=Color3.fromRGB(0,0,0); b.Font=Enum.Font.GothamBold
    b.TextSize=10; b.Text=btnText; b.Parent=r
    local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,6); bc.Parent=b
    b.MouseButton1Click:Connect(function() if cb then pcall(cb,i.Text) end end)
    return i,b
end

local function createButton(p,txt,col,cb)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,0,0,30)
    b.BackgroundColor3=col or C.Accent
    b.BorderSizePixel=0; b.TextColor3=Color3.fromRGB(0,0,0)
    b.Font=Enum.Font.GothamBold; b.TextSize=11; b.Text=txt; b.Parent=p
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=b
    b.MouseButton1Click:Connect(function() if cb then pcall(cb) end end)
    return b
end

-- НАПОЛНЕНИЕ (компактное)
local _,flingInner=createSection("⚡ FLING")
createButton(flingInner,"FLING ВСЕХ В РАДИУСЕ 400",C.Red,function()
    notify("FLING: "..flingRadius(Config.TP_RADIUS),3,C.Red)
end)
createButton(flingInner,"FLING ВСЕХ НА СЕРВЕРЕ",C.Red,function()
    notify("FLING ALL: "..flingAll(),3,C.Red)
end)
createInputRow(flingInner,"Имя","","FLING",function(txt)
    txt=(txt or ""):lower()
    if txt=="" then return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and p.Name:lower():sub(1,#txt)==txt then
            if flingPlayer(p) then notify("FLING: "..p.Name,2,C.Red) end
            return
        end
    end
    notify("Не найден",2,C.Red)
end)

local _,aimInner=createSection("🎯 AIMBOT / SPIN / INF")
local _,setAimState=createToggle(aimInner,"AIMBOT",function(on) State.AimBot=on end)
local _,setSpinState=createToggle(aimInner,"SPIN BOT",function(on)
    State.SpinBot=on; if on then startSpin() else stopSpin() end
end)
local _,setInfState=createToggle(aimInner,"INFINITE JUMP",function(on) State.InfJump=on end)

local _,tpInner=createSection("🚀 TP ≤400 studs")
local TPInfo=Instance.new("TextLabel")
TPInfo.Size=UDim2.new(1,0,0,14); TPInfo.BackgroundTransparency=1
TPInfo.Text="Найдено: 0"; TPInfo.TextColor3=C.Sub
TPInfo.Font=Enum.Font.Gotham; TPInfo.TextSize=10
TPInfo.TextXAlignment=Enum.TextXAlignment.Left; TPInfo.Parent=tpInner

local TPList=Instance.new("ScrollingFrame")
TPList.Size=UDim2.new(1,0,0,140)
TPList.BackgroundColor3=C.Bg; TPList.BorderSizePixel=0
TPList.ScrollBarThickness=3; TPList.ScrollBarImageColor3=C.Accent
TPList.CanvasSize=UDim2.new(0,0,0,0)
TPList.AutomaticCanvasSize=Enum.AutomaticSize.Y
TPList.Parent=tpInner
local tlc=Instance.new("UICorner"); tlc.CornerRadius=UDim.new(0,6); tlc.Parent=TPList
local tls=Instance.new("UIStroke"); tls.Color=C.Accent; tls.Thickness=1; tls.Transparency=0.6; tls.Parent=TPList
local tll=Instance.new("UIListLayout"); tll.Padding=UDim.new(0,3); tll.SortOrder=Enum.SortOrder.LayoutOrder; tll.Parent=TPList
local tlp=Instance.new("UIPadding")
tlp.PaddingTop=UDim.new(0,3); tlp.PaddingBottom=UDim.new(0,3)
tlp.PaddingLeft=UDim.new(0,3); tlp.PaddingRight=UDim.new(0,3); tlp.Parent=TPList

local function refreshTP()
    for _,ch in ipairs(TPList:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
    end
    local my=getLocalPos(); local list={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            local r,h=getHRP(p),getHum(p)
            if r and h and h.Health>0 then
                local d=(r.Position-my).Magnitude
                if d<=Config.TP_RADIUS then table.insert(list,{p=p,d=d,hp=h.Health}) end
            end
        end
    end
    table.sort(list,function(a,b) return a.d<b.d end)
    TPInfo.Text=string.format("Найдено: %d",#list)
    if #list==0 then
        local e=Instance.new("TextLabel")
        e.Size=UDim2.new(1,0,0,30); e.BackgroundTransparency=1
        e.Text="😔 Никого рядом"; e.TextColor3=C.Sub
        e.Font=Enum.Font.Gotham; e.TextSize=11; e.Parent=TPList
        return
    end
    for _,data in ipairs(list) do
        local p=data.p
        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=C.Panel2
        row.BorderSizePixel=0; row.Parent=TPList
        local rc=Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,5); rc.Parent=row
        local nl=Instance.new("TextLabel")
        nl.Size=UDim2.new(1,-70,0,15); nl.Position=UDim2.new(0,6,0,3)
        nl.BackgroundTransparency=1; nl.Text=p.Name
        nl.TextColor3=C.Text; nl.Font=Enum.Font.GothamBold
        nl.TextSize=11; nl.TextXAlignment=Enum.TextXAlignment.Left
        nl.TextTruncate=Enum.TextTruncate.AtEnd; nl.Parent=row
        local il=Instance.new("TextLabel")
        il.Size=UDim2.new(1,-70,0,12); il.Position=UDim2.new(0,6,0,18)
        il.BackgroundTransparency=1
        il.Text=string.format("%d st | %d hp",math.floor(data.d),math.floor(data.hp))
        il.TextColor3=C.Sub; il.Font=Enum.Font.Gotham
        il.TextSize=10; il.TextXAlignment=Enum.TextXAlignment.Left; il.Parent=row
        local tb=Instance.new("TextButton")
        tb.Size=UDim2.new(0,55,0,26); tb.Position=UDim2.new(1,-60,0,4)
        tb.BackgroundColor3=C.Green; tb.BorderSizePixel=0
        tb.Text="TP"; tb.TextColor3=Color3.fromRGB(0,0,0)
        tb.Font=Enum.Font.GothamBold; tb.TextSize=11; tb.Parent=row
        local tbc=Instance.new("UICorner"); tbc.CornerRadius=UDim.new(0,5); tbc.Parent=tb
        tb.MouseButton1Click:Connect(function() tpToPlayer(p) end)
    end
end
createButton(tpInner,"ОБНОВИТЬ",C.Accent2,function() refreshTP() end)
task.spawn(function()
    task.wait(1)
    while task.wait(0.5) do pcall(refreshTP) end
end)

local _,espInner=createSection("👁 ESP")
createToggle(espInner,"ESP",function(on) State.ESP=on; if not on then clearESP() end end)
createToggle(espInner,"Box",function(on) State.ESPBox=on; clearESP() end)
createToggle(espInner,"Имя",function(on) State.ESPName=on; clearESP() end)
createToggle(espInner,"HP+Дист",function(on) State.ESPHP=on; clearESP() end)

local _,moveInner=createSection("🦘 ДВИЖЕНИЕ")
createToggle(moveInner,"FLY",function(on) State.Fly=on; if on then startFly() else stopFly() end end)
createToggle(moveInner,"NOCLIP",function(on) State.Noclip=on; if on then startNoclip() else stopNoclip() end end)
createToggle(moveInner,"CLICK TP",function(on) State.ClickTP=on end)

local _,spdInner=createSection("💨 SPEED (16-500)")
createInputRow(spdInner,"Скорость","50","OK",function(txt)
    if setSpeed(txt) then notify("Скорость: "..txt,1.5) end
end)
createButton(spdInner,"СБРОС 16",C.Sub,function() setSpeed(16) end)

local _,musInner=createSection("🎵 MUSIC")
createInputRow(musInner,"ID",Config.DefaultMusic,"ИГРАТЬ",function(txt) playMusic(txt) end)
createButton(musInner,"СТОП",C.Red,function() stopMusic() end)

local _,visInner=createSection("🎨 ВИЗУАЛ")
createToggle(visInner,"FULLBRIGHT",function(on) State.Fullbright=on; if on then enableFB() else disableFB() end end)
createToggle(visInner,"RAINBOW",function(on) State.RainbowChar=on; if on then startRainbow() else stopRainbow() end end)

local _,utInner=createSection("🛡 УТИЛИТЫ")
createToggle(utInner,"ANTI-FLING",function(on) State.AntiFling=on end)
createToggle(utInner,"ANTI-AFK",function(on) State.AntiAFK=on end)
createToggle(utInner,"AUTO-COLLECT",function(on) State.AutoCollect=on end)
createToggle(utInner,"GOD MODE",function(on) State.GodMode=on end)

local _,perfInner=createSection("⚡ ПРОИЗВОДИТЕЛЬНОСТЬ")
createButton(perfInner,"FPS BOOSTER",C.Green,function() fpsBoost() end)
createButton(perfInner,"REJOIN",C.Orange,function()
    notify("Rejoin...",2); task.wait(0.5)
    TeleportService:Teleport(game.PlaceId,LP)
end)

local _,sizeInner=createSection("📏 РАЗМЕР (0.1-10)")
createInputRow(sizeInner,"Масштаб","1","OK",function(txt) setSize(txt) end)

-- МИНИ-КНОПКИ AB/SB/IJ
local _,uiInner=createSection("📌 МИНИ-КНОПКИ")
local showMiniBtn=Instance.new("TextButton")
showMiniBtn.Size=UDim2.new(1,0,0,30)
showMiniBtn.BackgroundColor3=C.Panel2
showMiniBtn.BorderSizePixel=0
showMiniBtn.TextColor3=C.Text
showMiniBtn.Font=Enum.Font.GothamBold
showMiniBtn.TextSize=11
showMiniBtn.Text="  ПОКАЗЫВАТЬ БЕЗ МЕНЮ : ВЫКЛ"
showMiniBtn.TextXAlignment=Enum.TextXAlignment.Left
showMiniBtn.Parent=uiInner
local smc=Instance.new("UICorner"); smc.CornerRadius=UDim.new(0,6); smc.Parent=showMiniBtn
local sms=Instance.new("UIStroke"); sms.Color=C.Red; sms.Thickness=1; sms.Parent=showMiniBtn
showMiniBtn.MouseButton1Click:Connect(function()
    State.ShowMini=not State.ShowMini
    if State.ShowMini then
        showMiniBtn.Text="  ПОКАЗЫВАТЬ БЕЗ МЕНЮ : ВКЛ"
        showMiniBtn.TextColor3=C.Green; sms.Color=C.Green
        if not MainFrame.Visible then MiniPanel.Visible=true end
    else
        showMiniBtn.Text="  ПОКАЗЫВАТЬ БЕЗ МЕНЮ : ВЫКЛ"
        showMiniBtn.TextColor3=C.Text; sms.Color=C.Red
        MiniPanel.Visible=false
    end
end)

-- ПАНЕЛЬ AB/SB/IJ
local MiniPanel=Instance.new("Frame")
MiniPanel.Size=UDim2.new(0,56,0,180)
MiniPanel.Position=UDim2.new(0,20,0,160)
MiniPanel.BackgroundColor3=C.Bg
MiniPanel.BackgroundTransparency=0.15
MiniPanel.BorderSizePixel=0
MiniPanel.Active=true
MiniPanel.Draggable=true
MiniPanel.Visible=false
MiniPanel.Parent=SG
local mpc=Instance.new("UICorner"); mpc.CornerRadius=UDim.new(0,12); mpc.Parent=MiniPanel
local mps=Instance.new("UIStroke"); mps.Color=C.Accent; mps.Thickness=2; mps.Parent=MiniPanel
local mpLayout=Instance.new("UIListLayout")
mpLayout.Padding=UDim.new(0,5)
mpLayout.SortOrder=Enum.SortOrder.LayoutOrder
mpLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
mpLayout.VerticalAlignment=Enum.VerticalAlignment.Center
mpLayout.Parent=MiniPanel
local mpPad=Instance.new("UIPadding")
mpPad.PaddingTop=UDim.new(0,6); mpPad.PaddingBottom=UDim.new(0,6)
mpPad.Parent=MiniPanel

local function createMiniToggle(parent,label,getState,setState)
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(0,42,0,42)
    btn.BackgroundColor3=C.Red
    btn.BorderSizePixel=0
    btn.Text=label
    btn.TextColor3=Color3.fromRGB(255,255,255)
    btn.Font=Enum.Font.GothamBold
    btn.TextSize=14
    btn.Parent=parent
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=btn
    local function applyColor()
        if getState() then
            btn.BackgroundColor3=C.Green; btn.TextColor3=Color3.fromRGB(0,0,0)
        else
            btn.BackgroundColor3=C.Red; btn.TextColor3=Color3.fromRGB(255,255,255)
        end
    end
    applyColor()
    btn.MouseButton1Click:Connect(function()
        setState(not getState()); applyColor()
    end)
    return btn,applyColor
end

local _,refreshMiniAB=createMiniToggle(MiniPanel,"AB",
    function() return State.AimBot end,
    function(v) State.AimBot=v; setAimState(v) end)
local _,refreshMiniSB=createMiniToggle(MiniPanel,"SB",
    function() return State.SpinBot end,
    function(v) State.SpinBot=v; if v then startSpin() else stopSpin() end; setSpinState(v) end)
local _,refreshMiniIJ=createMiniToggle(MiniPanel,"IJ",
    function() return State.InfJump end,
    function(v) State.InfJump=v; setInfState(v) end)

-- КРУГ "AD" ДЛЯ РАЗВОРОТА
local MiniIcon=Instance.new("TextButton")
MiniIcon.Size=UDim2.new(0,50,0,50)
MiniIcon.Position=UDim2.new(0,20,0,60)
MiniIcon.BackgroundColor3=C.Bg
MiniIcon.BorderSizePixel=0
MiniIcon.Text="AD"
MiniIcon.TextColor3=C.Accent
MiniIcon.Font=Enum.Font.GothamBold
MiniIcon.TextSize=16
MiniIcon.Visible=false
MiniIcon.Active=true
MiniIcon.Draggable=true
MiniIcon.Parent=SG
local mic=Instance.new("UICorner"); mic.CornerRadius=UDim.new(1,0); mic.Parent=MiniIcon
local mis=Instance.new("UIStroke"); mis.Color=C.Accent; mis.Thickness=2; mis.Parent=MiniIcon

-- ЛОГИКА
MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible=false
    MiniIcon.Visible=true
    if State.ShowMini then MiniPanel.Visible=true end
    notify("Свёрнуто",1.5,C.Orange)
end)
MiniIcon.MouseButton1Click:Connect(function()
    MainFrame.Visible=true
    MiniIcon.Visible=false
    MiniPanel.Visible=false
    refreshMiniAB(); refreshMiniSB(); refreshMiniIJ()
end)
CloseBtn.MouseButton1Click:Connect(function()
    stopMusic(); stopFly(); stopNoclip(); stopSpin(); stopRainbow()
    clearESP(); disableFB()
    for _,c in ipairs(Connections) do disc(c) end
    Connections={}
    SG:Destroy()
end)

notify("⚡ DELTA HUB MOBILE загружен!",2.5,C.Accent)
print("[ТГК КАНАЛ СОЗДАТЕЛЕЙ DELTA_ROBLOX_2] GUI parent:", GUI_PARENT:GetFullName())
