-- Generado con GuiMaker
local gui = Instance.new("ScreenGui")
gui.Name = "ScreenGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Modules, __mods, __runs = {}, {}, {}
local __req = require
local function require(m) if type(m) == "string" then return Modules[m] elseif type(m) == "table" then return m end return __req(m) end
do
  local _1_0 = Instance.new("Frame")
  _1_0.Name = "#1"
  _1_0.Position = UDim2.new(0, 268, 0, 49)
  _1_0.Size = UDim2.new(0, 329, 0, 234)
  _1_0.BackgroundColor3 = Color3.fromRGB(19, 9, 11)
  _1_0.BorderSizePixel = 0
  _1_0.Parent = gui
  do
    local UICorner_1 = Instance.new("UICorner")
    UICorner_1.Name = "UICorner"
    UICorner_1.Parent = _1_0
  end
  do
    local UIStroke_1 = Instance.new("UIStroke")
    UIStroke_1.Name = "UIStroke"
    UIStroke_1.Color = Color3.fromRGB(144, 0, 0)
    UIStroke_1.Parent = _1_0
  end
  do
    local script = {Parent = _1_0, Name = "principalaim"}
    __runs[#__runs + 1] = function()
-- AimAssistEyes.client.lua
-- AimAssist personalizado + FOV rojo + Sliders rojos + ON/OFF

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Squads = ReplicatedStorage:WaitForChild("Squads")
local LocalPlayer = Players.LocalPlayer

local AimAssist = require(
    ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AimAssist")
)

-- CONFIGURACIÓN

local SMOOTHNESS = 70
local TARGET_SCAN_INTERVAL = 0.12
local MAX_CENTER_DISTANCE = 550
local MAX_TARGET_DISTANCE = 2000

-- CONTROLES GUI

local GuiControls = {
    Principal = nil,
    FOVEnabled = nil,
    ShowFOV = nil,
    FOVSize = nil,
    AimSmoothness = nil
}

local IsEnabled = false
local FOVEnabled = false
local ShowFOVEnabled = false

local CurrentFOVSize = 150
local CurrentSmoothness = 70

-- PERSONAJE Y CÁMARA

local CurrentCamera = Workspace.CurrentCamera
local CurrentCharacter = LocalPlayer.Character
local IsAiming = false
local CurrentTarget = nil
local ScanTimer = 0

-- SERVICIOS GUI

local CoreGui = game:GetService("CoreGui")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- BUSCAR GUI

local function FindGuiObject(Name)
    local Object = PlayerGui:FindFirstChild(Name, true)

    if Object then
        return Object
    end

    local Success, Result = pcall(function()
        return CoreGui:FindFirstChild(Name, true)
    end)

    if Success and Result then
        return Result
    end

    return nil
end

-- ENCONTRAR BOTONES

local function GetButton(Object)
    if not Object then
        return nil
    end

    if Object:IsA("GuiButton") then
        return Object
    end

    return Object:FindFirstChildWhichIsA("GuiButton", true)
end

local function ConnectToggle(Object, Callback)
    local Button = GetButton(Object)

    if not Button then
        warn("[AimAssistEyes] No se encontró botón:", Object and Object.Name)
        return
    end

    Button.Activated:Connect(Callback)
end

-- TEXTO ON/OFF

local function SetButtonState(Object, State)
    local Button = GetButton(Object)

    if not Button then
        return
    end

    local StateText = State and "ON" or "OFF"

    if Button:IsA("TextButton") then
        Button.Text = Object.Name .. " " .. StateText

        Button.TextColor3 = State
            and Color3.fromRGB(0, 255, 100)
            or Color3.fromRGB(255, 50, 50)
    end
end

-- CÍRCULO FOV

local FOVGui = Instance.new("ScreenGui")
FOVGui.Name = "AimAssistFOV"
FOVGui.ResetOnSpawn = false
FOVGui.IgnoreGuiInset = true
FOVGui.DisplayOrder = 999998
FOVGui.Parent = PlayerGui

local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "Circle"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.Position = UDim2.fromScale(0.5, 0.5)
FOVCircle.Size = UDim2.fromOffset(CurrentFOVSize * 2, CurrentFOVSize * 2)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Visible = false
FOVCircle.Parent = FOVGui

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = FOVCircle

local CircleStroke = Instance.new("UIStroke")
CircleStroke.Color = Color3.fromRGB(255, 35, 45)
CircleStroke.Thickness = 2
CircleStroke.Transparency = 0.1
CircleStroke.Parent = FOVCircle

local function UpdateFOVVisual()
    FOVCircle.Size = UDim2.fromOffset(
        CurrentFOVSize * 2,
        CurrentFOVSize * 2
    )

    FOVCircle.Visible = FOVEnabled and ShowFOVEnabled
end

-- SLIDERS

local function CreateSlider(Object, Minimum, Maximum, InitialValue, Callback, Name)
    if not Object or not Object:IsA("GuiObject") then
        warn("[AimAssistEyes] Slider no encontrado:", Name)
        return
    end

    Object.Active = true
    Object.ClipsDescendants = false

    local InitialPercentage = math.clamp(
        (InitialValue - Minimum) / (Maximum - Minimum),
        0,
        1
    )

    -- BARRA DE PROGRESO

    local Fill = Instance.new("Frame")
    Fill.Name = "AimAssistSliderFill"
    Fill.AnchorPoint = Vector2.new(0, 0.5)
    Fill.Position = UDim2.new(0, 0, 0.5, 0)
    Fill.Size = UDim2.new(InitialPercentage, 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(255, 30, 40)
    Fill.BorderSizePixel = 0
    Fill.ZIndex = Object.ZIndex + 1
    Fill.Active = false
    Fill.Parent = Object

    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(1, 0)
    FillCorner.Parent = Fill

    local FillGradient = Instance.new("UIGradient")
    FillGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 0, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 55))
    })
    FillGradient.Parent = Fill

    local FillStroke = Instance.new("UIStroke")
    FillStroke.Color = Color3.fromRGB(255, 35, 45)
    FillStroke.Thickness = 1
    FillStroke.Transparency = 0.55
    FillStroke.Parent = Fill

    -- CONTROL DESLIZANTE

    local Knob = Instance.new("Frame")
    Knob.Name = "AimAssistSliderKnob"
    Knob.Size = UDim2.fromOffset(17, 17)
    Knob.AnchorPoint = Vector2.new(0.5, 0.5)
    Knob.Position = UDim2.new(InitialPercentage, 0, 0.5, 0)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 35, 45)
    Knob.BorderSizePixel = 0
    Knob.ZIndex = Object.ZIndex + 4
    Knob.Active = false
    Knob.Parent = Object

    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob

    local KnobStroke = Instance.new("UIStroke")
    KnobStroke.Color = Color3.fromRGB(255, 255, 255)
    KnobStroke.Thickness = 2
    KnobStroke.Transparency = 0.05
    KnobStroke.Parent = Knob

    -- VALOR

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Name = "AimAssistSliderValue"
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Size = UDim2.new(1, 0, 1, 0)
    ValueLabel.Position = UDim2.new(0, 0, 0, 0)
    ValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ValueLabel.TextSize = 12
    ValueLabel.Font = Enum.Font.GothamBold
    ValueLabel.ZIndex = Object.ZIndex + 2
    ValueLabel.Active = false
    ValueLabel.Parent = Object

    local Value = InitialValue

    local Dragging = false
    local ActiveTouch = nil
    local ActiveMouse = false

    local KnobTween = nil
    local FillTween = nil

    local AnimationInfo = TweenInfo.new(
        0.07,
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    )

    local function UpdateSlider(InputPosition)
        local Width = Object.AbsoluteSize.X

        if Width <= 0 then
            return
        end

        local RelativeX = math.clamp(
            (InputPosition.X - Object.AbsolutePosition.X) / Width,
            0,
            1
        )

        local NewValue = math.floor(
            Minimum + RelativeX * (Maximum - Minimum) + 0.5
        )

        local NewPercentage = math.clamp(
            (NewValue - Minimum) / (Maximum - Minimum),
            0,
            1
        )

        if KnobTween then
            KnobTween:Cancel()
        end

        if FillTween then
            FillTween:Cancel()
        end

        KnobTween = TweenService:Create(
            Knob,
            AnimationInfo,
            {
                Position = UDim2.new(NewPercentage, 0, 0.5, 0),
                Size = UDim2.fromOffset(18, 18)
            }
        )

        FillTween = TweenService:Create(
            Fill,
            AnimationInfo,
            {
                Size = UDim2.new(NewPercentage, 0, 1, 0)
            }
        )

        KnobTween:Play()
        FillTween:Play()

        if NewValue == Value then
            return
        end

        Value = NewValue

        ValueLabel.Text = Name .. ": " .. tostring(Value)

        Callback(Value)
    end

    ValueLabel.Text = Name .. ": " .. tostring(Value)

    local function BeginDrag(Input)
        if Dragging then
            return
        end

        if Input.UserInputType == Enum.UserInputType.Touch then
            ActiveTouch = Input
            ActiveMouse = false
            Dragging = true

            UpdateSlider(Input.Position)

        elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
            ActiveMouse = true
            ActiveTouch = nil
            Dragging = true

            UpdateSlider(Input.Position)
        end
    end

    Object.InputBegan:Connect(BeginDrag)
    Fill.InputBegan:Connect(BeginDrag)
    Knob.InputBegan:Connect(BeginDrag)
    ValueLabel.InputBegan:Connect(BeginDrag)

    UserInputService.InputChanged:Connect(function(Input)
        if not Dragging or not ActiveMouse then
            return
        end

        if Input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateSlider(Input.Position)
        end
    end)

    UserInputService.TouchMoved:Connect(function(Input)
        if not Dragging then
            return
        end

        if ActiveTouch and Input == ActiveTouch then
            UpdateSlider(Input.Position)
        end
    end)

    UserInputService.TouchEnded:Connect(function(Input)
        if ActiveTouch and Input == ActiveTouch then
            ActiveTouch = nil
            Dragging = false
        end
    end)

    UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1
            and ActiveMouse then

            ActiveMouse = false
            Dragging = false
        end
    end)

    Callback(InitialValue)
