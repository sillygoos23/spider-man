local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	WalkSpeed = 16,
	SprintSpeed = 26,
	SpeedSmoothing = 10,

	UI = {
		ShowOnStart = true,
	},

	Camera = {
		SprintFOVBoost = 8,
		SwingFOVBoost = 22,
		Smoothing = 8,
		BlurMax = 4,
	},

	Web = {
		MaxDistance = 350,
		MinDistance = 0,
		DistanceLimitLow = 0,
		DistanceLimitHigh = 1000,
		MaxDistanceStep = 25,
		MinDistanceStep = 5,
		MinLength = 5,
		ShootSpeed = 520,

		AimAssist = true,
		AssistMinHeight = 10,

		SkyZipDistance = 140,

		GroundHop = 30,

		SwingBoost = 26,
		AirSteer = 45,
		AirDrag = 0.04,
		MaxSpeed = 170,
		JumpReleaseBoost = 26,

		RetractStartSpeed = 8,
		RetractAccel = 80,
		RetractMaxSpeed = 150,

		ExtendStartSpeed = 10,
		ExtendAccel = 45,
		ExtendMaxSpeed = 100,

		ZipStartSpeed = 55,
		ZipAccel = 520,
		ZipMaxSpeed = 150,
		ZipArriveDistance = 5,
		ZipPlayerArriveDistance = 6.5,
		ZipMaxTime = 2.2,
		ZipCooldown = 0.3,
		ZipExitKeep = 0.7,
		ZipExitLift = 14,

		Color = Color3.fromRGB(240, 247, 255),
		Segments = 14,
		Twists = 4,
		SpinSpeed = 5,
		MainThickness = 0.15,
		StrandThickness = 0.055,
		SplatSize = 3.4,
		TrailSpeed = 55,
	},
}

local settings = {
	JumpRelease = true,
	AutoZipPlayers = true,
	SkyZip = true,
}

local function keyBind(code)
	return { kind = "Key", code = code }
end
local function mouseBind(inputType)
	return { kind = "Mouse", mouse = inputType }
end

local ACTIONS = {
	{ id = "Swing",           label = "Web swing (hold)",       default = mouseBind(Enum.UserInputType.MouseButton1) },
	{ id = "Zip",             label = "Web zip",                default = keyBind(Enum.KeyCode.E) },
	{ id = "Retract",         label = "Reel in (hold)",         default = keyBind(Enum.KeyCode.R) },
	{ id = "Extend",          label = "Let out (hold)",         default = keyBind(Enum.KeyCode.F) },
	{ id = "Sprint",          label = "Sprint (hold)",          default = keyBind(Enum.KeyCode.LeftShift) },
	{ id = "ToggleJump",      label = "Toggle jump to let go",  default = keyBind(Enum.KeyCode.J) },
	{ id = "TogglePlayerZip", label = "Toggle auto zip to players", default = keyBind(Enum.KeyCode.P) },
	{ id = "ToggleMenu",      label = "Show / hide menu",       default = keyBind(Enum.KeyCode.K) },
}

local EXTRA_KEYS = {
	Sprint = { Enum.KeyCode.ButtonL3 },
	Swing = { Enum.KeyCode.ButtonR2 },
	Zip = { Enum.KeyCode.ButtonL2 },
}

local RESERVED_KEYS = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Space] = true, [Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true, [Enum.KeyCode.Tab] = true,
	[Enum.KeyCode.Slash] = true, [Enum.KeyCode.Return] = true,
}

local binds = {}
for _, action in ACTIONS do
	binds[action.id] = action.default
end

local function matches(input, actionId)
	local b = binds[actionId]
	if b.kind == "Key" then
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == b.code then
			return true
		end
	elseif input.UserInputType == b.mouse then
		return true
	end
	local extras = EXTRA_KEYS[actionId]
	if extras then
		for _, key in extras do
			if input.KeyCode == key then
				return true
			end
		end
	end
	return false
end

local function sameBind(a, b)
	return a.kind == b.kind and a.code == b.code and a.mouse == b.mouse
end

local POSES = {
	R15 = {
		Idle   = { lean = 0,     hip = 0,   knee = 0,   arm = 0 },
		Sprint = { lean = -0.25, hip = 0,   knee = 0,   arm = 0.15 },
		Swing  = { lean = -0.35, hip = 0.6, knee = 1.0, arm = 0.5 },
		Zip    = { lean = -0.8,  hip = 0.2, knee = 0.3, arm = 0.2 },
	},
	R6 = {
		Idle   = { lean = 0,     hip = 0,   knee = 0, arm = 0 },
		Sprint = { lean = -0.25, hip = 0,   knee = 0, arm = 0.15 },
		Swing  = { lean = -0.35, hip = 0.6, knee = 0, arm = 0.5 },
		Zip    = { lean = -0.8,  hip = 0.2, knee = 0, arm = 0.2 },
	},
}

