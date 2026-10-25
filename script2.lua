-- ZYREN GUI BUILDER • EXPORTACIÓN RESPONSIVA
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")

-- MiGUI
local gui_1=Instance.new("ScreenGui")
gui_1.Name="MiGUI"
gui_1.ResetOnSpawn=false
gui_1.IgnoreGuiInset=true
gui_1.DisplayOrder=999999
gui_1.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui_1.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local design_1=Instance.new("Frame")
design_1.Name="__ZyrenResponsiveRoot"
design_1.AnchorPoint=Vector2.new(.5,.5)
design_1.Position=UDim2.fromScale(.5,.5)
design_1.Size=UDim2.fromOffset(844,390)
design_1.BackgroundTransparency=1
design_1.Parent=gui_1
local scale_1=Instance.new("UIScale",design_1)
local cam=workspace.CurrentCamera
local function updateScale_1()
 if not cam then return end
 scale_1.Scale=math.min(cam.ViewportSize.X/844,cam.ViewportSize.Y/390)
end
updateScale_1()
if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale_1) end
local obj_10001=Instance.new("TextButton")
obj_10001.Name="Botón"
obj_10001.Size = UDim2.new(0,96,0,28)
obj_10001.Position = UDim2.new(0,525,0,23)
obj_10001.AnchorPoint = Vector2.new(0,0)
obj_10001.Visible = true
obj_10001.ZIndex = 2
obj_10001.BorderSizePixel = 0
obj_10001.BackgroundColor3 = Color3.fromRGB(35,35,35)
obj_10001.BackgroundTransparency = 0
obj_10001.Text = "supa tech"
obj_10001.TextColor3 = Color3.fromRGB(255,255,255)
obj_10001.TextSize = 18
obj_10001.Font = Enum.Font.Gotham
obj_10001.AutoButtonColor = true
obj_10001.Parent=design_1
local wrap_10001_1=Instance.new("UICorner")
wrap_10001_1.CornerRadius=UDim.new(0,10)
wrap_10001_1.Parent=obj_10001
local wrap_10001_2=Instance.new("UIStroke")
wrap_10001_2.Color=Color3.fromRGB(23,215,185)
wrap_10001_2.Thickness=2
wrap_10001_2.Transparency=0
wrap_10001_2.Parent=obj_10001
-- LocalScript: LocalScript de Botón
task.spawn(function()
 local UserInputService = game:GetService("UserInputService")
 local objeto = obj_10001
 local dragging = false
 local dragStart = nil
 local startPos = nil
 local activeInput = nil
 local function limitarPantalla(pos)
 	local pantalla = workspace.CurrentCamera.ViewportSize
 	local ancho = objeto.AbsoluteSize.X
 	local alto = objeto.AbsoluteSize.Y
 	local x = math.clamp(
 		pos.X.Offset,
 		0,
 		pantalla.X - ancho
 	)
 	local y = math.clamp(
 		pos.Y.Offset,
 		0,
 		pantalla.Y - alto
 	)
 	return UDim2.new(
 		pos.X.Scale,
 		x,
 		pos.Y.Scale,
 		y
 	)
 end
 objeto.InputBegan:Connect(function(input)
 	if input.UserInputType == Enum.UserInputType.MouseButton1
 		or input.UserInputType == Enum.UserInputType.Touch then
 		-- El toque debe comenzar directamente sobre el objeto
 		dragging = true
 		activeInput = input
 		dragStart = input.Position
 		startPos = objeto.Position
 	end
 end)
 UserInputService.InputChanged:Connect(function(input)
 	if not dragging then
 		return
 	end
 	-- PC
 	if activeInput.UserInputType == Enum.UserInputType.MouseButton1 then
 		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
 			return
 		end
 	end
 	-- Móvil: solamente el dedo que inició el drag
 	if activeInput.UserInputType == Enum.UserInputType.Touch then
 		if input ~= activeInput then
 			return
 		end
 	end
 	local delta = input.Position - dragStart
 	local nuevaPos = UDim2.new(
 		startPos.X.Scale,
 		startPos.X.Offset + delta.X,
 		startPos.Y.Scale,
 		startPos.Y.Offset + delta.Y
 	)
 	objeto.Position = limitarPantalla(nuevaPos)
 end)
 UserInputService.InputEnded:Connect(function(input)
 	if input == activeInput then
 		dragging = false
 		activeInput = nil
 	end
 end)
end)
-- LocalScript: supa tech scripr
task.spawn(function()
 -- LocalScript - DENTRO DE TU BOTÓN
 local Players = game:GetService("Players")
 local RunService = game:GetService("RunService")
 local player = Players.LocalPlayer
 --==================================================
 -- CONFIGURACIÓN
 --==================================================
 local ANIMATION_IDS = {
 	["10503381238"] = true,
 	["13379003796"] = true
 }
 local UPPERCUT_TRIGGER_TIME = 0.25
 -- HITBOX
 local HITBOX_SIZE = Vector3.new(5, 6, 5)
 local HITBOX_DISTANCE = 4
 local HITBOX_TIME = 0.5
 -- HIGHLIGHT
 local HIGHLIGHT_TIME = 0.8
 -- DELAY ANTES DEL REMOTE
 local REMOTE_DELAY = 0.0983
 -- COOLDOWN DEL REMOTE
 local REMOTE_COOLDOWN = 5
 -- COOLDOWN DE TODA LA ACCIÓN AL DETECTAR ENEMIGO
 local HITBOX_ACTION_COOLDOWN = 5
 -- DISTANCIA AL ENEMIGO
 local CLOSE_DISTANCE = 0.9
 -- ALTURA
 local LOOK_Y_OFFSET = -0.2
 -- TIEMPO DEL MOVIMIENTO
 local LOOK_TIME = 0.7
 -- INCLINACIÓN HACIA ARRIBA EN GRADOS
 local LOOK_AIM_UP = 18
 -- VELOCIDAD DE ROTACIÓN
 local ROTATION_SPEED = 14
 -- SUAVIZADO DE Y
 local Y_EASING_POWER = 2
 --==================================================
 -- VARIABLES
 --==================================================
 local character
 local humanoid
 local root
 local animator
 local activeUppercut = false
 local remoteOnCooldown = false
 local hitboxActionOnCooldown = false
 local systemEnabled = true
 local toggleButton = obj_10001
 --==================================================
 -- BOTÓN ON / OFF
 --==================================================
 local function updateToggleButton()
 	if systemEnabled then
 		toggleButton.Text = "ON"
 		toggleButton.BackgroundColor3 =
 			Color3.fromRGB(0, 170, 0)
 	else
 		toggleButton.Text = "OFF"
 		toggleButton.BackgroundColor3 =
 			Color3.fromRGB(170, 0, 0)
 	end
 end
 toggleButton.Activated:Connect(function()
 	systemEnabled = not systemEnabled
 	updateToggleButton()
 	print(
 		"Uppercut Hitbox:",
 		systemEnabled and "ON" or "OFF"
 	)
 end)
 updateToggleButton()
 --==================================================
 -- COUNTDOWN REMOTE
 --==================================================
 local function startRemoteCountdown()
 	task.spawn(function()
 		for i = REMOTE_COOLDOWN, 1, -1 do
 			print("Remote cooldown: " .. i)
 			task.wait(1)
 		end
 		print("Remote cooldown terminado")
 	end)
 end
 --==================================================
 -- COOLDOWN DE TODA LA ACCIÓN
 --==================================================
 local function startHitboxActionCooldown()
 	hitboxActionOnCooldown = true
 	task.spawn(function()
 		for i = HITBOX_ACTION_COOLDOWN, 1, -1 do
 			print(
 				"Hitbox acción cooldown: " .. i
 			)
 			task.wait(1)
 		end
 		hitboxActionOnCooldown = false
 		print(
 			"Cooldown de acción del hitbox terminado"
 		)
 	end)
 end
 --==================================================
 -- HIGHLIGHT
 --==================================================
 local function createHighlight(targetCharacter)
 	if not targetCharacter then
 		return
 	end
 	local oldHighlight =
 		targetCharacter:FindFirstChild(
 			"UppercutHighlight"
 		)
 	if oldHighlight then
 		oldHighlight:Destroy()
 	end
 	local highlight =
 		Instance.new("Highlight")
 	highlight.Name =
 		"UppercutHighlight"
 	highlight.Adornee =
 		targetCharacter
 	highlight.FillColor =
 		Color3.fromRGB(255, 0, 0)
 	highlight.FillTransparency =
 		0.25
 	highlight.OutlineColor =
 		Color3.fromRGB(255, 255, 255)
 	highlight.OutlineTransparency =
 		0
 	highlight.DepthMode =
 		Enum.HighlightDepthMode.AlwaysOnTop
 	highlight.Parent =
 		targetCharacter
 	task.delay(
 		HIGHLIGHT_TIME,
 		function()
 			if highlight
 				and highlight.Parent
 			then
 				highlight:Destroy()
 			end
 		end
 	)
 end
 --==================================================
 -- BUSCAR ENEMIGO EN HITBOX
 --==================================================
 local function getTarget()
 	if not character
 		or not root
 	then
 		return nil, nil
 	end
 	local hitboxCFrame =
 		root.CFrame
 		* CFrame.new(
 			0,
 			0,
 			-HITBOX_DISTANCE
 		)
 	local overlapParams =
 		OverlapParams.new()
 	overlapParams.FilterType =
 		Enum.RaycastFilterType.Exclude
 	overlapParams.FilterDescendantsInstances =
 		{character}
 	overlapParams.MaxParts =
 		100
 	local parts =
 		workspace:GetPartBoundsInBox(
 			hitboxCFrame,
 			HITBOX_SIZE,
 			overlapParams
 		)
 	local closestCharacter =
 		nil
 	local closestRoot =
 		nil
 	local closestDistance =
 		math.huge
 	local checked = {}
 	for _, part in ipairs(parts) do
 		local model =
 			part:FindFirstAncestorOfClass(
 				"Model"
 			)
 		if model
 			and model ~= character
 			and not checked[model]
 		then
 			checked[model] = true
 			local targetHumanoid =
 				model:FindFirstChildOfClass(
 					"Humanoid"
 				)
 			local targetRoot =
 				model:FindFirstChild(
 					"HumanoidRootPart"
 				)
 			if targetHumanoid
 				and targetRoot
 				and targetHumanoid.Health > 0
 			then
 				local distance =
 					(
 						root.Position
 						- targetRoot.Position
 					).Magnitude
 				if distance <
 					closestDistance
 				then
 					closestDistance =
 						distance
 					closestCharacter =
 						model
 					closestRoot =
 						targetRoot
 				end
 			end
 		end
 	end
 	return closestCharacter,
 		closestRoot
 end
 --==================================================
 -- REMOTE
 --==================================================
 local function fireRemote()
 	if not systemEnabled then
 		return false
 	end
 	if not character then
 		return false
 	end
 	local Event =
 		character:FindFirstChild(
 			"Communicate"
 		)
 	if not Event then
 		return false
 	end
 	if not Event:IsA("RemoteEvent") then
 		return false
 	end
 	if remoteOnCooldown then
 		print(
 			"Remote en cooldown"
 		)
 		return false
 	end
 	remoteOnCooldown = true
 	Event:FireServer(
 		{
 			Dash = Enum.KeyCode.W,
 			Key = Enum.KeyCode.Q,
 			Goal = "KeyPress",
 			MousePos = CFrame.new(
 				346.26571655273438,
 				546.341552734375,
 				352.39794921875,
 				-0.85390132665634155,
 				-0.11197102814912796,
 				-0.50824719667434692,
 				-0,
 				0.97658145427703857,
 				-0.21514885127544403,
 				0.5204351544380188,
 				-0.18371589481830597,
 				-0.833903968334198
 			)
 		}
 	)
 	print("Remote activado")
 	startRemoteCountdown()
 	task.delay(
 		REMOTE_COOLDOWN,
 		function()
 			remoteOnCooldown =
 				false
 		end
 	)
 	return true
 end
 --==================================================
 -- MOVIMIENTO
 --==================================================
 local function moveUnderTarget(targetRoot)
 	if not root
 		or not root.Parent
 		or not humanoid
 		or humanoid.Health <= 0
 		or not targetRoot
 		or not targetRoot.Parent
 	then
 		return
 	end
 	local startPosition =
 		root.Position
 	local startY =
 		startPosition.Y
 	local targetStartPosition =
 		targetRoot.Position
 	-- DIRECCIÓN ORIGINAL HORIZONTAL
 	local originalLook =
 		root.CFrame.LookVector
 	local originalFlatLook =
 		Vector3.new(
 			originalLook.X,
 			0,
 			originalLook.Z
 		)
 	if originalFlatLook.Magnitude < 0.001 then
 		originalFlatLook =
 			Vector3.new(
 				0,
 				0,
 				-1
 			)
 	else
 		originalFlatLook =
 			originalFlatLook.Unit
 	end
 	-- DISTANCIA HORIZONTAL AL ENEMIGO
 	local horizontalDirection =
 		Vector3.new(
 			startPosition.X
 				- targetStartPosition.X,
 			0,
 			startPosition.Z
 				- targetStartPosition.Z
 		)
 	if horizontalDirection.Magnitude <
 		0.001
 	then
 		horizontalDirection =
 			Vector3.new(
 				0,
 				0,
 				1
 			)
 	else
 		horizontalDirection =
 			horizontalDirection.Unit
 	end
 	local fixedX =
 		targetStartPosition.X
 		+ horizontalDirection.X
 		* CLOSE_DISTANCE
 	local fixedZ =
 		targetStartPosition.Z
 		+ horizontalDirection.Z
 		* CLOSE_DISTANCE
 	local oldAutoRotate =
 		humanoid.AutoRotate
 	-- FORZAR ROTACIÓN
 	humanoid.AutoRotate = false
 	humanoid:ChangeState(
 		Enum.HumanoidStateType.Physics
 	)
 	local startTime =
 		os.clock()
 	while true do
 		if not root
 			or not root.Parent
 			or not humanoid
 			or humanoid.Health <= 0
 			or not targetRoot
 			or not targetRoot.Parent
 		then
 			break
 		end
 		local deltaTime =
 			RunService.Heartbeat:Wait()
 		-- VOLVER A FORZAR AUTO ROTATE OFF
 		humanoid.AutoRotate = false
 		local elapsed =
 			os.clock() - startTime
 		local alpha =
 			math.clamp(
 				elapsed / LOOK_TIME,
 				0,
 				1
 			)
 		local currentTargetY =
 			targetRoot.Position.Y
 			+ LOOK_Y_OFFSET
 		local easedAlpha =
 			1 -
 			(
 				(1 - alpha)
 				^ Y_EASING_POWER
 			)
 		local currentY =
 			startY
 			+ (
 				currentTargetY
 				- startY
 			)
 			* easedAlpha
 		local currentPosition =
 			Vector3.new(
 				fixedX,
 				currentY,
 				fixedZ
 			)
 		-- DIRECCIÓN HORIZONTAL HACIA EL ENEMIGO
 		local flatDirection =
 			Vector3.new(
 				targetRoot.Position.X
 					- currentPosition.X,
 				0,
 				targetRoot.Position.Z
 					- currentPosition.Z
 			)
 		if flatDirection.Magnitude >
 			0.001
 		then
 			flatDirection =
 				flatDirection.Unit
 			-- ÁNGULO VERTICAL REAL
 			local pitch =
 				math.rad(
 					math.clamp(
 						LOOK_AIM_UP,
 						-89,
 						89
 					)
 				)
 			local lookDirection =
 				(
 					flatDirection
 					* math.cos(pitch)
 				)
 				+
 				Vector3.new(
 					0,
 					math.sin(pitch),
 					0
 				)
 			lookDirection =
 				lookDirection.Unit
 			-- WANTED = ROTACIÓN FINAL DESEADA
 			local wanted =
 				CFrame.lookAt(
 					currentPosition,
 					currentPosition + lookDirection,
 					Vector3.yAxis
 				)
 			-- MISMO MÉTODO FORCE:
 			-- Root.CFrame:Lerp(Wanted, Alpha)
 			local rotationAlpha =
 				1 -
 				math.exp(
 					-ROTATION_SPEED
 					* deltaTime
 				)
 			root.CFrame =
 				root.CFrame:Lerp(
 					wanted,
 					rotationAlpha
 				)
 		else
 			-- SI ESTÁ EXACTAMENTE ENCIMA,
 			-- MANTENER LA POSICIÓN Y ROTACIÓN ACTUAL
 			root.CFrame =
 				CFrame.new(
 					currentPosition
 				)
 				* root.CFrame.Rotation
 		end
 		-- FORZAR POSICIÓN
 		local currentRotation =
 			root.CFrame.Rotation
 		root.CFrame =
 			CFrame.new(
 				currentPosition
 			)
 			* currentRotation
 		root.AssemblyLinearVelocity =
 			Vector3.zero
 		root.AssemblyAngularVelocity =
 			Vector3.zero
 		if alpha >= 1 then
 			break
 		end
 	end
 	--==================================================
 	-- RESTAURAR ROTACIÓN SIN PITCH
 	--==================================================
 	if root
 		and root.Parent
 		and humanoid
 		and humanoid.Health > 0
 	then
 		humanoid.AutoRotate = false
 		local wantedFinal =
 			CFrame.lookAt(
 				root.Position,
 				root.Position + originalFlatLook
 			)
 		root.CFrame =
 			root.CFrame:Lerp(
 				wantedFinal,
 				1
 			)
 		root.AssemblyLinearVelocity =
 			Vector3.zero
 		root.AssemblyAngularVelocity =
 			Vector3.zero
 	end
 	if root
 		and root.Parent
 	then
 		root.AssemblyLinearVelocity =
 			Vector3.zero
 		root.AssemblyAngularVelocity =
 			Vector3.zero
 	end
 	humanoid.AutoRotate =
 		oldAutoRotate
 	if humanoid.Health > 0 then
 		humanoid:ChangeState(
 			Enum.HumanoidStateType.Running
 		)
 	end
 end
 --==================================================
 -- SISTEMA DE HITBOX
 --==================================================
 local function activateHitboxSystem()
 	if not systemEnabled then
 		return
 	end
 	if hitboxActionOnCooldown then
 		print(
 			"Hitbox acción en cooldown"
 		)
 		return
 	end
 	print("HITBOX ACTIVADA")
 	local hitboxStart =
 		os.clock()
 	local targetFound =
 		false
 	while
 		os.clock() - hitboxStart
 		< HITBOX_TIME
 	do
 		if not systemEnabled then
 			break
 		end
 		if not character
 			or not root
 			or not humanoid
 			or humanoid.Health <= 0
 		then
 			break
 		end
 		local targetCharacter,
 			targetRoot =
 			getTarget()
 		if targetCharacter
 			and targetRoot
 		then
 			if not targetFound then
 				targetFound =
 					true
 				startHitboxActionCooldown()
 				print(
 					"enemigo detectado"
 				)
 				-- HIGHLIGHT DESACTIVADO
 				task.spawn(function()
 					moveUnderTarget(
 						targetRoot
 					)
 				end)
 				task.delay(
 					REMOTE_DELAY,
 					function()
 						fireRemote()
 					end
 				)
 			end
 			break
 		end
 		RunService.Heartbeat:Wait()
 	end
 end
 --==================================================
 -- UPPERCUT
 --==================================================
 local function activateUppercut()
 	if not systemEnabled then
 		return
 	end
 	if activeUppercut then
 		return
 	end
 	if hitboxActionOnCooldown then
 		return
 	end
 	if not character
 		or not root
 		or not humanoid
 		or humanoid.Health <= 0
 	then
 		return
 	end
 	activeUppercut =
 		true
 	task.wait(
 		UPPERCUT_TRIGGER_TIME
 	)
 	if systemEnabled
 		and not hitboxActionOnCooldown
 		and character
 		and root
 		and humanoid
 		and humanoid.Health > 0
 	then
 		activateHitboxSystem()
 	end
 	activeUppercut =
 		false
 end
 --==================================================
 -- DETECTAR ANIMACIÓN
 --==================================================
 local function onAnimationPlayed(track)
 	if not track
 		or not track.Animation
 	then
 		return
 	end
 	local animationId =
 		track.Animation.AnimationId:match(
 			"%d+"
 		)
 	if not ANIMATION_IDS[animationId] then
 		return
 	end
 	if not systemEnabled then
 		return
 	end
 	if hitboxActionOnCooldown then
 		return
 	end
 	task.spawn(function()
 		activateUppercut()
 	end)
 end
 --==================================================
 -- CHARACTER
 --==================================================
 local function setupCharacter()
 	character =
 		player.Character
 		or player.CharacterAdded:Wait()
 	humanoid =
 		character:WaitForChild(
 			"Humanoid"
 		)
 	root =
 		character:WaitForChild(
 			"HumanoidRootPart"
 		)
 	animator =
 		humanoid:FindFirstChildOfClass(
 			"Animator"
 		)
 	if not animator then
 		animator =
 			Instance.new(
 				"Animator"
 			)
 		animator.Parent =
 			humanoid
 	end
 	animator.AnimationPlayed:Connect(
 		onAnimationPlayed
 	)
 end
 --==================================================
 -- INICIAR
 --==================================================
 setupCharacter()
 player.CharacterAdded:Connect(
 	function()
 		task.wait(0.2)
 		setupCharacter()
 	end
 )
end)