end

-- BUSCAR CONTROLES

GuiControls.Principal = FindGuiObject("Principal")
GuiControls.FOVEnabled = FindGuiObject("FOV")
GuiControls.ShowFOV = FindGuiObject("ShowFOV")
GuiControls.FOVSize = FindGuiObject("FOVSize")
GuiControls.AimSmoothness = FindGuiObject("AimSmoothness")

-- FUNCIONES ORIGINALES

local OriginalValues = {
    Init = AimAssist.Init,
    SetCharacter = AimAssist.SetCharacter,
    SetAiming = AimAssist.SetAiming,
    GetAdjustment = AimAssist.GetAdjustment
}

-- BOTÓN PRINCIPAL

ConnectToggle(GuiControls.Principal, function()
    IsEnabled = not IsEnabled

    SetButtonState(GuiControls.Principal, IsEnabled)

    if not IsEnabled then
        CurrentTarget = nil
        ScanTimer = 0
    end

    print("[AimAssistEyes] Principal:", IsEnabled)
end)

-- BOTÓN FOV

ConnectToggle(GuiControls.FOVEnabled, function()
    FOVEnabled = not FOVEnabled

    SetButtonState(GuiControls.FOVEnabled, FOVEnabled)
    UpdateFOVVisual()

    print("[AimAssistEyes] FOV:", FOVEnabled)
end)

-- BOTÓN SHOW FOV

ConnectToggle(GuiControls.ShowFOV, function()
    ShowFOVEnabled = not ShowFOVEnabled

    SetButtonState(GuiControls.ShowFOV, ShowFOVEnabled)
    UpdateFOVVisual()

    print("[AimAssistEyes] ShowFOV:", ShowFOVEnabled)
end)

-- ESTADOS INICIALES

SetButtonState(GuiControls.Principal, false)
SetButtonState(GuiControls.FOVEnabled, false)
SetButtonState(GuiControls.ShowFOV, false)

-- SLIDER FOV SIZE

CreateSlider(
    GuiControls.FOVSize,
    20,
    550,
    CurrentFOVSize,

    function(Value)
        CurrentFOVSize = Value
        UpdateFOVVisual()
    end,

    "FOVSize"
)

-- SLIDER AIM SMOOTHNESS

CreateSlider(
    GuiControls.AimSmoothness,
    1,
    150,
    CurrentSmoothness,

    function(Value)
        CurrentSmoothness = Value
        SMOOTHNESS = Value
    end,

    "AimSmoothness"
)

-- EQUIPO

local function GetMySquad()
    for _, Squad in ipairs(Squads:GetChildren()) do
        if Squad:FindFirstChild(LocalPlayer.Name, true) then
            return Squad
        end
    end

    return nil
end

local function IsTeammate(Character)
    if not Character then
        return false
    end

    local MySquad = GetMySquad()

    if not MySquad then
        return false
    end

    return MySquad:FindFirstChild(Character.Name, true) ~= nil
end

-- ATTACHMENTS DE LOS OJOS

local function FindEyeAttachment(Head, Names)
    for _, Name in ipairs(Names) do
        local Object = Head:FindFirstChild(Name, true)

        if Object and Object:IsA("Attachment") then
            return Object
        end
    end

    return nil
end