local JOINT_SPECS = {
	R15 = {
		Root = { "LowerTorso", "Root" },
		LeftHip = { "LeftUpperLeg", "LeftHip" },
		RightHip = { "RightUpperLeg", "RightHip" },
		LeftKnee = { "LeftLowerLeg", "LeftKnee" },
		RightKnee = { "RightLowerLeg", "RightKnee" },
		LeftShoulder = { "LeftUpperArm", "LeftShoulder" },
		RightShoulder = { "RightUpperArm", "RightShoulder" },
	},
	R6 = {
		Root = { "HumanoidRootPart", "RootJoint" },
		LeftHip = { "Torso", "Left Hip" },
		RightHip = { "Torso", "Right Hip" },
		LeftShoulder = { "Torso", "Left Shoulder" },
		RightShoulder = { "Torso", "Right Shoulder" },
	},
}

local HIPS = { "LeftHip", "RightHip" }
local KNEES = { "LeftKnee", "RightKnee" }

local character, humanoid, rootPart, rootAttachment, windTrail
local rig = "R15"
local ready = false
local joints = {}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local fxFolder = Instance.new("Folder")
fxFolder.Name = "WebSwingFX"
fxFolder.Parent = camera

local speedBlur = Instance.new("BlurEffect")
speedBlur.Name = "WebSwingBlur"
speedBlur.Size = 0
speedBlur.Parent = camera

local state = {
	sprintHeld = false,
	retractHeld = false,
	extendHeld = false,
	lastZipEnd = 0,
	web = nil,
}

local pose = { lean = 0, hip = 0, knee = 0, arm = 0, armR = 0 }
local target = { lean = 0, hip = 0, knee = 0, arm = 0, armR = 0 }

local baseFOV = camera.FieldOfView

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function maxWebLength()
	return CONFIG.Web.MaxDistance + 50
end

local function isGrounded()
	return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
end

local function isSprinting()
	return state.sprintHeld and humanoid.MoveDirection.Magnitude > 0.1 and not state.web
end

local function footOffset()
	if rig == "R6" then
		return 3
	end
	return humanoid.HipHeight + rootPart.Size.Y / 2
end

local function getHandPosition()
	local hand = character:FindFirstChild("RightHand")
	if hand then
		return hand.Position
	end
	local arm = character:FindFirstChild("Right Arm")
	if arm then
		return (arm.CFrame * CFrame.new(0, -0.9, 0)).Position
	end
	return rootPart.Position
end

local function getAnchor(web)
	local part = web.targetPart
	if part and part.Parent then
		return part.CFrame:PointToWorldSpace(web.localOffset)
	end
	return web.hitPos
end

local function emitBurst(pos, color, count, speed, size)
	size = size or 0.5
	local part = Instance.new("Part")
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.one
	part.Position = pos
	part.Parent = fxFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.25, 0.55)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = part
	emitter:Emit(count)
	Debris:AddItem(part, 1)
end

local function impactRing(pos, normal, color)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.12, 1, 1)
	ring.CFrame = CFrame.lookAt(pos + normal * 0.08, pos + normal) * CFrame.Angles(0, math.pi / 2, 0)
	ring.Parent = fxFolder
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.12, 7, 7),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
end

