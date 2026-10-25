-- ZYREN • ANIMATION TARGET + PREDICTION + FORCE LOOK + RADAR

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

--==================================================
-- CONFIGURACIÓN
--==================================================

local ANIMATION_ID = "10471336737"

local DISTANCIA_OBJETIVO = 4
local DURACION = 0.54
local RADIO = 25

-- Predicción por ping
local PING_PREDICTION = 0.20
local MAX_PREDICTION = 0.20

-- Fuerza del giro
local ROTATION_ALPHA = 0.98

-- Radar
local RADAR = true
local RADAR_TRANSPARENCY = 0.88
local RADAR_COLOR = Color3.fromRGB(0, 255, 215)
local RADAR_HEIGHT = -2.8

--==================================================
-- VARIABLES
--==================================================

local Character
local Humanoid
local Root
local Animator

local AnimationConnection

local active = false
local activeTargetRoot = nil
local oldAutoRotate = true

--==================================================
-- RADAR
--==================================================

pcall(function()
	RunService:UnbindFromRenderStep("ZyrenRadar")
end)

pcall(function()
	local oldRadar = workspace:FindFirstChild("ZyrenRadar")
	if oldRadar then
		oldRadar:Destroy()
	end
end)

local RadarPart

if RADAR then
	RadarPart = Instance.new("Part")
	RadarPart.Name = "ZyrenRadar"
	RadarPart.Shape = Enum.PartType.Cylinder
	RadarPart.Size = Vector3.new(0.15, RADIO * 2, RADIO * 2)
	RadarPart.Material = Enum.Material.ForceField
	RadarPart.Color = RADAR_COLOR
	RadarPart.Transparency = RADAR_TRANSPARENCY
	RadarPart.Anchored = true
	RadarPart.CanCollide = false
	RadarPart.CanTouch = false
	RadarPart.CanQuery = false
	RadarPart.CastShadow = false
	RadarPart.Parent = workspace
end

RunService:BindToRenderStep(
	"ZyrenRadar",
	Enum.RenderPriority.Last.Value - 50,
	function()
		if not RADAR or not RadarPart then
			return
		end

		if Character and Root and Root.Parent then
			local pulse = math.sin(os.clock() * 3) * 0.08

			RadarPart.Transparency = math.clamp(
				RADAR_TRANSPARENCY - pulse,
				0,
				0.98
			)

			RadarPart.Size = Vector3.new(
				0.15,
				(RADIO * 2) + pulse,
				(RADIO * 2) + pulse
			)

			RadarPart.CFrame =
				CFrame.new(
					Root.Position.X,
					Root.Position.Y + RADAR_HEIGHT,
					Root.Position.Z
				)
				* CFrame.Angles(0, 0, math.rad(90))
		end
	end
)

--==================================================
-- LIMPIAR ACCIONES
--==================================================

local function stopAll()
	active = false
	activeTargetRoot = nil

	pcall(function()
		RunService:UnbindFromRenderStep("ZyrenMove")
	end)

	pcall(function()
		RunService:UnbindFromRenderStep("ZyrenForceLook")
	end)

	if Humanoid and Humanoid.Parent then
		Humanoid.AutoRotate = oldAutoRotate
	end
end

--==================================================
-- CHARACTER
--==================================================

local function setupCharacter(char)
	stopAll()

	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	Root = char:WaitForChild("HumanoidRootPart")

	Animator = Humanoid:FindFirstChildOfClass("Animator")

	if not Animator then
		Animator = Humanoid:WaitForChild("Animator", 3)
	end

	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end
end

--==================================================
-- BUSCAR OBJETIVO
--==================================================

local function getNearestTarget()
	if not Root or not Root.Parent then
		return nil
	end

	local nearestRoot = nil
	local nearestDistance = RADIO

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= Character then

			local targetHumanoid = obj:FindFirstChildOfClass("Humanoid")
			local targetRoot = obj:FindFirstChild("HumanoidRootPart")

			if targetHumanoid
				and targetRoot
				and targetHumanoid.Health > 0
				and targetRoot:IsA("BasePart")
			then
				local distance = (targetRoot.Position - Root.Position).Magnitude

				if distance <= nearestDistance then
					nearestDistance = distance
					nearestRoot = targetRoot
				end
			end
		end
	end

	return nearestRoot
end

--==================================================
-- PREDICCIÓN
--==================================================

local function getPredictedPosition(targetRoot)
	if not targetRoot or not targetRoot.Parent then
		return nil
	end

	local ping = 0

	pcall(function()
		ping = LocalPlayer:GetNetworkPing()
	end)

	local predictionTime = math.min(
		ping * PING_PREDICTION,
		MAX_PREDICTION
	)

	local velocity = targetRoot.AssemblyLinearVelocity

	local horizontalVelocity = Vector3.new(
		velocity.X,
		0,
		velocity.Z
	)

	return targetRoot.Position
		+ horizontalVelocity * predictionTime
end

--==================================================
-- MOVER AL OBJETIVO
--==================================================