local function GetEyePosition(Character)
    if not Character then
        return nil
    end

    local Head = Character:FindFirstChild("Head")

    if not Head or not Head:IsA("BasePart") then
        return nil
    end

    local LeftEye = FindEyeAttachment(Head, {
        "LeftEyeAttachment",
        "LeftEye",
        "EyeLeft"
    })

    local RightEye = FindEyeAttachment(Head, {
        "RightEyeAttachment",
        "RightEye",
        "EyeRight"
    })

    if LeftEye and RightEye then
        return (LeftEye.WorldPosition + RightEye.WorldPosition) / 2
    end

    return Head.Position + Head.CFrame.UpVector * (Head.Size.Y * 0.10)
end

-- VISIBILIDAD

local function HasLineOfSight(Camera, Character, EyePosition)
    local Params = RaycastParams.new()

    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {
        CurrentCharacter,
        Camera
    }

    Params.IgnoreWater = true

    local Origin = Camera.CFrame.Position
    local Direction = EyePosition - Origin

    local Result = Workspace:Raycast(
        Origin,
        Direction,
        Params
    )

    return Result == nil or Result.Instance:IsDescendantOf(Character)
end

-- VALIDAR OBJETIVOS

local function IsValidTarget(Character)
    if not Character
        or not Character:IsA("Model")
        or Character == CurrentCharacter
        or not Character.Parent then

        return false
    end

    if IsTeammate(Character) then
        return false
    end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local Head = Character:FindFirstChild("Head")

    return Humanoid ~= nil
        and Humanoid.Health > 0
        and Head ~= nil
        and Head:IsA("BasePart")
end

-- BUSCAR OBJETIVO

local function FindBestTarget(Camera)
    local Viewport = Camera.ViewportSize

    local ScreenCenter = Vector2.new(
        Viewport.X / 2,
        Viewport.Y / 2
    )

    local BestTarget = nil

    local SearchDistance = MAX_CENTER_DISTANCE

    if FOVEnabled then
        SearchDistance = CurrentFOVSize
    end

    local BestScreenDistance = SearchDistance
    local Seen = {}

    local function CheckCharacter(Character)
        if Seen[Character] then
            return
        end

        Seen[Character] = true

        if not IsValidTarget(Character) then
            return
        end

        local EyePosition = GetEyePosition(Character)

        if not EyePosition then
            return
        end

        if not HasLineOfSight(Camera, Character, EyePosition) then
            return
        end

        local WorldDistance = (
            EyePosition - Camera.CFrame.Position
        ).Magnitude

        if WorldDistance > MAX_TARGET_DISTANCE then
            return
        end

        local ScreenPosition, OnScreen =
            Camera:WorldToViewportPoint(EyePosition)

        if not OnScreen or ScreenPosition.Z <= 0 then
            return
        end

        local ScreenDistance = (
            Vector2.new(ScreenPosition.X, ScreenPosition.Y)
            - ScreenCenter
        ).Magnitude

        if ScreenDistance < BestScreenDistance then
            BestScreenDistance = ScreenDistance
            BestTarget = Character
        end
    end

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character then
            CheckCharacter(Player.Character)
        end
    end

    for _, Object in ipairs(Workspace:GetDescendants()) do
        if Object:IsA("Model")
            and Object:GetAttribute("IsBot") == true then

            CheckCharacter(Object)
        end
    end

    return BestTarget
end

-- SUAVIDAD

local function ApplySmoothnessAdjustment(DeltaTime)
    local Alpha = 1 - math.exp(-SMOOTHNESS * DeltaTime)

    return Alpha
end

-- INICIALIZACIÓN

AimAssist.Init = function(Camera)
    CurrentCamera = Camera or Workspace.CurrentCamera

    if OriginalValues.Init then
        return OriginalValues.Init(Camera)
    end
end

AimAssist.SetCharacter = function(Character)
    CurrentCharacter = Character
    CurrentTarget = nil
    ScanTimer = TARGET_SCAN_INTERVAL

    if OriginalValues.SetCharacter then
        return OriginalValues.SetCharacter(Character)
    end
end

AimAssist.SetAiming = function(Value)
    IsAiming = Value == true

    if not IsAiming then
        CurrentTarget = nil
        ScanTimer = 0
    end

    if OriginalValues.SetAiming then
        return OriginalValues.SetAiming(Value)
    end
end

-- ACTUALIZACIÓN AIM ASSIST

AimAssist.GetAdjustment = function(DeltaTime)

    -- PRINCIPAL OFF: AIM ASSIST ORIGINAL

    if not IsEnabled then
        if OriginalValues.GetAdjustment then
            return OriginalValues.GetAdjustment(DeltaTime)
        end

        return Vector2.zero
    end

    -- PRINCIPAL ON: PERSONALIZADO

    if not IsAiming then
        return Vector2.zero
    end

    local Camera = Workspace.CurrentCamera or CurrentCamera

    if not Camera then
        return Vector2.zero
    end

    CurrentCamera = Camera

    DeltaTime = math.clamp(
        tonumber(DeltaTime) or (1 / 60),
        0,
        0.1
    )

    if CurrentTarget and not IsValidTarget(CurrentTarget) then
        CurrentTarget = nil
        ScanTimer = TARGET_SCAN_INTERVAL
    end

    ScanTimer += DeltaTime

    if ScanTimer >= TARGET_SCAN_INTERVAL then
        ScanTimer = 0
        CurrentTarget = FindBestTarget(Camera)
    end

    if not CurrentTarget then
        return Vector2.zero
    end

    local EyePosition = GetEyePosition(CurrentTarget)

    if not EyePosition then
        CurrentTarget = nil
        return Vector2.zero
    end

    local LocalPosition = Camera.CFrame:PointToObjectSpace(EyePosition)

    if LocalPosition.Z >= 0 then
        return Vector2.zero
    end

    local HorizontalDistance = math.sqrt(
        LocalPosition.X * LocalPosition.X
        + LocalPosition.Z * LocalPosition.Z
    )

    if HorizontalDistance < 0.001 then
        HorizontalDistance = 0.001
    end

    local YawError = math.atan2(
        LocalPosition.X,
        -LocalPosition.Z
    )

    local PitchError = -math.atan2(
        LocalPosition.Y,
        HorizontalDistance
    )

    local Alpha = ApplySmoothnessAdjustment(DeltaTime)

    return Vector2.new(
        YawError * Alpha,
        PitchError * Alpha
    )
end

-- REAPARICIÓN

LocalPlayer.CharacterAdded:Connect(function(Character)
    CurrentCharacter = Character
    CurrentTarget = nil
    ScanTimer = TARGET_SCAN_INTERVAL

    if OriginalValues.SetCharacter then
        OriginalValues.SetCharacter(Character)
    end
end)

-- INICIALIZACIÓN FINAL

if CurrentCharacter and OriginalValues.SetCharacter then
    OriginalValues.SetCharacter(CurrentCharacter)
end