local function newLinePart(thickness, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = CONFIG.Web.Color
	p.Transparency = transparency
	p.Size = Vector3.new(thickness, thickness, 1)
	p.Parent = fxFolder
	return p
end

local function placeLine(p, a, b)
	local d = b - a
	local len = d.Magnitude
	if len < 0.01 then
		len = 0.01
		d = Vector3.new(0, 0, -0.01)
	end
	p.Size = Vector3.new(p.Size.X, p.Size.Y, len)
	p.CFrame = CFrame.lookAt(a + d / 2, a + d)
end

local function buildStrands(parts)
	local W = CONFIG.Web
	local N = W.Segments
	local s = { core = {}, a = {}, b = {}, rungs = {} }
	for i = 1, N do
		s.core[i] = newLinePart(W.MainThickness, 0)
		s.a[i] = newLinePart(W.StrandThickness, 0.1)
		s.b[i] = newLinePart(W.StrandThickness, 0.1)
		table.insert(parts, s.core[i])
		table.insert(parts, s.a[i])
		table.insert(parts, s.b[i])
	end
	for i = 1, N - 1 do
		s.rungs[i] = newLinePart(W.StrandThickness * 0.8, 0.3)
		table.insert(parts, s.rungs[i])
	end
	return s
end

local function updateWebVisual(web, startPos, endPos)
	local W = CONFIG.Web
	local N = W.Segments
	local axis = endPos - startPos
	local len = axis.Magnitude
	if len < 0.5 then
		return
	end

	local dir = axis / len
	local right = dir:Cross(Vector3.yAxis)
	if right.Magnitude < 0.05 then
		right = dir:Cross(Vector3.xAxis)
	end
	right = right.Unit
	local up = right:Cross(dir)

	local radius = math.min(lerp(1.0, 0.22, web.tension), len * 0.06)
	local time = os.clock()
	local strands = web.strands

	local prevC, prevA, prevB
	for i = 0, N do
		local t = i / N
		local env = math.sin(math.pi * t)
		local lateral = (right * math.sin(t * math.pi * 4 + time * 26) + up * math.cos(t * math.pi * 3 + time * 21))
			* web.wave * env
		local center = startPos + axis * t - Vector3.new(0, web.sag * env, 0) + lateral
		local angle = t * W.Twists * 2 * math.pi + time * W.SpinSpeed
		local offset = (right * math.cos(angle) + up * math.sin(angle)) * radius * env
		local pa = center + offset
		local pb = center - offset

		if i > 0 then
			placeLine(strands.core[i], prevC, center)
			placeLine(strands.a[i], prevA, pa)
			placeLine(strands.b[i], prevB, pb)
		end
		if i > 0 and i < N then
			placeLine(strands.rungs[i], pa, pb)
		end
		prevC, prevA, prevB = center, pa, pb
	end
end

local function buildSplat(web)
	local W = CONFIG.Web
	local n = web.normal
	local right = n:Cross(Vector3.yAxis)
	if right.Magnitude < 0.1 then
		right = n:Cross(Vector3.xAxis)
	end
	right = right.Unit
	local up = n:Cross(right).Unit
	local center = web.hitPos + n * 0.06
	local size = W.SplatSize
	local SPOKES = 9

	local jitter = {}
	for k = 0, SPOKES - 1 do
		jitter[k] = 0.85 + math.random() * 0.3
	end

	local function pointAt(k, radius)
		local idx = k % SPOKES
		local angle = idx / SPOKES * 2 * math.pi
		return center + (right * math.cos(angle) + up * math.sin(angle)) * radius * jitter[idx]
	end

	local splat = {}
	for k = 0, SPOKES - 1 do
		local line = newLinePart(W.StrandThickness * 1.3, 1)
		placeLine(line, center, pointAt(k, size * 1.05))
		table.insert(splat, line)
	end
	for _, fraction in { 0.25, 0.5, 0.75, 1.0 } do
		for k = 0, SPOKES - 1 do
			local line = newLinePart(W.StrandThickness, 1)
			placeLine(line, pointAt(k, size * fraction), pointAt(k + 1, size * fraction * 0.94))
			table.insert(splat, line)
		end
	end

	for _, p in splat do
		table.insert(web.parts, p)
		TweenService:Create(p, TweenInfo.new(0.18), { Transparency = 0.1 }):Play()
	end
end

local function fadeAndRemove(parts, duration)
	for _, p in parts do
		TweenService:Create(p, TweenInfo.new(duration), { Transparency = 1 }):Play()
		Debris:AddItem(p, duration + 0.05)
	end
end

local function getAimRay()
	local lastType = UserInputService:GetLastInputType()
	local pos
	if lastType.Name:find("Gamepad") or lastType == Enum.UserInputType.Touch then
		pos = camera.ViewportSize / 2
	else
		pos = UserInputService:GetMouseLocation()
	end
	return camera:ViewportPointToRay(pos.X, pos.Y)
end

local function castSkipping(params, filter, origin, direction)
	for _ = 1, 5 do
		local result = workspace:Raycast(origin, direction, params)
		if not result then
			return nil
		end
		local inst = result.Instance
		if inst:IsA("Terrain") or inst.Transparency < 0.98 or inst.CanCollide then
			return result
		end
		table.insert(filter, inst)
		params.FilterDescendantsInstances = filter
	end
	return nil
end

local function isFloorHit(hit)
	return hit.Normal.Y > 0.7 and hit.Position.Y < rootPart.Position.Y + 2
end

local function findTarget(allowAssist)
	local W = CONFIG.Web
	local ray = getAimRay()

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = table.clone(raycastParams.FilterDescendantsInstances)
	params.FilterDescendantsInstances = filter

	local rootPos = rootPart.Position
	local direct = castSkipping(params, filter, ray.Origin, ray.Direction * (W.MaxDistance + 60))
	if direct then
		local d = (direct.Position - rootPos).Magnitude
		if d > W.MaxDistance or d < W.MinDistance then
			direct = nil
		end
	end

	if direct and not (allowAssist and isFloorHit(direct)) then
		return direct, ray
	end

	if allowAssist and W.AimAssist then
		local base = CFrame.lookAt(ray.Origin, ray.Origin + ray.Direction)
		local minDist = math.max(14, W.MinDistance)
		local best, bestScore
		for _, yaw in { 0, -8, 8, -16, 16, -26, 26, -38, 38 } do
			for _, pitch in { 0, 8, 16, 24, 34, 45 } do
				local cf = base * CFrame.fromEulerAnglesYXZ(math.rad(pitch), math.rad(yaw), 0)
				local hit = castSkipping(params, filter, ray.Origin, cf.LookVector * (W.MaxDistance + 60))
				if hit then
					local height = hit.Position.Y - rootPos.Y
					local dist = (hit.Position - rootPos).Magnitude
					local model = hit.Instance:FindFirstAncestorOfClass("Model")
					local isCharacter = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
					if height > W.AssistMinHeight and dist > minDist and dist < W.MaxDistance and not isCharacter then
						local score = math.abs(yaw) + pitch * 0.9 + dist * 0.03
						if not bestScore or score < bestScore then
							best, bestScore = hit, score
						end
					end
				end
			end
		end
		if best then
			return best, ray
		end
	end

	return direct, ray
end

local hudStatus
local function flashStatus(text)
	if hudStatus then
		hudStatus.Text = text
		task.delay(1.2, function()
			if hudStatus and hudStatus.Text == text then
				hudStatus.Text = ""
			end
		end)
	end
end

local function releaseWeb(jumpBoost)
	local web = state.web
	if not web then
		return
	end
	state.web = nil

	if web.align then
		web.align:Destroy()
	end
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
		if web.phase == "attached" and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end

	fadeAndRemove(web.parts, 0.25)

	if jumpBoost and rootPart then
		local v = rootPart.AssemblyLinearVelocity
		rootPart.AssemblyLinearVelocity = v + Vector3.new(0, CONFIG.Web.JumpReleaseBoost, 0)
	end
end

local function startWeb(mode)
	local hit, ray = findTarget(mode == "swing")
	local isSky = false
	local hitPos, hitNormal

	if hit then
		hitPos, hitNormal = hit.Position, hit.Normal
	elseif mode == "zip" and settings.SkyZip then
		local dist = math.min(CONFIG.Web.SkyZipDistance, CONFIG.Web.MaxDistance)
		hitPos = rootPart.Position + ray.Direction * dist
		hitNormal = -ray.Direction
		isSky = true
	else
		flashStatus("No web target")
		return
	end

	local web = {
		mode = mode,
		phase = "shooting",
		hitPos = hitPos,
		normal = hitNormal,
		isSky = isSky,
		shootStart = os.clock(),
		shootTime = math.clamp((hitPos - rootPart.Position).Magnitude / CONFIG.Web.ShootSpeed, 0.04, 0.25),
		length = 0,
		retractTime = 0,
		extendTime = 0,
		zipStart = 0,
		attachTime = 0,
		tension = 0.3,
		sag = 0,
		wave = 1.6,
		localOffset = Vector3.zero,
		parts = {},
	}

	if hit then
		local inst = hit.Instance
		local model = inst:FindFirstAncestorOfClass("Model")
		local isCharacter = model ~= nil and model ~= character and model:FindFirstChildOfClass("Humanoid") ~= nil
		if isCharacter then
			local theirRoot = model:FindFirstChild("HumanoidRootPart") or inst
			web.targetPart = theirRoot
			web.localOffset = Vector3.zero
			web.isCharacter = true
			web.normal = (rootPart.Position - theirRoot.Position).Unit
			if mode == "swing" and settings.AutoZipPlayers then
				web.mode = "zip"
			end
		elseif not inst:IsA("Terrain") then
			web.targetPart = inst
			web.localOffset = inst.CFrame:PointToObjectSpace(hit.Position)
		end
	end

	web.strands = buildStrands(web.parts)
	state.web = web

	emitBurst(getHandPosition(), CONFIG.Web.Color, 10, 12, 0.45)
end

local function attachWeb(web)
	local W = CONFIG.Web
	web.phase = "attached"
	web.attachTime = os.clock()
	web.zipStart = web.attachTime

	local anchor = getAnchor(web)
	local wasGrounded = isGrounded()

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = rootAttachment
	align.RigidityEnabled = false
	align.MaxTorque = 1e6
	align.Responsiveness = 18
	align.CFrame = rootPart.CFrame.Rotation
	align.Parent = rootPart
	web.align = align

	local v = rootPart.AssemblyLinearVelocity
	if web.mode == "swing" then
		web.length = math.min((anchor - rootPart.Position).Magnitude, maxWebLength())
		if wasGrounded then
			rootPart.AssemblyLinearVelocity = v + Vector3.new(0, W.GroundHop, 0)
		end
	elseif wasGrounded then
		rootPart.AssemblyLinearVelocity = v + Vector3.new(0, 12, 0)
	end

	if web.isSky then
		emitBurst(anchor, W.Color, 12, 12, 0.45)
		return
	end

	if not web.isCharacter then
		buildSplat(web)
		impactRing(web.hitPos, web.normal, W.Color)
	end
	emitBurst(anchor, W.Color, 16, 16, 0.5)
end

local function convertToZip(web)
	web.mode = "zip"
	web.zipStart = os.clock()
	web.retractTime = 0
	web.extendTime = 0
	if isGrounded() then
		local v = rootPart.AssemblyLinearVelocity
		rootPart.AssemblyLinearVelocity = v + Vector3.new(0, 12, 0)
	end
	emitBurst(getHandPosition(), CONFIG.Web.Color, 8, 10, 0.45)
end

local function startZip()
	if os.clock() - state.lastZipEnd < CONFIG.Web.ZipCooldown then
		return
	end
	local web = state.web
	if web then
		if web.phase == "attached" and web.mode == "swing" then
			convertToZip(web)
		end
		return
	end
	startWeb("zip")
end

local function finishZip()
	local W = CONFIG.Web
	local v = rootPart.AssemblyLinearVelocity
	local exitVelocity = v * W.ZipExitKeep + Vector3.new(0, W.ZipExitLift, 0)
	releaseWeb(false)
	rootPart.AssemblyLinearVelocity = exitVelocity
	state.lastZipEnd = os.clock()
	emitBurst(rootPart.Position, W.Color, 10, 10, 0.45)
end

local function faceDirection(web, flatDir)
	if flatDir.Magnitude > 0.01 then
		web.align.CFrame = CFrame.lookAt(Vector3.zero, flatDir)
	end
end

local function updateWebZip(web, dt)
	local W = CONFIG.Web
	local anchor = getAnchor(web)
	local toAnchor = anchor - rootPart.Position
	local dist = toAnchor.Magnitude
	local elapsed = os.clock() - web.zipStart
	local arrive = web.isCharacter and W.ZipPlayerArriveDistance or W.ZipArriveDistance

	if dist <= arrive
		or elapsed > W.ZipMaxTime
		or (elapsed > 0.25 and rootPart.AssemblyLinearVelocity.Magnitude < 12) then
		finishZip()
		return
	end

	local dir = toAnchor / dist
	local speed = math.min(W.ZipMaxSpeed, W.ZipStartSpeed + W.ZipAccel * elapsed)
	speed = math.min(speed, (dist - arrive * 0.5) / math.max(dt, 1 / 120))
	rootPart.AssemblyLinearVelocity = dir * speed

	faceDirection(web, Vector3.new(dir.X, 0, dir.Z))
end

local function updateWebSwing(web, dt)
	local W = CONFIG.Web
	local now = os.clock()

	local anchor = getAnchor(web)
	local pos = rootPart.Position
	local toAnchor = anchor - pos
	local dist = toAnchor.Magnitude
	if dist < 0.5 then
		releaseWeb(false)
		return
	end
	local dir = toAnchor / dist
	local vel = rootPart.AssemblyLinearVelocity

	if state.retractHeld then
		web.retractTime += dt
		web.extendTime = 0
		local pull = math.min(W.RetractMaxSpeed, W.RetractStartSpeed + W.RetractAccel * web.retractTime ^ 1.5)
		web.length = math.max(W.MinLength, math.min(web.length, dist) - pull * dt)
		local radial = vel:Dot(dir)
		if radial < pull then
			vel += dir * (pull - radial) * (1 - math.exp(-dt * 6))
		end
	elseif state.extendHeld then
		web.extendTime += dt
		web.retractTime = 0
		local speed = math.min(W.ExtendMaxSpeed, W.ExtendStartSpeed + W.ExtendAccel * web.extendTime ^ 1.5)
		web.length = math.min(maxWebLength(), web.length + speed * dt)
	else
		web.retractTime = 0
		web.extendTime = 0
	end

	if dist >= web.length - 0.4 then
		local radial = vel:Dot(dir)
		if radial < 0 then
			vel -= dir * radial
		end
		if dist > web.length then
			vel += dir * math.min((dist - web.length) * 12 * math.min(dt * 60, 3), 45)
		end

		local tangent = vel - dir * vel:Dot(dir)
		if tangent.Magnitude > 10 then
			vel += tangent.Unit * W.SwingBoost * dt
		end
	end

	local move = humanoid.MoveDirection
	if move.Magnitude > 0.1 then
		vel += move * W.AirSteer * dt
	end

	vel *= 1 - W.AirDrag * dt
	if vel.Magnitude > W.MaxSpeed then
		vel = vel.Unit * W.MaxSpeed
	end
	rootPart.AssemblyLinearVelocity = vel

	local flat = Vector3.new(vel.X, 0, vel.Z)
	if flat.Magnitude < 6 then
		flat = Vector3.new(dir.X, 0, dir.Z)
	end
	faceDirection(web, flat)

	if now - web.attachTime > 0.4 and vel.Y <= 2 then
		local hit = workspace:Raycast(pos, Vector3.new(0, -(footOffset() + 1.2), 0), raycastParams)
		if hit and hit.Instance.CanCollide then
			releaseWeb(false)
		end
	end
end

local function updateWeb(web, dt)
	if web.targetPart and not web.targetPart:IsDescendantOf(workspace) then
		releaseWeb(false)
		return
	end
	if web.mode == "zip" then
		updateWebZip(web, dt)
	else
		updateWebSwing(web, dt)
	end
end

local COLORS = {
	Panel = Color3.fromRGB(20, 22, 30),
	Stroke = Color3.fromRGB(80, 90, 120),
	Button = Color3.fromRGB(44, 48, 62),
	Listening = Color3.fromRGB(190, 40, 50),
	Accent = Color3.fromRGB(220, 50, 60),
	On = Color3.fromRGB(46, 140, 80),
	Off = Color3.fromRGB(110, 50, 55),
	Text = Color3.fromRGB(238, 240, 247),
	Muted = Color3.fromRGB(160, 168, 184),
	Warn = Color3.fromRGB(255, 170, 120),
}

local NUMBER_WORDS = {
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
	Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
}

local MOUSE_NAMES = {
	[Enum.UserInputType.MouseButton1] = "Left Click",
	[Enum.UserInputType.MouseButton2] = "Right Click",
	[Enum.UserInputType.MouseButton3] = "Middle Click",
}

local function prettyKeyName(keyCode)
	local name = keyCode.Name
	if name:sub(1, 6) == "Keypad" then
		local rest = name:sub(7)
		return "Num " .. (NUMBER_WORDS[rest] or rest)
	end
	return (name:gsub("(%l)(%u)", "%1 %2"))
end

local function prettyBindName(bind)
	if bind.kind == "Key" then
		return prettyKeyName(bind.code)
	end
	return MOUSE_NAMES[bind.mouse] or bind.mouse.Name
end

local ui = { panel = nil, toggleButton = nil, status = nil, buttons = {}, toggles = {}, values = {} }
local listening = nil

local TOGGLES = {
	{ key = "JumpRelease",    label = "Jump to let go of web" },
	{ key = "AutoZipPlayers", label = "Auto zip to players" },
	{ key = "SkyZip",         label = "Zip in the sky" },
}

local STEPPERS = {
	{ key = "MaxDistance", label = "Max web distance", step = "MaxDistanceStep" },
	{ key = "MinDistance", label = "Min web distance", step = "MinDistanceStep" },
}

local function setStatus(text, isWarning)
	if ui.status then
		ui.status.Text = text
		ui.status.TextColor3 = isWarning and COLORS.Warn or COLORS.Muted
	end
end

local function refreshUI()
	for _, action in ACTIONS do
		local button = ui.buttons[action.id]
		if button then
			if listening == action.id then
				button.Text = "Press a key..."
				button.BackgroundColor3 = COLORS.Listening
			else
				button.Text = prettyBindName(binds[action.id])
				button.BackgroundColor3 = COLORS.Button
			end
		end
	end
	for _, t in TOGGLES do
		local button = ui.toggles[t.key]
		if button then
			local on = settings[t.key]
			button.Text = on and "ON" or "OFF"
			button.BackgroundColor3 = on and COLORS.On or COLORS.Off
		end
	end
	for _, s in STEPPERS do
		local label = ui.values[s.key]
		if label then
			label.Text = tostring(CONFIG.Web[s.key])
		end
	end
	if ui.toggleButton then
		ui.toggleButton.Text = "Controls (" .. prettyBindName(binds.ToggleMenu) .. ")"
	end
end

local function adjustDistance(key, direction)
	local W = CONFIG.Web
	local stepSize = W[key == "MaxDistance" and "MaxDistanceStep" or "MinDistanceStep"]
	local value = W[key] + direction * stepSize
	if key == "MaxDistance" then
		value = math.clamp(value, math.max(W.DistanceLimitLow + stepSize, W.MinDistance + stepSize), W.DistanceLimitHigh)
	else
		value = math.clamp(value, W.DistanceLimitLow, W.MaxDistance - W.MaxDistanceStep)
	end
	W[key] = value
	refreshUI()
end

local function toggleSetting(key)
	settings[key] = not settings[key]
	refreshUI()
end

local function stopListening()
	listening = nil
	refreshUI()
end

local function beginListening(actionId)
	if listening == actionId then
		stopListening()
		setStatus("Cancelled.", false)
		return
	end
	listening = actionId
	for _, action in ACTIONS do
		if action.id == actionId then
			setStatus('Press the new key or mouse button for "' .. action.label .. '" (Esc cancels)', false)
		end
	end
	refreshUI()
end

local function onRebind(newBind)
	if newBind.kind == "Key" then
		if newBind.code == Enum.KeyCode.Escape or newBind.code == Enum.KeyCode.Backspace then
			stopListening()
			setStatus("Cancelled.", false)
			return
		end
		if RESERVED_KEYS[newBind.code] then
			setStatus(prettyKeyName(newBind.code) .. " can't be used (movement / chat). Try another key.", true)
			return
		end
	end

	local id = listening
	for _, action in ACTIONS do
		if action.id ~= id and sameBind(binds[action.id], newBind) then
			binds[action.id] = binds[id]
		end
	end
	binds[id] = newBind

	state.sprintHeld = false
	state.retractHeld = false
	state.extendHeld = false

	listening = nil
	refreshUI()
	setStatus("Bound to " .. prettyBindName(newBind) .. ".", false)
end

local function toggleMenu()
	if not ui.panel then
		return
	end
	ui.panel.Visible = not ui.panel.Visible
	if not ui.panel.Visible and listening then
		stopListening()
	end
end

local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in props do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local hudSpeed

local function createUI()
	local playerGui = player:WaitForChild("PlayerGui")

	local old = playerGui:FindFirstChild("WebSwingUI")
	if old then
		old:Destroy()
	end

	local gui = make("ScreenGui", {
		Name = "WebSwingUI",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	ui.toggleButton = make("TextButton", {
		Name = "ToggleButton",
		Size = UDim2.fromOffset(150, 30),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.1,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Text = "Controls",
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, ui.toggleButton)
	make("UIStroke", { Color = COLORS.Stroke, Thickness = 1 }, ui.toggleButton)
	ui.toggleButton.Activated:Connect(toggleMenu)

	local panel = make("Frame", {
		Name = "Panel",
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.05,
		Visible = CONFIG.UI.ShowOnStart,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
	make("UIStroke", { Color = COLORS.Accent, Thickness = 1.5 }, panel)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
	}, panel)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	ui.panel = panel

	local function header(order, text)
		make("TextLabel", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = COLORS.Text,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, panel)
	end

	local function rowLabel(row, text)
		make("TextLabel", {
			Size = UDim2.new(1, -136, 1, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = COLORS.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
	end

	local function smallButton(parent, props)
		local b = make("TextButton", {
			AnchorPoint = props.AnchorPoint,
			Position = props.Position,
			Size = props.Size,
			BackgroundColor3 = COLORS.Button,
			TextColor3 = COLORS.Text,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Text = props.Text or "",
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		return b
	end

	header(0, "Web Swing Controls")

	make("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Text = "Click a key, then press the key or mouse button you want. Webbing a player zips you to them if auto zip is on.",
		TextColor3 = COLORS.Muted,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, panel)

	for index, action in ACTIONS do
		local row = make("Frame", {
			Name = action.id,
			LayoutOrder = 10 + index,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
		}, panel)
		rowLabel(row, action.label)
		local button = smallButton(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(128, 28),
		})
		button.Activated:Connect(function()
			beginListening(action.id)
		end)
		ui.buttons[action.id] = button
	end

	header(50, "Settings")

	for index, t in TOGGLES do
		local row = make("Frame", {
			LayoutOrder = 50 + index,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
		}, panel)
		rowLabel(row, t.label)
		local button = smallButton(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(128, 28),
		})
		button.Activated:Connect(function()
			toggleSetting(t.key)
		end)
		ui.toggles[t.key] = button
	end

	for index, s in STEPPERS do
		local row = make("Frame", {
			LayoutOrder = 60 + index,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
		}, panel)
		rowLabel(row, s.label)
		local plus = smallButton(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(34, 28),
			Text = "+",
		})
		local value = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -38, 0.5, 0),
			Size = UDim2.fromOffset(56, 28),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = COLORS.Text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
		}, row)
		local minus = smallButton(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -98, 0.5, 0),
			Size = UDim2.fromOffset(34, 28),
			Text = "-",
		})
		plus.Activated:Connect(function()
			adjustDistance(s.key, 1)
		end)
		minus.Activated:Connect(function()
			adjustDistance(s.key, -1)
		end)
		ui.values[s.key] = value
	end

	local reset = make("TextButton", {
		LayoutOrder = 100,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = COLORS.Button,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Text = "Reset controls to defaults",
	}, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, reset)
	reset.Activated:Connect(function()
		for _, action in ACTIONS do
			binds[action.id] = action.default
		end
		listening = nil
		refreshUI()
		setStatus("Controls reset to defaults.", false)
	end)

	ui.status = make("TextLabel", {
		LayoutOrder = 101,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = COLORS.Muted,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, panel)

	hudSpeed = make("TextLabel", {
		Name = "Speed",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(220, 26),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = COLORS.Text,
		TextStrokeTransparency = 0.5,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	}, gui)
	hudStatus = make("TextLabel", {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -50),
		Size = UDim2.fromOffset(300, 22),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = COLORS.Warn,
		TextStrokeTransparency = 0.5,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
	}, gui)

	refreshUI()
end

task.spawn(createUI)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if listening then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			onRebind(keyBind(input.KeyCode))
		elseif not gameProcessed and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton3) then
			onRebind(mouseBind(input.UserInputType))
		end
		return
	end

	if gameProcessed then
		return
	end

	if matches(input, "ToggleMenu") then
		toggleMenu()
		return
	end

	if matches(input, "ToggleJump") then
		toggleSetting("JumpRelease")
		flashStatus("Jump to let go: " .. (settings.JumpRelease and "ON" or "OFF"))
		return
	end

	if matches(input, "TogglePlayerZip") then
		toggleSetting("AutoZipPlayers")
		flashStatus("Auto zip to players: " .. (settings.AutoZipPlayers and "ON" or "OFF"))
		return
	end

	if not ready or humanoid.Health <= 0 then
		return
	end

	if matches(input, "Sprint") then
		state.sprintHeld = true
	elseif matches(input, "Swing") then
		if not state.web then
			startWeb("swing")
		end
	elseif matches(input, "Zip") then
		startZip()
	elseif matches(input, "Retract") then
		state.retractHeld = true
	elseif matches(input, "Extend") then
		state.extendHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if matches(input, "Sprint") then
		state.sprintHeld = false
	elseif matches(input, "Swing") then
		local web = state.web
		if web and web.mode == "swing" then
			releaseWeb(false)
		end
	elseif matches(input, "Retract") then
		state.retractHeld = false
	elseif matches(input, "Extend") then
		state.extendHeld = false
	end