local function moveToTarget(targetRoot)
	if active then
		return
	end

	if not Root or not Root.Parent then
		return
	end

	if not Humanoid or Humanoid.Health <= 0 then
		return
	end

	if not targetRoot or not targetRoot.Parent then
		return
	end

	active = true
	activeTargetRoot = targetRoot

	oldAutoRotate = Humanoid.AutoRotate
	Humanoid.AutoRotate = false

	local startTime = os.clock()
	local startPosition = Root.Position

	--==================================================
	-- MOVIMIENTO
	--==================================================

	RunService:BindToRenderStep(
		"ZyrenMove",
		Enum.RenderPriority.Last.Value - 10,
		function()
			if not active then
				return
			end

			if not Character
				or not Character.Parent
				or not Humanoid
				or Humanoid.Health <= 0
				or not Root
				or not Root.Parent
				or not activeTargetRoot
				or not activeTargetRoot.Parent
			then
				stopAll()
				return
			end

			local elapsed = os.clock() - startTime
			local progress = math.clamp(elapsed / DURACION, 0, 1)

			local easedProgress = TweenService:GetValue(
				progress,
				Enum.EasingStyle.Exponential,
				Enum.EasingDirection.Out
			)

			local predictedPosition = getPredictedPosition(activeTargetRoot)

			if not predictedPosition then
				stopAll()
				return
			end

			local flatDirection = Vector3.new(
				predictedPosition.X - Root.Position.X,
				0,
				predictedPosition.Z - Root.Position.Z
			)

			if flatDirection.Magnitude > 0.001 then
				flatDirection = flatDirection.Unit
			else
				flatDirection = Vector3.new(0, 0, -1)
			end

			local targetPosition =
				predictedPosition
				- flatDirection * DISTANCIA_OBJETIVO

			-- Nunca modifica la altura
			targetPosition = Vector3.new(
				targetPosition.X,
				Root.Position.Y,
				targetPosition.Z
			)

			local horizontalPosition = Vector3.new(
				startPosition.X
					+ (targetPosition.X - startPosition.X) * easedProgress,

				Root.Position.Y,

				startPosition.Z
					+ (targetPosition.Z - startPosition.Z) * easedProgress
			)

			-- Conserva la rotación actual.
			-- El force look se aplica DESPUÉS.
			local rx, ry, rz = Root.CFrame:ToOrientation()

			Root.CFrame =
				CFrame.new(horizontalPosition)
				* CFrame.fromOrientation(rx, ry, rz)

			if progress >= 1 then
				stopAll()
			end
		end
	)

	--==================================================
	-- FORCE LOOK
	--==================================================

	RunService:BindToRenderStep(
		"ZyrenForceLook",
		Enum.RenderPriority.Last.Value,
		function()
			if not active then
				return
			end

			if not Character
				or not Character.Parent
				or not Humanoid
				or Humanoid.Health <= 0
				or not Root
				or not Root.Parent
				or not activeTargetRoot
				or not activeTargetRoot.Parent
			then
				stopAll()
				return
			end

			-- Lo mantenemos desactivado EN CADA FRAME
			-- para que nada vuelva a activar AutoRotate.
			Humanoid.AutoRotate = false

			local predictedPosition = getPredictedPosition(activeTargetRoot)

			if not predictedPosition then
				return
			end

			-- SOLO X/Z.
			-- Nunca hace que el personaje mire hacia arriba/abajo.
			local lookDirection = Vector3.new(
				predictedPosition.X - Root.Position.X,
				0,
				predictedPosition.Z - Root.Position.Z
			)

			if lookDirection.Magnitude <= 0.001 then
				return
			end

			lookDirection = lookDirection.Unit

			local currentPosition = Root.Position

			-- Método de FORCE LOOK
			local wanted = CFrame.lookAt(
				currentPosition,
				currentPosition + lookDirection,
				Vector3.yAxis
			)

			-- Último paso de render:
			-- se aplica después del movimiento y de Shift Lock.
			Root.CFrame = Root.CFrame:Lerp(
				wanted,
				ROTATION_ALPHA
			)

			-- Mata cualquier giro físico acumulado.
			Root.AssemblyAngularVelocity = Vector3.zero
		end
	)
end

--==================================================
-- CONECTAR ANIMATOR
--==================================================

local function connectAnimator(animator)
	if not animator then
		return
	end

	-- Elimina la conexión anterior para no duplicarla
	if AnimationConnection then
		AnimationConnection:Disconnect()
		AnimationConnection = nil
	end

	AnimationConnection = animator.AnimationPlayed:Connect(function(track)
		if not track or not track.Animation then
			return
		end

		local animationId = tostring(track.Animation.AnimationId)

		animationId = animationId:gsub("rbxassetid://", "")

		if animationId == ANIMATION_ID then
			if active then
				return
			end

			local targetRoot = getNearestTarget()

			if targetRoot then
				moveToTarget(targetRoot)
			end
		end
	end)
end

--==================================================
-- INICIALIZAR
--==================================================

setupCharacter(
	LocalPlayer.Character
	or LocalPlayer.CharacterAdded:Wait()
)

connectAnimator(Animator)

--==================================================
-- RESPAWN
--==================================================

LocalPlayer.CharacterAdded:Connect(function(char)
	stopAll()

	-- Espera a que el nuevo personaje esté completo
	setupCharacter(char)

	-- Conecta el nuevo Animator
	if Animator then
		connectAnimator(Animator)
	end

	-- Por si el Animator aparece unos instantes después
	Humanoid.ChildAdded:Connect(function(child)
		if child:IsA("Animator") then
			Animator = child
			connectAnimator(child)
		end
	end)
end)