print("[AimAssistEyes] Conectado al módulo AimAssist.")
    end
  end
  do
    local titulo_1 = Instance.new("Frame")
    titulo_1.Name = "titulo"
    titulo_1.Position = UDim2.new(0, -1, 0, -1)
    titulo_1.Size = UDim2.new(0, 331, 0, 35)
    titulo_1.BackgroundColor3 = Color3.fromRGB(159, 16, 41)
    titulo_1.BorderSizePixel = 0
    titulo_1.Parent = _1_0
    do
      local UICorner_2 = Instance.new("UICorner")
      UICorner_2.Name = "UICorner"
      UICorner_2.Parent = titulo_1
    end
    do
      local UIStroke_2 = Instance.new("UIStroke")
      UIStroke_2.Name = "UIStroke"
      UIStroke_2.Color = Color3.fromRGB(255, 164, 164)
      UIStroke_2.Parent = titulo_1
    end
    do
      local TextLabel_2 = Instance.new("TextLabel")
      TextLabel_2.Name = "TextLabel"
      TextLabel_2.Position = UDim2.new(0, 2, 0, 1)
      TextLabel_2.Size = UDim2.new(0, 177, 0, 33)
      TextLabel_2.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
      TextLabel_2.BackgroundTransparency = 1
      TextLabel_2.BorderSizePixel = 0
      TextLabel_2.Text = "   painel oxmarx ff     @oxmarx62636"
      TextLabel_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      TextLabel_2.TextSize = 16
      TextLabel_2.Font = Enum.Font.GothamBlack
      TextLabel_2.TextXAlignment = Enum.TextXAlignment.Left
      TextLabel_2.Parent = titulo_1
    end
  end
  do
    local script = {Parent = _1_0, Name = "drag"}
    __runs[#__runs + 1] = function()

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Frame = script.Parent

local dragging = false
local dragInput
local dragStart
local startPosition

Frame.Active = true

local function ClampPosition(position)
    local camera = workspace.CurrentCamera
    if not camera then return position end

    local viewport = camera.ViewportSize
    local size = Frame.AbsoluteSize

    local x = math.clamp(
        position.X.Offset, 0,
        math.max(0, viewport.X - size.X)
    )

    local y = math.clamp(
        position.Y.Offset, 0,
        math.max(0, viewport.Y - size.Y)
    )

    return UDim2.new(
        position.X.Scale, x,
        position.Y.Scale, y
    )
end

local function IsInsideFrame(input)
    local p = input.Position
    local pos = Frame.AbsolutePosition
    local size = Frame.AbsoluteSize

    return p.X >= pos.X
        and p.X <= pos.X + size.X
        and p.Y >= pos.Y
        and p.Y <= pos.Y + size.Y
end

Frame.InputBegan:Connect(function(input)
    if dragging then return end

    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    if not IsInsideFrame(input) then return end

    dragging = true
    dragInput = input
    dragStart = input.Position
    startPosition = Frame.Position
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end

    local validInput =
        input == dragInput
        or (
            dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        )

    if not validInput then return end

    local delta = input.Position - dragStart

    local newPosition = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )

    Frame.Position = ClampPosition(newPosition)
end)

UserInputService.InputEnded:Connect(function(input)
    if not dragging then return end

    if input == dragInput or (
        dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1
    ) then
        dragging = false
        dragInput = nil
        dragStart = nil
        startPosition = nil
    end
end)