end)

UserInputService.JumpRequest:Connect(function()
	if not ready or humanoid.Health <= 0 then
		return
	end
	if state.web and settings.JumpRelease then
		releaseWeb(true)
	end
end)

local function rotated(joint, angle)
	return joint.c0 * CFrame.fromAxisAngle(joint.axis, angle)
end

local function applyPose()
	local j = joints

	if j.Root then
		j.Root.motor.C0 = rotated(j.Root, pose.lean)
	end
	for _, name in HIPS do
		if j[name] then
			j[name].motor.C0 = rotated(j[name], pose.hip)
		end
	end
	for _, name in KNEES do
		if j[name] then
			j[name].motor.C0 = rotated(j[name], -pose.knee)
		end
	end
	if j.LeftShoulder then
		j.LeftShoulder.motor.C0 = rotated(j.LeftShoulder, pose.arm)
	end
	if j.RightShoulder then
		j.RightShoulder.motor.C0 = rotated(j.RightShoulder, pose.armR)
	end
end

local function chooseTargetPose()
	local presets = POSES[rig]
	local web = state.web
	local base

	if web and web.phase == "attached" and web.mode == "zip" then
		base = presets.Zip
	elseif web then
		base = presets.Swing
	elseif isSprinting() then
		base = presets.Sprint
	else
		base = presets.Idle
	end

	for key, value in base do
		target[key] = value
	end
	target.armR = base.arm

	if web then
		if web.mode == "swing" and web.phase == "attached" then
			local vy = rootPart.AssemblyLinearVelocity.Y
			target.lean = math.clamp(-0.35 + vy / 160, -0.95, 0.2)
		end

		local offset = getAnchor(web) - rootPart.Position
		if offset.Magnitude > 0.1 then
			local localDir = rootPart.CFrame:VectorToObjectSpace(offset.Unit)
			target.armR = math.atan2(-localDir.Z, -localDir.Y) - pose.lean
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	if not ready or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()

	local web = state.web
	if web then
		if web.phase == "shooting" then
			if now - web.shootStart >= web.shootTime then
				attachWeb(web)
			end
		else
			updateWeb(web, dt)
		end
	end

	local desired = CONFIG.WalkSpeed
	if isSprinting() then
		desired = CONFIG.SprintSpeed
	end
	humanoid.WalkSpeed = lerp(humanoid.WalkSpeed, desired, 1 - math.exp(-dt * CONFIG.SpeedSmoothing))
end)

RunService.RenderStepped:Connect(function(dt)
	if not ready or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local alpha = 1 - math.exp(-dt * 14)
	local vel = rootPart.AssemblyLinearVelocity
	local speed = vel.Magnitude

	chooseTargetPose()
	for key, value in target do
		pose[key] = lerp(pose[key], value, alpha)
	end
	applyPose()

	local web = state.web
	if web then
		local startPos = getHandPosition()
		local endPos
		local anchor = getAnchor(web)

		if web.phase == "shooting" then
			local p = math.clamp((now - web.shootStart) / web.shootTime, 0, 1)
			endPos = startPos:Lerp(anchor, p)
		else
			endPos = anchor
			web.wave = lerp(web.wave, 0, 1 - math.exp(-dt * 7))
			if web.mode == "zip" then
				web.tension = lerp(web.tension, 1, alpha)
				web.sag = lerp(web.sag, 0, alpha)
			else
				local dist = (endPos - rootPart.Position).Magnitude
				local slack = math.max(0, web.length - dist)
				web.tension = lerp(web.tension, 1 - math.clamp(slack / 3, 0, 1), alpha)
				web.sag = lerp(web.sag, math.min(slack, 4) * 0.5, alpha)
			end
		end

		updateWebVisual(web, startPos, endPos)
	end

	if windTrail then
		windTrail.Enabled = speed > CONFIG.Web.TrailSpeed
	end

	local fov = baseFOV
	local blur = 0
	if state.web and state.web.phase == "attached" then
		local k = math.clamp((speed - 20) / 110, 0, 1)
		fov += CONFIG.Camera.SwingFOVBoost * k
		blur = CONFIG.Camera.BlurMax * math.clamp((speed - 90) / 70, 0, 1)
	elseif isSprinting() then
		fov += CONFIG.Camera.SprintFOVBoost
	end
	camera.FieldOfView = lerp(camera.FieldOfView, fov, 1 - math.exp(-dt * CONFIG.Camera.Smoothing))
	speedBlur.Size = lerp(speedBlur.Size, blur, 1 - math.exp(-dt * 6))

	if hudSpeed then
		hudSpeed.Text = speed > 8 and (math.floor(speed + 0.5) .. " studs/s") or ""
	end
end)