RunService.RenderStepped:Connect(function()
    if not dragging then
        local clamped = ClampPosition(Frame.Position)

        if clamped ~= Frame.Position then
            Frame.Position = clamped
        end
    end
end)

    end
  end
  do
    local center_1_1 = Instance.new("Frame")
    center_1_1.Name = "center#1"
    center_1_1.Position = UDim2.new(0, 7, 0, 61)
    center_1_1.Size = UDim2.new(0, 315, 0, 168)
    center_1_1.BackgroundColor3 = Color3.fromRGB(63, 0, 6)
    center_1_1.BorderSizePixel = 0
    center_1_1.Visible = false
    center_1_1.Parent = _1_0
    do
      local AimSmoothness_2 = Instance.new("TextButton")
      AimSmoothness_2.Name = "AimSmoothness"
      AimSmoothness_2.Position = UDim2.new(0, 4, 0, 139)
      AimSmoothness_2.Size = UDim2.new(0, 304, 0, 23)
      AimSmoothness_2.BackgroundColor3 = Color3.fromRGB(52, 0, 0)
      AimSmoothness_2.BorderSizePixel = 0
      AimSmoothness_2.Text = ""
      AimSmoothness_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      AimSmoothness_2.TextSize = 16
      AimSmoothness_2.Font = Enum.Font.GothamMedium
      AimSmoothness_2.Parent = center_1_1
      do
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Name = "UICorner"
        UICorner_3.Parent = AimSmoothness_2
      end
    end
    do
      local FOVSize_2 = Instance.new("TextButton")
      FOVSize_2.Name = "FOVSize"
      FOVSize_2.Position = UDim2.new(0, 4, 0, 108)
      FOVSize_2.Size = UDim2.new(0, 304, 0, 23)
      FOVSize_2.BackgroundColor3 = Color3.fromRGB(52, 0, 0)
      FOVSize_2.BorderSizePixel = 0
      FOVSize_2.Text = ""
      FOVSize_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      FOVSize_2.TextSize = 16
      FOVSize_2.Font = Enum.Font.GothamMedium
      FOVSize_2.Parent = center_1_1
      do
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Name = "UICorner"
        UICorner_3.Parent = FOVSize_2
      end
    end
    do
      local UICorner_2 = Instance.new("UICorner")
      UICorner_2.Name = "UICorner"
      UICorner_2.Parent = center_1_1
    end
    do
      local ShowFOV_2 = Instance.new("TextButton")
      ShowFOV_2.Name = "ShowFOV"
      ShowFOV_2.Position = UDim2.new(0, 4, 0, 75)
      ShowFOV_2.Size = UDim2.new(0, 304, 0, 23)
      ShowFOV_2.BackgroundColor3 = Color3.fromRGB(52, 0, 0)
      ShowFOV_2.BorderSizePixel = 0
      ShowFOV_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      ShowFOV_2.TextSize = 16
      ShowFOV_2.Font = Enum.Font.GothamMedium
      ShowFOV_2.Parent = center_1_1
      do
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Name = "UICorner"
        UICorner_3.Parent = ShowFOV_2
      end
    end
    do
      local FOV_2 = Instance.new("TextButton")
      FOV_2.Name = "FOV"
      FOV_2.Position = UDim2.new(0, 4, 0, 43)
      FOV_2.Size = UDim2.new(0, 304, 0, 23)
      FOV_2.BackgroundColor3 = Color3.fromRGB(52, 0, 0)
      FOV_2.BorderSizePixel = 0
      FOV_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      FOV_2.TextSize = 16
      FOV_2.Font = Enum.Font.GothamMedium
      FOV_2.Parent = center_1_1
      do
        local script = {Parent = FOV_2, Name = "fov"}
        __runs[#__runs + 1] = function()
local gui = script.Parent:FindFirstAncestorOfClass("ScreenGui")
if not gui then return end

if gui:GetAttribute("FOV") == nil then
    gui:SetAttribute("FOV", false)
end

script.Parent.Activated:Connect(function()
    local value = not gui:GetAttribute("FOV")
    gui:SetAttribute("FOV", value)
    script.Parent.Text = value and "FOV: ON" or "FOV: OFF"
end)
        end
      end
      do
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Name = "UICorner"
        UICorner_3.Parent = FOV_2
      end
    end
    do
      local Principal_2 = Instance.new("TextButton")
      Principal_2.Name = "Principal"
      Principal_2.Position = UDim2.new(0, 4, 0, 8)
      Principal_2.Size = UDim2.new(0, 304, 0, 26)
      Principal_2.BackgroundColor3 = Color3.fromRGB(52, 0, 0)
      Principal_2.BorderSizePixel = 0
      Principal_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      Principal_2.TextSize = 16
      Principal_2.Font = Enum.Font.GothamBlack
      Principal_2.Parent = center_1_1
      do
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Name = "UICorner"
        UICorner_3.Parent = Principal_2
      end
    end
  end
  do
    local menus_1 = Instance.new("Frame")
    menus_1.Name = "menus"
    menus_1.Position = UDim2.new(0, 7, 0, 39)
    menus_1.Size = UDim2.new(0, 315, 0, 18)
    menus_1.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    menus_1.BackgroundTransparency = 0.8
    menus_1.BorderSizePixel = 0
    menus_1.Parent = _1_0
    do
      local UICorner_2 = Instance.new("UICorner")
      UICorner_2.Name = "UICorner"
      UICorner_2.Parent = menus_1
    end
    do
      local button_1_2 = Instance.new("TextButton")
      button_1_2.Name = "button#1"
      button_1_2.Position = UDim2.new(0, 5, 0, 3)
      button_1_2.Size = UDim2.new(0, 89, 0, 12)
      button_1_2.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
      button_1_2.BackgroundTransparency = 1
      button_1_2.BorderSizePixel = 0
      button_1_2.Text = "aim"
      button_1_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      button_1_2.TextSize = 16
      button_1_2.Font = Enum.Font.SourceSansItalic
      button_1_2.Parent = menus_1
      do
        local UIStroke_3 = Instance.new("UIStroke")
        UIStroke_3.Name = "UIStroke"
        UIStroke_3.Parent = button_1_2
      end
    end
    do
      local UICorner_2 = Instance.new("UICorner")
      UICorner_2.Name = "UICorner"
      UICorner_2.Parent = menus_1
    end
    do
      local UICorner_2 = Instance.new("UICorner")
      UICorner_2.Name = "UICorner"
      UICorner_2.Parent = menus_1
    end
    do
      local button_2_2 = Instance.new("TextButton")
      button_2_2.Name = "button#2"
      button_2_2.Position = UDim2.new(0, 86, 0, 4)
      button_2_2.Size = UDim2.new(0, 89, 0, 12)
      button_2_2.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
      button_2_2.BackgroundTransparency = 1
      button_2_2.BorderSizePixel = 0
      button_2_2.Text = "esp"
      button_2_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      button_2_2.TextSize = 16
      button_2_2.Font = Enum.Font.SourceSansItalic
      button_2_2.Parent = menus_1
      do
        local UIStroke_3 = Instance.new("UIStroke")
        UIStroke_3.Name = "UIStroke"
        UIStroke_3.Parent = button_2_2
      end
    end
  end
  do
    local center_2_1 = Instance.new("Frame")
    center_2_1.Name = "center#2"
    center_2_1.Position = UDim2.new(0, 7, 0, 61)
    center_2_1.Size = UDim2.new(0, 315, 0, 168)
    center_2_1.BackgroundColor3 = Color3.fromRGB(63, 0, 6)
    center_2_1.BorderSizePixel = 0
    center_2_1.Parent = _1_0
    do
      local UICorner_2 = Instance.new("UICorner")
      UICorner_2.Name = "UICorner"
      UICorner_2.Parent = center_2_1
    end
    do
      local centerwelcome_2 = Instance.new("TextButton")
      centerwelcome_2.Name = "centerwelcome"
      centerwelcome_2.Position = UDim2.new(0, 4, 0, 8)
      centerwelcome_2.Size = UDim2.new(0, 304, 0, 26)
      centerwelcome_2.BackgroundColor3 = Color3.fromRGB(52, 0, 0)
      centerwelcome_2.BorderSizePixel = 0
      centerwelcome_2.Text = "🤑"
      centerwelcome_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      centerwelcome_2.TextSize = 16
      centerwelcome_2.Font = Enum.Font.Bodoni
      centerwelcome_2.Parent = center_2_1
      do
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Name = "UICorner"
        UICorner_3.Parent = centerwelcome_2
      end
      do
        local script = {Parent = centerwelcome_2, Name = "masterespfun"}
        __runs[#__runs + 1] = function()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ESP_OPTIONS = {
    Box = "ESP_Box",
    Skeleton = "ESP_Skeleton",
    Line = "ESP_Line",
    Health = "ESP_Health"
}

for _, attribute in pairs(ESP_OPTIONS) do
    if PlayerGui:GetAttribute(attribute) == nil then
        PlayerGui:SetAttribute(attribute, false)
    end
end

local function IsESPEnabled(option)
    return PlayerGui:GetAttribute(option) == true
end
local Camera = workspace.CurrentCamera
local Squads = ReplicatedStorage:WaitForChild("Squads")

local PREFIX = "Down_"
local NORMAL = Color3.fromRGB(255, 255, 255)
local RED = Color3.fromRGB(255, 45, 65)
local WHITE = Color3.fromRGB(245, 250, 255)
local GREEN = Color3.fromRGB(0, 255, 130)
local YELLOW = Color3.fromRGB(255, 210, 40)
local DARK = Color3.fromRGB(12, 15, 20)

-- LOW PERFORMANCE MODE
local SQUAD_INTERVAL = 2
local SCAN_INTERVAL = 0.5
local BOX_INTERVAL = 1 / 30
local SKELETON_INTERVAL = 1 / 30
local HEALTH_INTERVAL = 0.2

local ESP = {}
local Catalog = {}
local DownState = {}
local DisplayedHealth = {}
local SquadCache = {}

local SquadCacheClock = 0
local ScanClock = 0
local BoxClock = 0
local SkeletonClock = 0
local HealthClock = 0

local function GetSquad(player)
for _, squad in ipairs(Squads:GetChildren()) do
if squad:FindFirstChild(player.Name, true) then
return squad
end
end
return nil
end

local function RefreshSquads()
SquadCache = {}
for _, player in ipairs(Players:GetPlayers()) do
SquadCache[player] = GetSquad(player)
end
end

local function IsTeammate(player)
if not player or player == LocalPlayer then
return true
end

local mySquad = SquadCache[LocalPlayer]
local theirSquad = SquadCache[player]

return mySquad ~= nil and theirSquad ~= nil
    and mySquad == theirSquad

end

local function RegisterAnimation(object)
if object:IsA("Animation") and object.AnimationId ~= "" then
Catalog[object.AnimationId] = object.Name
end
end

for _, object in ipairs(game:GetDescendants()) do
RegisterAnimation(object)
end

game.DescendantAdded:Connect(RegisterAnimation)

local function IsDownAnimation(track)
local animation = track.Animation
if not animation then return false end

if string.sub(animation.Name, 1, #PREFIX) == PREFIX then
    return true
end

local name = Catalog[animation.AnimationId]
return name ~= nil
    and string.sub(name, 1, #PREFIX) == PREFIX

end

local function ScanDown(player)
if IsTeammate(player) then
DownState[player] = false
return
end

local character = player.Character
local humanoid = character
    and character:FindFirstChildOfClass("Humanoid")
local animator = humanoid
    and humanoid:FindFirstChildOfClass("Animator")

if not animator then
    DownState[player] = false
    return
end

local down = false

for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
    if IsDownAnimation(track) then
        down = true
        break
    end
end

DownState[player] = down

end

local function NewDrawing(kind)
local object = Drawing.new(kind)
object.Visible = false
return object
end

local function CreateESP(player)
if player == LocalPlayer or ESP[player] then return end

local e = {
    Box = NewDrawing("Square"),
    Line = NewDrawing("Line"),
    HealthBG = NewDrawing("Square"),
    Health = NewDrawing("Square"),
    TopAccent = NewDrawing("Line"),
    BottomAccent = NewDrawing("Line"),
    Corner1 = NewDrawing("Line"),
    Corner2 = NewDrawing("Line"),
    Corner3 = NewDrawing("Line"),
    Corner4 = NewDrawing("Line"),
    Skeleton = {},
    SkeletonBones = {
        {"Head", "UpperTorso", "Torso"},
        {"UpperTorso", "LowerTorso", "Torso"},
        {"UpperTorso", "LeftUpperArm", "Left Arm"},
        {"LeftUpperArm", "LeftLowerArm", "Left Arm"},
        {"LeftLowerArm", "LeftHand", "Left Arm"},
        {"UpperTorso", "RightUpperArm", "Right Arm"},
        {"RightUpperArm", "RightLowerArm", "Right Arm"},
        {"RightLowerArm", "RightHand", "Right Arm"},
        {"LowerTorso", "LeftUpperLeg", "Left Leg"},
        {"LeftUpperLeg", "LeftLowerLeg", "Left Leg"},
        {"LeftLowerLeg", "LeftFoot", "Left Leg"},
        {"LowerTorso", "RightUpperLeg", "Right Leg"},
        {"RightUpperLeg", "RightLowerLeg", "Right Leg"},
        {"RightLowerLeg", "RightFoot", "Right Leg"},
    }
}

ESP[player] = e

e.Box.Thickness = 1.5
e.Box.Filled = false
e.Line.Thickness = 1.3
e.HealthBG.Filled = true
e.HealthBG.Color = DARK
e.Health.Filled = true

for _, name in ipairs({
    "TopAccent", "BottomAccent",
    "Corner1", "Corner2", "Corner3", "Corner4"
}) do
    e[name].Thickness = 2
end

for i = 1, #e.SkeletonBones do
    e.Skeleton[i] = NewDrawing("Line")
    e.Skeleton[i].Thickness = 1.5
end

end

local function HideESP(e)
for _, object in pairs(e) do
if typeof(object) == "table" then
for _, drawing in pairs(object) do
pcall(function()
drawing.Visible = false
end)
end
else
pcall(function()
object.Visible = false
end)
end
end
end

local function RemoveESP(player)
local e = ESP[player]
if e then
for _, object in pairs(e) do
if typeof(object) == "table" then
for _, drawing in pairs(object) do
pcall(function()
drawing:Remove()
end)
end
else
pcall(function()
object:Remove()
end)
end
end
end

ESP[player] = nil
DisplayedHealth[player] = nil
DownState[player] = nil
SquadCache[player] = nil

end

-- Caja ligera con proyección de cabeza y raíz.
local function GetBounds(character)
local head = character:FindFirstChild("Head")
local root = character:FindFirstChild("HumanoidRootPart")
local humanoid = character:FindFirstChildOfClass("Humanoid")

if not head or not root or not humanoid then
    return nil
end

local rootPos, rootVisible =
    Camera:WorldToViewportPoint(root.Position)

if not rootVisible or rootPos.Z <= 0 then
    return nil
end

local headPos = Camera:WorldToViewportPoint(
    head.Position + Vector3.new(0, 0.3, 0)
)

local feetPos = Camera:WorldToViewportPoint(
    root.Position - Vector3.new(
        0,
        humanoid.HipHeight + root.Size.Y / 2 + 1,
        0
    )
)

if headPos.Z <= 0 or feetPos.Z <= 0 then
    return nil
end

local height = math.abs(feetPos.Y - headPos.Y)
if height < 2 then return nil end

local width = height * 0.48

return rootPos.X - width / 2,
    math.min(headPos.Y, feetPos.Y),
    rootPos.X + width / 2,
    math.max(headPos.Y, feetPos.Y)

end

local function SetLine(line, x1, y1, x2, y2, color, thickness)
line.From = Vector2.new(x1, y1)
line.To = Vector2.new(x2, y2)
line.Color = color
line.Thickness = thickness
line.Visible = true
end

local function DrawCorners(e, x, y, w, h, color)
local length = math.clamp(math.min(w, h) * 0.22, 3, 10)

SetLine(e.Corner1, x, y + length, x, y, color, 2)
SetLine(e.Corner2, x, y, x + length, y, color, 2)
SetLine(e.Corner3, x + w - length, y, x + w, y, color, 2)
SetLine(e.Corner4, x + w, y, x + w, y + length, color, 2)

SetLine(e.TopAccent, x + w * 0.35, y,
    x + w * 0.65, y, WHITE, 2)

SetLine(e.BottomAccent, x + w * 0.35, y + h,
    x + w * 0.65, y + h, color, 2)

end

local function DrawHealth(e, player, humanoid, minX, minY, maxY, dt)
local barWidth = 4
local barX = minX - 9
local height = math.max(maxY - minY, 1)

local ratio = math.clamp(
    humanoid.Health / math.max(humanoid.MaxHealth, 1),
    0, 1
)

local current = DisplayedHealth[player]

if current == nil then
    current = ratio
end

current = current + (ratio - current) * math.min(dt * 14, 1)
DisplayedHealth[player] = current

local fillHeight = height * current

e.HealthBG.Position = Vector2.new(barX, minY)
e.HealthBG.Size = Vector2.new(barWidth, height)
e.HealthBG.Visible = true

e.Health.Position = Vector2.new(barX, maxY - fillHeight)
e.Health.Size = Vector2.new(barWidth, math.max(fillHeight, 0))

e.Health.Color = ratio > 0.6 and GREEN
    or ratio > 0.3 and YELLOW
    or RED

e.Health.Visible = ratio > 0

end

local function DrawSkeleton(e, character, color)
for i, bone in ipairs(e.SkeletonBones) do
local partA = character:FindFirstChild(bone[1]) or character:FindFirstChild(bone[3])
local partB = character:FindFirstChild(bone[2])

local line = e.Skeleton[i]

    if partA and partB and partA ~= partB then
        local posA, visibleA =
            Camera:WorldToViewportPoint(partA.Position)
        local posB, visibleB =
            Camera:WorldToViewportPoint(partB.Position)

        if visibleA and visibleB and posA.Z > 0 and posB.Z > 0 then
            SetLine(line, posA.X, posA.Y, posB.X, posB.Y, color, 1.5)
        else
            line.Visible = false
        end
    else
        line.Visible = false
    end
end

end

for _, player in ipairs(Players:GetPlayers()) do
CreateESP(player)
end

Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(RemoveESP)

RefreshSquads()

RunService.RenderStepped:Connect(function(dt)
Camera = workspace.CurrentCamera or Camera

SquadCacheClock += dt
ScanClock += dt
BoxClock += dt
SkeletonClock += dt
HealthClock += dt

if SquadCacheClock >= SQUAD_INTERVAL then
    SquadCacheClock = 0
    RefreshSquads()
end

if ScanClock >= SCAN_INTERVAL then
    ScanClock = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            ScanDown(player)
        end
    end
end

local updateBox = BoxClock >= BOX_INTERVAL
local updateSkeleton = SkeletonClock >= SKELETON_INTERVAL

if updateBox then BoxClock = 0 end
if updateSkeleton then SkeletonClock = 0 end

for player, e in pairs(ESP) do
    if IsTeammate(player) then
        HideESP(e)
        DownState[player] = false
        continue
    end

    local character = player.Character
    local humanoid = character
        and character:FindFirstChildOfClass("Humanoid")
    local root = character
        and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root or humanoid.Health <= 0 then
        HideESP(e)
        continue
    end

    if updateBox then
        local minX, minY, maxX, maxY = GetBounds(character)

        if not minX then
            HideESP(e)
            continue
        end

        local width = maxX - minX
        local height = maxY - minY

        if width < 2 or height < 2 then
            HideESP(e)
            continue
        end

        local color = DownState[player] and RED or NORMAL
        local centerX = (minX + maxX) / 2

        -- BOX
        if IsESPEnabled("ESP_Box") then
            e.Box.Position = Vector2.new(minX, minY)
            e.Box.Size = Vector2.new(width, height)
            e.Box.Color = color
            e.Box.Visible = true

            DrawCorners(e, minX, minY, width, height, color)
        else
            e.Box.Visible = false
            e.TopAccent.Visible = false
            e.BottomAccent.Visible = false
            e.Corner1.Visible = false
            e.Corner2.Visible = false
            e.Corner3.Visible = false
            e.Corner4.Visible = false
        end

        -- LINE
        if IsESPEnabled("ESP_Line") then
            SetLine(
                e.Line,
                Camera.ViewportSize.X / 2, 0,
                centerX, minY - 8,
                color, 1.3
            )
        else
            e.Line.Visible = false
        end

        e.LastBounds = {minX, minY, maxX, maxY}

        -- HEALTH
        if IsESPEnabled("ESP_Health") then
            DrawHealth(e, player, humanoid, minX, minY, maxY, dt)
        else
            e.Health.Visible = false
            e.HealthBG.Visible = false
        end
    end

    local bounds = e.LastBounds

    if not bounds then
        continue
    end

    local color = DownState[player] and RED or NORMAL

    if IsESPEnabled("ESP_Skeleton") then
        if updateSkeleton then
            DrawSkeleton(e, character, color)
        end
    else
        for _, bone in ipairs(e.Skeleton) do
            bone.Visible = false
        end
    end


end

end)

        end
      end
    end
    do
      local BoxEspButton_2 = Instance.new("TextButton")
      BoxEspButton_2.Name = "BoxEspButton"
      BoxEspButton_2.Position = UDim2.new(0, 4, 0, 40)
      BoxEspButton_2.Size = UDim2.new(0, 304, 0, 26)
      BoxEspButton_2.BackgroundColor3 = Color3.fromRGB(52, 0, 0)
      BoxEspButton_2.BorderSizePixel = 0
      BoxEspButton_2.Text = "BoxEsp"
      BoxEspButton_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      BoxEspButton_2.TextSize = 16
      BoxEspButton_2.Font = Enum.Font.GothamBlack
      BoxEspButton_2.Parent = center_2_1
      do
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Name = "UICorner"
        UICorner_3.Parent = BoxEspButton_2
      end
      do
        local script = {Parent = BoxEspButton_2, Name = "fun"}
        __runs[#__runs + 1] = function()
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local button = script.Parent
local attribute = "ESP_Box"

local function Update()
    local enabled = PlayerGui:GetAttribute(attribute) == true
    button.Text = enabled and "BOX: ON" or "BOX: OFF"
end

button.MouseButton1Click:Connect(function()
    local current = PlayerGui:GetAttribute(attribute) == true
    PlayerGui:SetAttribute(attribute, not current)
    Update()
end)

PlayerGui:GetAttributeChangedSignal(attribute):Connect(Update)

Update()
        end
      end
    end
    do
      local lineEspButton_2 = Instance.new("TextButton")
      lineEspButton_2.Name = "lineEspButton"
      lineEspButton_2.Position = UDim2.new(0, 4, 0, 71)
      lineEspButton_2.Size = UDim2.new(0, 304, 0, 26)
      lineEspButton_2.BackgroundColor3 = Color3.fromRGB(52, 0, 0)
      lineEspButton_2.BorderSizePixel = 0
      lineEspButton_2.Text = "lineEsp"
      lineEspButton_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      lineEspButton_2.TextSize = 16
      lineEspButton_2.Font = Enum.Font.GothamBlack
      lineEspButton_2.Parent = center_2_1
      do
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Name = "UICorner"
        UICorner_3.Parent = lineEspButton_2
      end
      do
        local script = {Parent = lineEspButton_2, Name = "fun"}
        __runs[#__runs + 1] = function()
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local button = script.Parent
local attribute = "ESP_Line"

local function Update()
    local enabled = PlayerGui:GetAttribute(attribute) == true
    button.Text = enabled and "LINE: ON" or "LINE: OFF"
end

button.MouseButton1Click:Connect(function()
    local current = PlayerGui:GetAttribute(attribute) == true
    PlayerGui:SetAttribute(attribute, not current)
    Update()
end)

PlayerGui:GetAttributeChangedSignal(attribute):Connect(Update)

Update()
        end
      end
    end
    do
      local skeletonEspButton_2 = Instance.new("TextButton")
      skeletonEspButton_2.Name = "skeletonEspButton"
      skeletonEspButton_2.Position = UDim2.new(0, 4, 0, 103)
      skeletonEspButton_2.Size = UDim2.new(0, 304, 0, 26)
      skeletonEspButton_2.BackgroundColor3 = Color3.fromRGB(52, 0, 0)
      skeletonEspButton_2.BorderSizePixel = 0
      skeletonEspButton_2.Text = "skeletonEsp"
      skeletonEspButton_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      skeletonEspButton_2.TextSize = 16
      skeletonEspButton_2.Font = Enum.Font.GothamBlack
      skeletonEspButton_2.Parent = center_2_1
      do
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Name = "UICorner"
        UICorner_3.Parent = skeletonEspButton_2
      end
      do
        local script = {Parent = skeletonEspButton_2, Name = "fun"}
        __runs[#__runs + 1] = function()
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local button = script.Parent
local attribute = "ESP_Skeleton"

local function Update()
    local enabled = PlayerGui:GetAttribute(attribute) == true
    button.Text = enabled and "SKELETON: ON" or "SKELETON: OFF"
end

button.MouseButton1Click:Connect(function()
    local current = PlayerGui:GetAttribute(attribute) == true
    PlayerGui:SetAttribute(attribute, not current)
    Update()
end)

PlayerGui:GetAttributeChangedSignal(attribute):Connect(Update)

Update()
        end
      end
    end
    do
      local HealthEspButton_2 = Instance.new("TextButton")
      HealthEspButton_2.Name = "HealthEspButton"
      HealthEspButton_2.Position = UDim2.new(0, 4, 0, 135)
      HealthEspButton_2.Size = UDim2.new(0, 304, 0, 26)
      HealthEspButton_2.BackgroundColor3 = Color3.fromRGB(52, 0, 0)
      HealthEspButton_2.BorderSizePixel = 0
      HealthEspButton_2.Text = "healthEsp"
      HealthEspButton_2.TextColor3 = Color3.fromRGB(255, 255, 255)
      HealthEspButton_2.TextSize = 16
      HealthEspButton_2.Font = Enum.Font.GothamBlack
      HealthEspButton_2.Parent = center_2_1
      do
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Name = "UICorner"
        UICorner_3.Parent = HealthEspButton_2
      end
      do
        local script = {Parent = HealthEspButton_2, Name = "fun"}
        __runs[#__runs + 1] = function()
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local button = script.Parent
local attribute = "ESP_Health"

local function Update()
    local enabled = PlayerGui:GetAttribute(attribute) == true
    button.Text = enabled and "HEALTH: ON" or "HEALTH: OFF"
end

button.MouseButton1Click:Connect(function()
    local current = PlayerGui:GetAttribute(attribute) == true
    PlayerGui:SetAttribute(attribute, not current)
    Update()
end)

PlayerGui:GetAttributeChangedSignal(attribute):Connect(Update)

Update()
        end
      end
    end
  end
  do
    local script = {Parent = _1_0, Name = "menusfun"}
    __runs[#__runs + 1] = function()
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Gui = script.Parent

for i = 1, 3 do
    local Center = Gui:FindFirstChild("center#" .. i, true)
    local Button = Gui:FindFirstChild("button#" .. i, true)

    if Center then
        Center.Visible = (i == 1)
    end

    if Button and Center then
        Button.MouseButton1Click:Connect(function()

            for j = 1, 3 do
                local OtherCenter = Gui:FindFirstChild("center#" .. j, true)

                if OtherCenter then
                    OtherCenter.Visible = (j == i)
                end
            end

        end)
    end
end
    end
  end
end
do
  local _2_0 = Instance.new("ImageButton")
  _2_0.Name = "#2"
  _2_0.Position = UDim2.new(0, 28, 0, 48)
  _2_0.Size = UDim2.new(0, 60, 0, 60)
  _2_0.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
  _2_0.BackgroundTransparency = 1
  _2_0.BorderSizePixel = 0
  _2_0.Image = "rbxassetid://100166523594655"
  _2_0.Parent = gui
  do
    local script = {Parent = _2_0, Name = "drag#2"}
    __runs[#__runs + 1] = function()

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Frame = script.Parent

local dragging = false
local dragInput
local dragStart
local startPosition

Frame.Active = true

local function ClampPosition(position)
    local camera = workspace.CurrentCamera
    if not camera then return position end

    local viewport = camera.ViewportSize
    local size = Frame.AbsoluteSize

    local x = math.clamp(
        position.X.Offset, 0,
        math.max(0, viewport.X - size.X)
    )

    local y = math.clamp(
        position.Y.Offset, 0,
        math.max(0, viewport.Y - size.Y)
    )

    return UDim2.new(
        position.X.Scale, x,
        position.Y.Scale, y
    )
end

local function IsInsideFrame(input)
    local p = input.Position
    local pos = Frame.AbsolutePosition
    local size = Frame.AbsoluteSize

    return p.X >= pos.X
        and p.X <= pos.X + size.X
        and p.Y >= pos.Y
        and p.Y <= pos.Y + size.Y
end

Frame.InputBegan:Connect(function(input)
    if dragging then return end

    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    if not IsInsideFrame(input) then return end

    dragging = true
    dragInput = input
    dragStart = input.Position
    startPosition = Frame.Position
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end

    local validInput =
        input == dragInput
        or (
            dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        )

    if not validInput then return end

    local delta = input.Position - dragStart

    local newPosition = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )

    Frame.Position = ClampPosition(newPosition)
end)

UserInputService.InputEnded:Connect(function(input)
    if not dragging then return end

    if input == dragInput or (
        dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1
    ) then
        dragging = false
        dragInput = nil
        dragStart = nil
        startPosition = nil
    end
end)

RunService.RenderStepped:Connect(function()
    if not dragging then
        local clamped = ClampPosition(Frame.Position)

        if clamped ~= Frame.Position then
            Frame.Position = clamped
        end
    end
end)

    end
  end
  do
    local script = {Parent = _2_0, Name = "abrir cr"}
    __runs[#__runs + 1] = function()
local button = script.Parent
local frame = button.Parent:WaitForChild("#1")

frame.Visible = true

button.Activated:Connect(function()
    frame.Visible = not frame.Visible
end)
    end
  end
  do
    local UICorner_1 = Instance.new("UICorner")
    UICorner_1.Name = "UICorner"
    UICorner_1.CornerRadius = UDim.new(1, 3)
    UICorner_1.Parent = _2_0
  end
end

gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

-- ModuleScripts: usa require("Nombre") o Modules.Nombre
for _, m in ipairs(__mods) do Modules[m[1]] = m[2]() end
for _, f in ipairs(__runs) do task.spawn(f) end