local function cacheJoint(jointName, partName)
	local part = character:WaitForChild(partName, 5)
	local motor = part and part:WaitForChild(jointName, 5)
	if motor and motor:IsA("Motor6D") then
		joints[jointName] = {
			motor = motor,
			c0 = motor.C0,
			axis = motor.C0:VectorToObjectSpace(Vector3.xAxis),
		}
	end
end

local function setupCharacter(char)
	ready = false
	releaseWeb(false)

	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	rig = humanoid.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6"

	raycastParams.FilterDescendantsInstances = { char, fxFolder }

	table.clear(joints)
	for jointName, spec in JOINT_SPECS[rig] do
		cacheJoint(jointName, spec[1])
	end

	rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "WebAttachment"
	rootAttachment.Parent = rootPart

	local a0 = Instance.new("Attachment")
	a0.Name = "WebTrailTop"
	a0.Position = Vector3.new(0, 1.3, 0)
	a0.Parent = rootPart
	local a1 = Instance.new("Attachment")
	a1.Name = "WebTrailBottom"
	a1.Position = Vector3.new(0, -1.3, 0)
	a1.Parent = rootPart
	windTrail = Instance.new("Trail")
	windTrail.Attachment0 = a0
	windTrail.Attachment1 = a1
	windTrail.Lifetime = 0.35
	windTrail.MinLength = 0.1
	windTrail.LightEmission = 0.6
	windTrail.Color = ColorSequence.new(CONFIG.Web.Color)
	windTrail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	windTrail.Enabled = false
	windTrail.Parent = rootPart

	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	state.retractHeld = false
	state.extendHeld = false
	for key in pose do
		pose[key] = 0
		target[key] = 0
	end

	humanoid.WalkSpeed = CONFIG.WalkSpeed

	humanoid.Died:Connect(function()
		ready = false
		releaseWeb(false)
		speedBlur.Size = 0
	end)

	ready = true
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	task.spawn(setupCharacter, player.Character)
end
