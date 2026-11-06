--[[
  GuiMaker v1.0  -  Constructor de GUI para Roblox (LocalScript / ejecutor Delta)
  - Dex (explorer) y Propiedades separados, arrastrables y redimensionables
  - Elementos seleccionables en pantalla: arrastra para mover, vertices para redimensionar
  - Color picker, todas las propiedades editables, deshacer / rehacer
  - Guardados (writefile/readfile de Delta): guardar, actualizar, renombrar, eliminar
  - Exportar codigo (copiar / archivo / probar)
  - Ajustes: tema oscuro/claro, transparencia del maker (no afecta tu GUI), snap
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local HS = game:GetService("HttpService")
local LP = Players.LocalPlayer
local FONT, FONTB = Enum.Font.GothamMedium, Enum.Font.GothamBold
local LEFT = Enum.TextXAlignment.Left
local FOLDER = "GuiMaker"

local function VPsize()
	local c = workspace.CurrentCamera
	local v = c and c.ViewportSize or Vector2.new(800, 400)
	return Vector2.new(v.X, v.Y - 36)
end

---------------------------------------------------------------- host / guis
local function getHost()
	if gethui then
		local ok, h = pcall(gethui)
		if ok and typeof(h) == "Instance" then return h end
	end
	local ok = pcall(function() return #game:GetService("CoreGui"):GetChildren() end)
	if ok then return game:GetService("CoreGui") end
	return LP:WaitForChild("PlayerGui")
end
local HOST = getHost()
for _, c in ipairs(HOST:GetChildren()) do
	if c:GetAttribute("GuiMaker") then c:Destroy() end
end
local function mkGui(name, order)
	local g = Instance.new("ScreenGui")
	g.Name = name; g.ResetOnSpawn = false; g.IgnoreGuiInset = false
	g.DisplayOrder = order; g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g:SetAttribute("GuiMaker", true)
	g.Parent = HOST
	return g
end
local root = mkGui("ScreenGui", 500)   -- lienzo (tu GUI)
local UI = mkGui("GuiMaker_UI", 1000)  -- herramientas del maker
local conns = {}

---------------------------------------------------------------- estado / tema
local S = { theme = "dark", alpha = 0.1, snap = 0, preview = false, target = "executor" }
local THEMES = {
	dark = { bg = Color3.fromRGB(24, 24, 28), bg2 = Color3.fromRGB(40, 40, 46), bg3 = Color3.fromRGB(62, 62, 72),
		text = Color3.fromRGB(235, 235, 240), sub = Color3.fromRGB(165, 165, 175), acc = Color3.fromRGB(0, 200, 170) },
	light = { bg = Color3.fromRGB(244, 244, 248), bg2 = Color3.fromRGB(224, 224, 230), bg3 = Color3.fromRGB(200, 200, 210),
		text = Color3.fromRGB(20, 20, 24), sub = Color3.fromRGB(90, 90, 100), acc = Color3.fromRGB(0, 150, 125) },
}
local function col(k) return THEMES[S.theme][k] end
local themed, BUILDING = {}, true

local function ui(class, props, parent, bg, tx)
	local o = Instance.new(class)
	props = props or {}
	local fixed = props.BackgroundTransparency
	if bg then
		props.BackgroundColor3 = col(bg)
		if fixed == nil then props.BackgroundTransparency = S.alpha end
	end
	if tx then props.TextColor3 = col(tx) end
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		o.Font = FONT
		if props.TextSize == nil then o.TextSize = 12 end
	end
	if props.BorderSizePixel == nil and (class == "Frame" or class == "TextButton" or class == "TextBox"
		or class == "ScrollingFrame" or class == "TextLabel") then
		o.BorderSizePixel = 0
	end
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	if BUILDING and (bg or tx) then themed[#themed + 1] = { o, bg, tx, fixed } end
	return o
end
local function corner(o, r) ui("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end
local function btn(parent, text, pos, size, cb, bg)
	local b = ui("TextButton", { Text = text, Position = pos, Size = size, AutoButtonColor = true }, parent, bg or "bg3", "text")
	corner(b, 5)
	if cb then b.Activated:Connect(cb) end
	return b
end
local function box(parent, pos, size, text)
	local b = ui("TextBox", { Text = text or "", Position = pos, Size = size, ClearTextOnFocus = false }, parent, "bg2", "text")
	corner(b, 4)
	return b
end
local function fmt(x) return tostring(math.floor(x * 1000 + 0.5) / 1000) end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function startDrag(input, onMove, onEnd)
	local sp = input.Position
	local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
	local c1, c2
	c1 = UIS.InputChanged:Connect(function(i)
		if i == input or (isMouse and i.UserInputType == Enum.UserInputType.MouseMovement) then
			onMove(Vector2.new(i.Position.X, i.Position.Y), Vector2.new(i.Position.X - sp.X, i.Position.Y - sp.Y))
		end
	end)
	c2 = UIS.InputEnded:Connect(function(i)
		if i == input or (isMouse and i.UserInputType == Enum.UserInputType.MouseButton1) then
			c1:Disconnect(); c2:Disconnect()
			if onEnd then onEnd() end
		end
	end)
end

---------------------------------------------------------------- toast / dropdown
local toastL = ui("TextLabel", { BackgroundTransparency = 0.15, BackgroundColor3 = Color3.fromRGB(20, 20, 24),
	TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Visible = false, ZIndex = 100000, TextSize = 13, Text = "" }, UI)
corner(toastL, 8)
ui("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, toastL)
local sel = root
local refreshDex, refreshProps, refreshSaves, selectObj, openPicker, openScript
local function toast(msg)
	toastL.Text = msg; toastL.Visible = true
	local id = (toastL:GetAttribute("id") or 0) + 1
	toastL:SetAttribute("id", id)
	task.delay(2.2, function()
		if toastL.Parent and toastL:GetAttribute("id") == id then toastL.Visible = false end
	end)
end

local ddCatcher, ddList
local function closeDropdown()
	if ddCatcher then ddCatcher:Destroy(); ddCatcher = nil end
	if ddList then ddList:Destroy(); ddList = nil end
end
local function openDropdown(anchor, names, cur, onPick)
	closeDropdown()
	local vp = VPsize()
	ddCatcher = ui("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 99998 }, UI)
	ddCatcher.Activated:Connect(closeDropdown)
	local h = math.min(#names * 26 + 6, 210)
	local pos, sz = anchor.AbsolutePosition, anchor.AbsoluteSize
	local y = pos.Y + sz.Y
	if y + h > vp.Y then y = math.max(0, pos.Y - h) end
	local x = math.clamp(pos.X, 0, math.max(0, vp.X - math.max(sz.X, 140)))
	ddList = ui("ScrollingFrame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(math.max(sz.X, 140), h),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ZIndex = 99999,
		ScrollingDirection = Enum.ScrollingDirection.Y }, UI, "bg", nil)
	ddList.BackgroundTransparency = 0
	corner(ddList, 6)
	ui("UIStroke", { Color = Color3.fromRGB(120, 120, 130) }, ddList)
	ui("UIListLayout", { Padding = UDim.new(0, 2) }, ddList)
	ui("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, ddList)
	for _, n in ipairs(names) do
		local b = ui("TextButton", { Text = n, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = LEFT,
			BackgroundColor3 = n == cur and col("acc") or col("bg2"), TextColor3 = col("text") }, ddList)
		corner(b, 4)
		b.Activated:Connect(function() closeDropdown(); onPick(n) end)
	end
end

---------------------------------------------------------------- propiedades
local function L(s)
	local t = {}
	for n, ty in s:gmatch("(%w+):([%w%.]+)") do t[#t + 1] = { n = n, t = ty } end
	return t
end
local G = {
	Name = L "Name:s",
	Abs = L "AbsolutePosition:ro AbsoluteSize:ro",
	GuiObject = L "Position:u2 Size:u2 AnchorPoint:v2 Rotation:n BackgroundColor3:c BackgroundTransparency:n BorderColor3:c BorderSizePixel:n Visible:b ZIndex:n LayoutOrder:n ClipsDescendants:b Active:b AutomaticSize:e.AutomaticSize SizeConstraint:e.SizeConstraint",
	Text = L "Text:s TextColor3:c TextSize:n TextTransparency:n TextStrokeColor3:c TextStrokeTransparency:n Font:e.Font TextXAlignment:e.TextXAlignment TextYAlignment:e.TextYAlignment TextWrapped:b TextScaled:b RichText:b LineHeight:n TextTruncate:e.TextTruncate",
	Btn = L "AutoButtonColor:b Modal:b Selectable:b",
	TextBox = L "PlaceholderText:s PlaceholderColor3:c ClearTextOnFocus:b MultiLine:b TextEditable:b",
	Image = L "Image:s ImageColor3:c ImageTransparency:n ScaleType:e.ScaleType ResampleMode:e.ResamplerMode SliceCenter:rect SliceScale:n TileSize:u2 ImageRectOffset:v2 ImageRectSize:v2",
	ImgBtn = L "HoverImage:s PressedImage:s",
	Scroll = L "CanvasSize:u2 CanvasPosition:v2 ScrollBarThickness:n ScrollBarImageColor3:c ScrollBarImageTransparency:n ScrollingDirection:e.ScrollingDirection AutomaticCanvasSize:e.AutomaticSize ScrollingEnabled:b ElasticBehavior:e.ElasticBehavior",
	CanvasG = L "GroupTransparency:n GroupColor3:c",
	UICorner = L "CornerRadius:ud",
	UIStroke = L "Color:c Thickness:n Transparency:n ApplyStrokeMode:e.ApplyStrokeMode LineJoinMode:e.LineJoinMode Enabled:b",
	UIGradient = L "ColorA:c ColorB:c TransparencyAll:n Rotation:n Offset:v2 Enabled:b",
	UIListLayout = L "FillDirection:e.FillDirection HorizontalAlignment:e.HorizontalAlignment VerticalAlignment:e.VerticalAlignment SortOrder:e.SortOrder Padding:ud Wraps:b",
	UIGridLayout = L "CellPadding:u2 CellSize:u2 FillDirection:e.FillDirection FillDirectionMaxCells:n HorizontalAlignment:e.HorizontalAlignment VerticalAlignment:e.VerticalAlignment SortOrder:e.SortOrder StartCorner:e.StartCorner",
	UIPadding = L "PaddingTop:ud PaddingBottom:ud PaddingLeft:ud PaddingRight:ud",
	UIScale = L "Scale:n",
	UIAspect = L "AspectRatio:n AspectType:e.AspectType DominantAxis:e.DominantAxis",
	UISize = L "MinSize:v2 MaxSize:v2",
	UITextSize = L "MinTextSize:n MaxTextSize:n",
	Root = L "ResetOnSpawn:b ZIndexBehavior:e.ZIndexBehavior",
	Script = L "Source:code",
}
local CLASS = {
	ScreenGui = { "Name", "Root" },
	Frame = { "Name", "Abs", "GuiObject" },
	ScrollingFrame = { "Name", "Abs", "GuiObject", "Scroll" },
	CanvasGroup = { "Name", "Abs", "GuiObject", "CanvasG" },
	TextLabel = { "Name", "Abs", "GuiObject", "Text" },
	TextButton = { "Name", "Abs", "GuiObject", "Text", "Btn" },
	TextBox = { "Name", "Abs", "GuiObject", "Text", "TextBox" },
	ImageLabel = { "Name", "Abs", "GuiObject", "Image" },
	ImageButton = { "Name", "Abs", "GuiObject", "Image", "Btn", "ImgBtn" },
	UICorner = { "Name", "UICorner" }, UIStroke = { "Name", "UIStroke" }, UIGradient = { "Name", "UIGradient" },
	UIListLayout = { "Name", "UIListLayout" }, UIGridLayout = { "Name", "UIGridLayout" },
	UIPadding = { "Name", "UIPadding" }, UIScale = { "Name", "UIScale" },
	UIAspectRatioConstraint = { "Name", "UIAspect" }, UISizeConstraint = { "Name", "UISize" },
	UITextSizeConstraint = { "Name", "UITextSize" },
	LocalScript = { "Name", "Script" }, ModuleScript = { "Name", "Script" },
}
local ICON = { ScreenGui = "SG", Frame = "Fr", ScrollingFrame = "Sc", CanvasGroup = "CG", TextLabel = "T", TextButton = "Tb",
	TextBox = "Tx", ImageLabel = "Im", ImageButton = "Ib", UICorner = "Co", UIStroke = "St", UIGradient = "Gr",
	UIListLayout = "Li", UIGridLayout = "Gd", UIPadding = "Pd", UIScale = "Sl", UIAspectRatioConstraint = "Ar",
	UISizeConstraint = "Sz", UITextSizeConstraint = "Tz", LocalScript = "LS", ModuleScript = "MS" }

local function propsOf(obj)
	local out = {}
	for _, g in ipairs(CLASS[obj.ClassName] or { "Name" }) do
		for _, p in ipairs(G[g]) do out[#out + 1] = p end
	end
	return out
end
local SP = {
	ColorA = { get = function(o) return o.Color.Keypoints[1].Value end,
		set = function(o, v) local k = o.Color.Keypoints; o.Color = ColorSequence.new(v, k[#k].Value) end },
	ColorB = { get = function(o) local k = o.Color.Keypoints; return k[#k].Value end,
		set = function(o, v) o.Color = ColorSequence.new(o.Color.Keypoints[1].Value, v) end },
	TransparencyAll = { get = function(o) return o.Transparency.Keypoints[1].Value end,
		set = function(o, v) o.Transparency = NumberSequence.new(math.clamp(v, 0, 1)) end },
	Source = { get = function(o) return o:GetAttribute("GM_Source") or "" end,
		set = function(o, v) o:SetAttribute("GM_Source", v) end },
}
local function getP(o, n)
	local sp = SP[n]
	if sp then return sp.get(o) end
	return o[n]
end
local function setP(o, n, v)
	local sp = SP[n]
	return pcall(function() if sp then sp.set(o, v) else o[n] = v end end)
end
local CODEC = {
	u2 = { n = 4, lb = { "Xs", "Xo", "Ys", "Yo" }, get = function(v) return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset } end,
		set = function(f) return UDim2.new(f[1], f[2], f[3], f[4]) end },
	ud = { n = 2, lb = { "Scale", "Offset" }, get = function(v) return { v.Scale, v.Offset } end,
		set = function(f) return UDim.new(f[1], f[2]) end },
	v2 = { n = 2, lb = { "X", "Y" }, get = function(v) return { v.X, v.Y } end, set = function(f) return Vector2.new(f[1], f[2]) end },
	rect = { n = 4, lb = { "x1", "y1", "x2", "y2" }, get = function(v) return { v.Min.X, v.Min.Y, v.Max.X, v.Max.Y } end,
		set = function(f) return Rect.new(f[1], f[2], f[3], f[4]) end },
}

---------------------------------------------------------------- deshacer / rehacer
local U, Rd = {}, {}
local function afterChange()
	if sel ~= root and not sel:IsDescendantOf(root) then sel = root end
	refreshDex(); refreshProps()
end
local function push(c) U[#U + 1] = c; Rd = {}; if #U > 150 then table.remove(U, 1) end end
local function undo()
	local c = table.remove(U)
	if not c then toast("Nada que deshacer") return end
	c.undo(); Rd[#Rd + 1] = c; afterChange()
end
local function redo()
	local c = table.remove(Rd)
	if not c then toast("Nada que rehacer") return end
	c.redo(); U[#U + 1] = c; afterChange()
end
local function setProp(o, n, v)
	local ok, old = pcall(getP, o, n)
	if ok and old == v then refreshProps() return end
	if not setP(o, n, v) then toast("Valor no valido para " .. n); refreshProps() return end
	local _, now = pcall(getP, o, n)
	if ok then push({ undo = function() setP(o, n, old) end, redo = function() setP(o, n, now) end }) end
	refreshProps()
end

---------------------------------------------------------------- operaciones
local MODS = { UICorner = 1, UIStroke = 1, UIGradient = 1, UIListLayout = 1, UIGridLayout = 1, UIPadding = 1, UIScale = 1,
	UIAspectRatioConstraint = 1, UISizeConstraint = 1, UITextSizeConstraint = 1 }
local function parentFor(isMod)
	local p = sel or root
	while p ~= root and not p:IsA("GuiObject") do p = p.Parent end
	if isMod and p == root then return nil end
	return p
end
local function insert(o, par)
	o.Parent = par
	push({ undo = function() o.Parent = nil end, redo = function() o.Parent = par end })
	selectObj(o)
end
local function addObject(class)
	local par = parentFor(MODS[class])
	if not par then toast("Selecciona un elemento para aplicar el modificador") return end
	local o = Instance.new(class)
	local n = #root:GetDescendants()
	if o:IsA("GuiObject") then
		o.Position = UDim2.fromOffset(60 + (n % 8) * 16, 70 + (n % 8) * 16)
		o.Size = UDim2.fromOffset(150, 50); o.BorderSizePixel = 0
		o.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
	end
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
		o.Font = Enum.Font.GothamMedium; o.TextSize = 16; o.TextColor3 = Color3.new(1, 1, 1)
		o.Text = o:IsA("TextBox") and "" or (o:IsA("TextButton") and "Button" or "Label")
		if o:IsA("TextBox") then o.PlaceholderText = "TextBox" end
	end
	if o:IsA("ImageLabel") or o:IsA("ImageButton") then o.Size = UDim2.fromOffset(100, 100) end
	if o:IsA("ScrollingFrame") then
		o.Size = UDim2.fromOffset(200, 150); o.CanvasSize = UDim2.new(0, 0, 0, 300); o.ScrollBarThickness = 6
	end
	if o:IsA("LocalScript") then
		pcall(function() o.Enabled = false end)
		o:SetAttribute("GM_Source", "-- LocalScript\nlocal gui = script.Parent\n")
	elseif o:IsA("ModuleScript") then
		o:SetAttribute("GM_Source", "local module = {}\n\nreturn module\n")
	end
	insert(o, par)
end
local clip
local function deleteSel()
	local o = sel
	if o == root then toast("No se puede eliminar el ScreenGui") return end
	local par = o.Parent
	o.Parent = nil
	push({ undo = function() o.Parent = par end, redo = function() o.Parent = nil end })
	selectObj(par)
end
local function dupSel()
	if sel == root then return end
	local c = sel:Clone()
	if c:IsA("GuiObject") then c.Position = c.Position + UDim2.fromOffset(12, 12) end
	insert(c, sel.Parent)
end
local function copySel()
	if sel == root then return end
	clip = sel:Clone(); toast("Copiado: " .. sel.Name)
end
local function pasteSel()
	if not clip then toast("Portapapeles vacio") return end
	local par = parentFor(MODS[clip.ClassName])
	if not par then toast("Selecciona un elemento destino") return end
	insert(clip:Clone(), par)
end

---------------------------------------------------------------- ventanas
local WIN, topZ = {}, 10
local function front(f) topZ += 1; f.ZIndex = topZ end
local function mkWindow(key, title, x, y, w, h)
	local f = ui("Frame", { Name = key, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Active = true,
		Visible = false, ZIndex = topZ }, UI, "bg")
	corner(f, 8)
	ui("UIStroke", { Color = Color3.fromRGB(120, 120, 130), Transparency = 0.5 }, f)
	local bar = ui("Frame", { Size = UDim2.new(1, 0, 0, 28) }, f, "bg2")
	corner(bar, 8)
	local ttl = ui("TextLabel", { Text = title, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -44, 1, 0), TextXAlignment = LEFT, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd }, bar, nil, "text")
	ttl.Font = FONTB
	local win = { f = f, title = ttl, key = key }
	win.body = ui("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28),
		ClipsDescendants = true }, f)
	win.show = function() f.Visible = true; front(f) end
	win.hide = function() f.Visible = false; if win.onHide then win.onHide() end end
	win.toggle = function() if f.Visible then win.hide() else win.show() end end
	btn(bar, "X", UDim2.new(1, -28, 0, 2), UDim2.fromOffset(24, 24), win.hide)
	local function clampPos(px, py, wd)
		local V = VPsize()
		return math.clamp(px, -wd + 70, V.X - 70), math.clamp(py, 0, V.Y - 30)
	end
	bar.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		front(f)
		local sp, wd = f.Position, f.AbsoluteSize.X
		startDrag(input, function(_, d)
			local px, py = clampPos(sp.X.Offset + d.X, sp.Y.Offset + d.Y, wd)
			f.Position = UDim2.fromOffset(px, py)
		end)
	end)
	f.InputBegan:Connect(function(input) if isPress(input) then front(f) end end)
	local grip = ui("TextLabel", { Text = "◢", Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = true, TextSize = 14 }, f, nil, "sub")
	grip.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		local sz = f.AbsoluteSize
		startDrag(input, function(_, d)
			f.Size = UDim2.fromOffset(math.max(170, sz.X + d.X), math.max(110, sz.Y + d.Y))
		end)
	end)
	WIN[key] = win
	return win
end

local VP = VPsize()
local dexW = mkWindow("dex", "Dex (Explorer)", 8, 44, 235, math.min(290, VP.Y - 60))
local propW = mkWindow("props", "Propiedades", math.max(8, VP.X - 308), 44, 300, math.min(300, VP.Y - 60))
local addW = mkWindow("add", "Anadir", 252, 44, 200, math.min(280, VP.Y - 60))
local saveW = mkWindow("saves", "Guardados", 120, 60, 290, math.min(280, VP.Y - 70))
local expW = mkWindow("export", "Exportar codigo", 140, 50, 330, math.min(300, VP.Y - 60))
local setW = mkWindow("settings", "Ajustes", 160, 56, 270, math.min(290, VP.Y - 60))
local pickW = mkWindow("color", "Color", 200, 60, 224, 256)
local scriptW = mkWindow("script", "Editor de script", 90, 50, 390, math.min(290, VP.Y - 60))

---------------------------------------------------------------- DEX
local collapsed = {}
local dexList = ui("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -42),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y }, dexW.body)
ui("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }, dexList)
local dexBar = ui("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -4),
	Size = UDim2.new(1, -8, 0, 30) }, dexW.body)
do
	local acts = { { "Del", deleteSel }, { "Dup", dupSel }, { "Copy", copySel }, { "Paste", pasteSel }, { "Undo", undo }, { "Redo", redo } }
	for i, a in ipairs(acts) do
		btn(dexBar, a[1], UDim2.new((i - 1) / #acts, 1, 0, 0), UDim2.new(1 / #acts, -2, 1, 0), a[2])
	end
end
function refreshDex()
	for _, c in ipairs(dexList:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	if sel ~= root and not sel:IsDescendantOf(root) then sel = root end
	local order = 0
	local function walk(o, d)
		order += 1
		local isSel = (o == sel)
		local r = ui("Frame", { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = order, BackgroundColor3 = col("acc"),
			BackgroundTransparency = isSel and 0.55 or 1 }, dexList)
		local kids = o:GetChildren()
		local x = d * 14
		if #kids > 0 then
			local a = ui("TextButton", { Text = collapsed[o] and ">" or "v", BackgroundTransparency = 1,
				Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(20, 26), TextColor3 = col("sub") }, r)
			a.Activated:Connect(function() collapsed[o] = not collapsed[o] or nil; refreshDex() end)
		end
		local ic = ui("TextLabel", { Text = ICON[o.ClassName] or "?", Position = UDim2.fromOffset(x + 20, 3),
			Size = UDim2.fromOffset(22, 20), TextSize = 10, TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = (o == root or o:IsA("GuiObject")) and Color3.fromRGB(60, 120, 220) or (o:IsA("LuaSourceContainer") and Color3.fromRGB(50, 160, 85) or Color3.fromRGB(150, 90, 210)) }, r)
		ic.Font = FONTB; corner(ic, 4)
		local plus = (o == root or o:IsA("GuiObject"))
		local nb = ui("TextButton", { Text = o.Name, BackgroundTransparency = 1, Position = UDim2.fromOffset(x + 46, 0),
			Size = UDim2.new(1, -(x + 46 + (plus and 30 or 4)), 1, 0), TextXAlignment = LEFT, TextSize = 13,
			TextColor3 = col("text"), TextTruncate = Enum.TextTruncate.AtEnd }, r)
		nb.Activated:Connect(function() selectObj(o) end)
		if plus then
			local pb = ui("TextButton", { Text = "+", Position = UDim2.new(1, -28, 0, 2), Size = UDim2.fromOffset(24, 22),
				TextSize = 16, BackgroundColor3 = col("bg3"), TextColor3 = col("text") }, r)
			corner(pb, 5)
			pb.Activated:Connect(function() selectObj(o); addW.show() end)
		end
		if not collapsed[o] then
			for _, k in ipairs(kids) do walk(k, d + 1) end
		end
	end
	walk(root, 0)
end

---------------------------------------------------------------- AÑADIR
local ADD = { "#Elementos", "Frame", "ScrollingFrame", "CanvasGroup", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton",
	"#Modificadores UI", "UICorner", "UIStroke", "UIGradient", "UIListLayout", "UIGridLayout", "UIPadding", "UIScale",
	"UIAspectRatioConstraint", "UISizeConstraint", "UITextSizeConstraint", "#Scripts", "LocalScript", "ModuleScript" }
local addList = ui("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y }, addW.body)
ui("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, addList)
for i, n in ipairs(ADD) do
	if n:sub(1, 1) == "#" then
		local h = ui("TextLabel", { Text = n:sub(2), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = LEFT,
			LayoutOrder = i }, addList, nil, "acc")
		h.Font = FONTB
	else
		local b = btn(addList, "  " .. n, UDim2.new(), UDim2.new(1, -4, 0, 28), function() addObject(n) end)
		b.LayoutOrder = i; b.TextXAlignment = LEFT
	end
end

---------------------------------------------------------------- PROPIEDADES
local filter = ""
local search = box(propW.body, UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 26), "")
search.PlaceholderText = "buscar propiedad"
local propList = ui("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 34), Size = UDim2.new(1, -8, 1, -38),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y }, propW.body)
ui("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, propList)
search:GetPropertyChangedSignal("Text"):Connect(function() filter = search.Text:lower(); refreshProps() end)

local function hex(c) return string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)) end

local function buildRow(o, p, order)
	local ok, val = pcall(getP, o, p.n)
	if not ok or val == nil then return end
	local r = ui("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = order }, propList)
	ui("TextLabel", { Text = p.n, BackgroundTransparency = 1, Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromOffset(6, 0),
		TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 11, TextColor3 = col("sub") }, r)
	local ex = ui("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.4, 0, 0, 2), Size = UDim2.new(0.6, -6, 1, -4) }, r)
	local t = p.t
	local full = UDim2.fromScale(1, 1)
	local function mk(class, props) -- helper con tema
		props.BackgroundColor3 = col("bg2"); props.TextColor3 = col("text"); props.BackgroundTransparency = S.alpha
		props.Size = full
		local x = ui(class, props, ex); corner(x, 4); return x
	end
	if t == "s" or t == "n" then
		local b = mk("TextBox", { Text = t == "n" and fmt(val) or tostring(val), ClearTextOnFocus = false, TextSize = 12 })
		b.FocusLost:Connect(function()
			local v = b.Text
			if t == "n" then
				v = tonumber(v)
				if not v then refreshProps() return end
			elseif p.n:find("Image") and v:match("^%d+$") then
				v = "rbxassetid://" .. v
			end
			setProp(o, p.n, v)
		end)
	elseif t == "b" then
		local b = mk("TextButton", { Text = val and "ON" or "OFF", TextSize = 12 })
		if val then b.BackgroundColor3 = col("acc") end
		b.Activated:Connect(function() setProp(o, p.n, not getP(o, p.n)) end)
	elseif t == "c" then
		local lum = val.R * 0.3 + val.G * 0.59 + val.B * 0.11
		local b = mk("TextButton", { Text = hex(val), TextSize = 11 })
		b.BackgroundColor3 = val; b.BackgroundTransparency = 0
		b.TextColor3 = lum > 0.55 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
		b.Activated:Connect(function() openPicker(o, p.n) end)
	elseif t:sub(1, 2) == "e." then
		local en = t:sub(3)
		local b = mk("TextButton", { Text = val.Name .. "  v", TextSize = 12 })
		b.Activated:Connect(function()
			local names = {}
			local okE, items = pcall(function() return Enum[en]:GetEnumItems() end)
			if not okE then return end
			for _, it in ipairs(items) do names[#names + 1] = it.Name end
			openDropdown(b, names, val.Name, function(n) setProp(o, p.n, Enum[en][n]) end)
		end)
	elseif t == "code" then
		local _, nl = tostring(val):gsub("\n", "")
		local b = mk("TextButton", { Text = "Editar codigo (" .. (nl + 1) .. " lineas)", TextSize = 11 })
		b.BackgroundColor3 = col("acc")
		b.Activated:Connect(function() openScript(o) end)
	elseif t == "ro" then
		local txt = typeof(val) == "Vector2" and (fmt(val.X) .. ", " .. fmt(val.Y)) or fmt(val)
		ui("TextLabel", { Text = txt, BackgroundTransparency = 1, Size = full, TextXAlignment = LEFT, TextColor3 = col("text") }, ex)
	else
		local cd = CODEC[t]
		if not cd then return end
		local vals, boxes = cd.get(val), {}
		for i = 1, cd.n do
			local b = ui("TextBox", { Text = fmt(vals[i]), PlaceholderText = cd.lb[i], ClearTextOnFocus = false, TextSize = 11,
				Position = UDim2.new((i - 1) / cd.n, i > 1 and 1 or 0, 0, 0), Size = UDim2.new(1 / cd.n, -2, 1, 0),
				BackgroundColor3 = col("bg2"), TextColor3 = col("text"), BackgroundTransparency = S.alpha }, ex)
			corner(b, 4); boxes[i] = b
			b.FocusLost:Connect(function()
				local f = {}
				for k = 1, cd.n do
					f[k] = tonumber(boxes[k].Text)
					if not f[k] then refreshProps() return end
				end
				setProp(o, p.n, cd.set(f))
			end)
		end
	end
end
function refreshProps()
	local keep = propList.CanvasPosition
	for _, c in ipairs(propList:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	if sel ~= root and not sel:IsDescendantOf(root) then sel = root end
	propW.title.Text = "Propiedades - " .. sel.ClassName .. ' "' .. sel.Name .. '"'
	addW.title.Text = "Anadir a: " .. sel.Name
	local order = 0
	for _, p in ipairs(propsOf(sel)) do
		if filter == "" or p.n:lower():find(filter, 1, true) then
			order += 1; buildRow(sel, p, order)
		end
	end
	propList.CanvasPosition = keep
end

function selectObj(o)
	sel = o or root
	refreshDex(); refreshProps()
end

---------------------------------------------------------------- COLOR PICKER
do
	local body = pickW.body
	local ph, ps, pv = 0, 1, 1
	local target
	local sv = ui("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 110), Active = true,
		BackgroundColor3 = Color3.new(1, 0, 0) }, body)
	local wh = ui("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, sv)
	ui("UIGradient", { Transparency = NumberSequence.new(0, 1) }, wh)
	local bl = ui("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0) }, sv)
	ui("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, bl)
	local th = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1 }, sv)
	corner(th, 7); ui("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, th)
	local hue = ui("Frame", { Position = UDim2.fromOffset(10, 126), Size = UDim2.new(1, -20, 0, 18), Active = true,
		BackgroundColor3 = Color3.new(1, 1, 1) }, body)
	local kp = {}
	for i = 0, 6 do kp[#kp + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 == 1 and 0 or i / 6, 1, 1)) end
	ui("UIGradient", { Color = ColorSequence.new(kp) }, hue)
	local hth = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 24), BackgroundColor3 = Color3.new(1, 1, 1) }, hue)
	ui("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }, hth)
	local prev = ui("Frame", { Position = UDim2.fromOffset(10, 152), Size = UDim2.fromOffset(36, 28) }, body)
	corner(prev, 5)
	local hexB = box(body, UDim2.fromOffset(52, 152), UDim2.new(1, -62, 0, 28), "")
	local rgb = {}
	for i, n in ipairs({ "R", "G", "B" }) do
		rgb[i] = box(body, UDim2.new((i - 1) / 3, i == 1 and 10 or 3, 0, 188), UDim2.new(1 / 3, -9, 0, 28), "")
		rgb[i].PlaceholderText = n
	end
	local function cur() return Color3.fromHSV(ph, ps, pv) end
	local function sync()
		local c = cur()
		sv.BackgroundColor3 = Color3.fromHSV(ph, 1, 1)
		th.Position = UDim2.fromScale(ps, 1 - pv)
		hth.Position = UDim2.fromScale(ph, 0.5)
		prev.BackgroundColor3 = c
		hexB.Text = hex(c)
		rgb[1].Text = tostring(math.round(c.R * 255)); rgb[2].Text = tostring(math.round(c.G * 255)); rgb[3].Text = tostring(math.round(c.B * 255))
	end
	local function live()
		sync()
		if target and target.obj.Parent then setP(target.obj, target.prop, cur()) end
	end
	local function commit()
		if not target then return end
		local o, n = target.obj, target.prop
		local ok, now = pcall(getP, o, n)
		if ok and now ~= target.start then
			local old = target.start
			push({ undo = function() setP(o, n, old) end, redo = function() setP(o, n, now) end })
			target.start = now
		end
		refreshProps()
	end
	sv.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		local function upd(pos)
			ps = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			pv = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
			live()
		end
		upd(Vector2.new(input.Position.X, input.Position.Y))
		startDrag(input, function(p) upd(p) end, commit)
	end)
	hue.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		local function upd(pos)
			ph = math.clamp((pos.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 0.999)
			live()
		end
		upd(Vector2.new(input.Position.X, input.Position.Y))
		startDrag(input, function(p) upd(p) end, commit)
	end)
	hexB.FocusLost:Connect(function()
		local h = (hexB.Text:gsub("#", ""))
		if #h == 6 and tonumber(h, 16) then
			local n = tonumber(h, 16)
			ph, ps, pv = Color3.fromRGB(math.floor(n / 65536), math.floor(n / 256) % 256, n % 256):ToHSV()
			live(); commit()
		else sync() end
	end)
	for i = 1, 3 do
		rgb[i].FocusLost:Connect(function()
			local r, g, b = tonumber(rgb[1].Text), tonumber(rgb[2].Text), tonumber(rgb[3].Text)
			if r and g and b then
				ph, ps, pv = Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255)):ToHSV()
				live(); commit()
			else sync() end
		end)
	end
	pickW.onHide = function() commit(); target = nil end
	function openPicker(o, prop)
		local ok, c = pcall(getP, o, prop)
		if not ok or typeof(c) ~= "Color3" then return end
		if target then commit() end
		target = { obj = o, prop = prop, start = c }
		ph, ps, pv = c:ToHSV()
		sync(); pickW.title.Text = "Color - " .. prop; pickW.show()
	end
end

---------------------------------------------------------------- EDITOR DE SCRIPTS (LocalScript / ModuleScript)
do
	local b = scriptW.body
	local scroll = ui("ScrollingFrame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -42), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y }, b, "bg2")
	corner(scroll, 6)
	local ed = ui("TextBox", { BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 0), Size = UDim2.new(1, -6, 0, 200),
		AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, MultiLine = true, ClearTextOnFocus = false, TextXAlignment = LEFT,
		TextYAlignment = Enum.TextYAlignment.Top, TextSize = 12, Text = "" }, scroll, nil, "text")
	ed.Font = Enum.Font.Code
	local target
	local function compile()
		if not loadstring then return nil, "tu ejecutor no tiene loadstring" end
		return loadstring("local script = ... " .. ed.Text)
	end
	local function apply(silent)
		if target and target.Parent then
			setProp(target, "Source", ed.Text)
			if not silent then toast("Codigo aplicado a " .. target.Name) end
		elseif not silent then toast("El script ya no existe") end
	end
	local function sb(txt, idx, cb)
		return btn(b, txt, UDim2.new((idx - 1) / 4, 3, 1, -34), UDim2.new(0.25, -5, 0, 28), cb, idx == 1 and "acc" or nil)
	end
	sb("Aplicar", 1, function() apply(false) end)
	sb("Verificar", 2, function()
		local f, err = compile()
		toast(f and "Sintaxis OK" or ("Error: " .. tostring(err):sub(1, 90)))
	end)
	sb("Ejecutar", 3, function()
		if not target then return end
		local f, err = compile()
		if not f then toast("Error: " .. tostring(err):sub(1, 90)) return end
		local env = { Parent = target.Parent, Name = target.Name }
		if target:IsA("ModuleScript") then
			local ok, res = pcall(f, env)
			toast(ok and ("Modulo OK, devuelve: " .. typeof(res)) or ("Error: " .. tostring(res):sub(1, 90)))
		else
			task.spawn(function()
				local ok, e = pcall(f, env)
				if not ok then toast("Error: " .. tostring(e):sub(1, 90)) end
			end)
			toast("LocalScript ejecutado")
		end
	end)
	sb("Copiar", 4, function()
		local cp = setclipboard or toclipboard or (syn and syn.write_clipboard)
		if cp then pcall(cp, ed.Text); toast("Codigo copiado") else toast("Tu ejecutor no tiene portapapeles") end
	end)
	scriptW.onHide = function() apply(true) end
	function openScript(o)
		if target and target ~= o then apply(true) end
		target = o
		ed.Text = o:GetAttribute("GM_Source") or ""
		scriptW.title.Text = o.ClassName .. " - " .. o.Name
		scriptW.show()
	end
end

---------------------------------------------------------------- SELECCION / MOVER / REDIMENSIONAR
local function snap(v)
	if S.snap > 0 then return math.round(v / S.snap) * S.snap end
	return math.round(v)
end
local selFrame = ui("Frame", { BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, UI)
ui("UIStroke", { Color = Color3.fromRGB(255, 170, 0), Thickness = 2 }, selFrame)

local function beginResize(dx, dy, input)
	local o = sel
	if not (o and o ~= root and o:IsA("GuiObject")) then return end
	local sp, ss, ap, abs = o.Position, o.Size, o.AnchorPoint, o.AbsoluteSize
	local rot = math.rad(-o.Rotation)
	local changed = false
	startDrag(input, function(_, d)
		changed = true
		local x = d.X * math.cos(rot) - d.Y * math.sin(rot)
		local y = d.X * math.sin(rot) + d.Y * math.cos(rot)
		local gw = dx == 0 and 0 or snap(dx * x)
		local gh = dy == 0 and 0 or snap(dy * y)
		gw = math.max(gw, 6 - abs.X); gh = math.max(gh, 6 - abs.Y)
		local px = dx == 1 and ap.X * gw or (dx == -1 and -(1 - ap.X) * gw or 0)
		local py = dy == 1 and ap.Y * gh or (dy == -1 and -(1 - ap.Y) * gh or 0)
		o.Size = UDim2.new(ss.X.Scale, ss.X.Offset + gw, ss.Y.Scale, ss.Y.Offset + gh)
		o.Position = UDim2.new(sp.X.Scale, sp.X.Offset + px, sp.Y.Scale, sp.Y.Offset + py)
	end, function()
		if changed then
			local ns, np = o.Size, o.Position
			push({ undo = function() o.Size = ss; o.Position = sp end, redo = function() o.Size = ns; o.Position = np end })
			refreshProps()
		end
	end)
end
for dx = -1, 1 do
	for dy = -1, 1 do
		if dx ~= 0 or dy ~= 0 then
			local h = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((dx + 1) / 2, (dy + 1) / 2),
				Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.fromRGB(255, 170, 0), BackgroundTransparency = 0.3,
				Active = true, BorderSizePixel = 0 }, selFrame)
			corner(h, 11)
			h.InputBegan:Connect(function(input) if isPress(input) then beginResize(dx, dy, input) end end)
		end
	end
end
conns[#conns + 1] = RS.RenderStepped:Connect(function()
	if sel and sel ~= root and sel.Parent and sel:IsA("GuiObject") and sel:IsDescendantOf(root) and not S.preview then
		local p, s = sel.AbsolutePosition, sel.AbsoluteSize
		selFrame.Visible = true
		selFrame.Position = UDim2.fromOffset(p.X, p.Y)
		selFrame.Size = UDim2.fromOffset(s.X, s.Y)
		selFrame.Rotation = sel.Rotation
	else
		selFrame.Visible = false
	end
end)

local function beginMove(o, input)
	local sp = o.Position
	local moved = false
	startDrag(input, function(_, d)
		if not moved and d.Magnitude < 5 then return end
		moved = true
		o.Position = UDim2.new(sp.X.Scale, sp.X.Offset + snap(d.X), sp.Y.Scale, sp.Y.Offset + snap(d.Y))
	end, function()
		if moved then
			local np = o.Position
			push({ undo = function() o.Position = sp end, redo = function() o.Position = np end })
			refreshProps()
		end
	end)
end

local function depth(o)
	local d = 0
	while o and o ~= root do d += 1; o = o.Parent end
	return d
end
local hooked, pend, pendIn = {}, {}, nil
local lastTap = { o = nil, t = 0 }
local function resolvePick()
	local input = pendIn
	local best, bd, bz
	for _, o in ipairs(pend) do
		local d, z = depth(o), o.ZIndex
		if not best or d > bd or (d == bd and z >= bz) then best, bd, bz = o, d, z end
	end
	pend = {}
	if best and best:IsDescendantOf(root) then
		if sel == best then
			beginMove(best, input) -- ya seleccionado: arrastrar para mover
		else
			local now = os.clock()
			if lastTap.o == best and now - lastTap.t < 0.45 then -- doble toque: seleccionar
				lastTap.o = nil
				selectObj(best)
				beginMove(best, input)
			else
				lastTap.o, lastTap.t = best, now -- primer toque: solo lo marca
			end
		end
	end
end
local dirty = false
local function markDirty()
	if dirty then return end
	dirty = true
	task.defer(function() dirty = false; refreshDex(); refreshProps() end)
end
local function onAdded(o)
	if hooked[o] then return end
	hooked[o] = true
	o:GetPropertyChangedSignal("Name"):Connect(markDirty)
	if o:IsA("GuiObject") then
		o.InputBegan:Connect(function(input)
			if S.preview or not isPress(input) then return end
			if pendIn ~= input then
				pend = {}; pendIn = input
				task.defer(resolvePick)
			end
			pend[#pend + 1] = o
		end)
		if o:IsA("TextBox") then
			o.Focused:Connect(function() if not S.preview then o:ReleaseFocus() end end)
		end
	end
end
root.DescendantAdded:Connect(function(o) onAdded(o); markDirty() end)
root.DescendantRemoving:Connect(markDirty)
root:GetPropertyChangedSignal("Name"):Connect(markDirty)

---------------------------------------------------------------- GUARDADOS
local FS = { w = writefile, r = readfile, l = listfiles, d = delfile, mk = makefolder, isf = isfolder }
local MEM = {}
local hasFS = FS.w and FS.r and FS.l and FS.d
local function ensureFolder()
	if FS.mk and FS.isf then pcall(function() if not FS.isf(FOLDER) then FS.mk(FOLDER) end end) end
end
local function enc(v)
	local t = typeof(v)
	if t == "Color3" then return { t = "C3", v = { v.R, v.G, v.B } }
	elseif t == "UDim2" then return { t = "U2", v = { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset } }
	elseif t == "UDim" then return { t = "UD", v = { v.Scale, v.Offset } }
	elseif t == "Vector2" then return { t = "V2", v = { v.X, v.Y } }
	elseif t == "Rect" then return { t = "RC", v = { v.Min.X, v.Min.Y, v.Max.X, v.Max.Y } }
	elseif t == "EnumItem" then return { t = "E", e = tostring(v.EnumType), v = v.Name } end
	return v
end
local function dec(x)
	if type(x) ~= "table" then return x end
	local t, v = x.t, x.v
	if t == "C3" then return Color3.new(v[1], v[2], v[3])
	elseif t == "U2" then return UDim2.new(v[1], v[2], v[3], v[4])
	elseif t == "UD" then return UDim.new(v[1], v[2])
	elseif t == "V2" then return Vector2.new(v[1], v[2])
	elseif t == "RC" then return Rect.new(v[1], v[2], v[3], v[4])
	elseif t == "E" then
		local ok, r = pcall(function() return Enum[x.e][x.v] end)
		return ok and r or nil
	end
end
local function ser(o)
	local d = { c = o.ClassName, p = {}, ch = {} }
	for _, p in ipairs(propsOf(o)) do
		if p.t ~= "ro" then
			local ok, v = pcall(getP, o, p.n)
			if ok and v ~= nil then d.p[p.n] = enc(v) end
		end
	end
	for _, c in ipairs(o:GetChildren()) do d.ch[#d.ch + 1] = ser(c) end
	return d
end
local function build(d, parent)
	local ok, o = pcall(Instance.new, d.c)
	if not ok then return end
	for n, v in pairs(d.p or {}) do setP(o, n, dec(v)) end
	for _, c in ipairs(d.ch or {}) do build(c, o) end
	if o:IsA("LocalScript") then pcall(function() o.Enabled = false end) end
	o.Parent = parent
end
local function loadData(d)
	for _, c in ipairs(root:GetChildren()) do c:Destroy() end
	for n, v in pairs(d.p or {}) do setP(root, n, dec(v)) end
	for _, c in ipairs(d.ch or {}) do build(c, root) end
	U, Rd = {}, {}
	sel = root
	afterChange()
end
local function clean(n) return ((n or ""):gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function listSaves()
	local out = {}
	if hasFS then
		local ok, files = pcall(FS.l, FOLDER)
		if ok then
			for _, p in ipairs(files) do
				local n = tostring(p):match("([^/\\]+)%.json$")
				if n then out[#out + 1] = n end
			end
		end
	else
		for k in pairs(MEM) do out[#out + 1] = k end
	end
	table.sort(out)
	return out
end
local function readSave(n)
	local raw
	if hasFS then
		local ok, r = pcall(FS.r, FOLDER .. "/" .. n .. ".json")
		if not ok then return nil end
		raw = r
	else raw = MEM[n] end
	if not raw then return nil end
	local ok, d = pcall(function() return HS:JSONDecode(raw) end)
	return ok and d or nil
end
local function writeSave(n, raw)
	if hasFS then
		ensureFolder()
		return pcall(FS.w, FOLDER .. "/" .. n .. ".json", raw)
	end
	MEM[n] = raw
	return true
end
local function delSave(n)
	if hasFS then return pcall(FS.d, FOLDER .. "/" .. n .. ".json") end
	MEM[n] = nil
	return true
end

local nameBox = box(saveW.body, UDim2.fromOffset(4, 4), UDim2.new(1, -90, 0, 28), "")
nameBox.PlaceholderText = "nombre del guardado"
btn(saveW.body, "Guardar", UDim2.new(1, -82, 0, 4), UDim2.fromOffset(78, 28), function()
	local n = clean(nameBox.Text)
	if n == "" then toast("Escribe un nombre") return end
	local ok, res = pcall(function() return writeSave(n, HS:JSONEncode(ser(root))) end)
	if ok and res then toast((hasFS and "Guardado: " or "Guardado (solo memoria): ") .. n) else toast("Error al guardar") end
	refreshSaves()
end, "acc")
local saveList = ui("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 38), Size = UDim2.new(1, -8, 1, -42),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y }, saveW.body)
ui("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, saveList)
local confirmDel
function refreshSaves()
	for _, c in ipairs(saveList:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local list = listSaves()
	if #list == 0 then
		ui("TextLabel", { Text = hasFS and "No hay guardados todavia" or "Sin acceso a archivos: se guarda solo en memoria",
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), TextColor3 = col("sub"), TextWrapped = true }, saveList)
	end
	for i, n in ipairs(list) do
		local r = ui("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = col("bg2"), BackgroundTransparency = S.alpha, LayoutOrder = i }, saveList)
		corner(r, 5)
		local nb = ui("TextButton", { Text = n, BackgroundTransparency = 1, Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromOffset(4, 0),
			TextXAlignment = LEFT, TextColor3 = col("text"), TextTruncate = Enum.TextTruncate.AtEnd }, r)
		nb.Activated:Connect(function() nameBox.Text = n end)
		local function b(txt, idx, cb)
			local x = ui("TextButton", { Text = txt, Position = UDim2.new(0.4 + (idx - 1) * 0.2, 1, 0, 3), Size = UDim2.new(0.2, -3, 1, -6),
				BackgroundColor3 = col("bg3"), TextColor3 = col("text"), TextSize = 11 }, r)
			corner(x, 4); x.Activated:Connect(function() cb(x) end)
		end
		b("Cargar", 1, function()
			local d = readSave(n)
			if d then loadData(d); toast("Cargado: " .. n) else toast("No se pudo leer") end
		end)
		b("Renom.", 2, function()
			local nn = clean(nameBox.Text)
			if nn == "" or nn == n then toast("Escribe el nuevo nombre arriba") return end
			local d = readSave(n)
			if not d then toast("No se pudo leer") return end
			writeSave(nn, HS:JSONEncode(d)); delSave(n); toast("Renombrado a " .. nn); refreshSaves()
		end)
		b(confirmDel == n and "Seguro?" or "Borrar", 3, function()
			if confirmDel == n then
				delSave(n); confirmDel = nil; toast("Eliminado: " .. n)
			else confirmDel = n end
			refreshSaves()
		end)
	end
end
saveW.onHide = function() confirmDel = nil end

---------------------------------------------------------------- EXPORTAR
local function n4(x) return tostring(math.floor(x * 10000 + 0.5) / 10000) end
local function luaVal(v)
	local t = typeof(v)
	if t == "string" then return string.format("%q", v)
	elseif t == "number" then return n4(v)
	elseif t == "boolean" then return tostring(v)
	elseif t == "Color3" then return string.format("Color3.fromRGB(%d, %d, %d)", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	elseif t == "UDim2" then return string.format("UDim2.new(%s, %s, %s, %s)", n4(v.X.Scale), n4(v.X.Offset), n4(v.Y.Scale), n4(v.Y.Offset))
	elseif t == "UDim" then return string.format("UDim.new(%s, %s)", n4(v.Scale), n4(v.Offset))
	elseif t == "Vector2" then return string.format("Vector2.new(%s, %s)", n4(v.X), n4(v.Y))
	elseif t == "Rect" then return string.format("Rect.new(%s, %s, %s, %s)", n4(v.Min.X), n4(v.Min.Y), n4(v.Max.X), n4(v.Max.Y))
	elseif t == "EnumItem" then return tostring(v) end
	return "nil"
end
local hasScripts = false
local defs = {}
local function gen(o, pv, d, out)
	local ind = ("  "):rep(d)
	if o:IsA("LuaSourceContainer") then
		local code = o:GetAttribute("GM_Source") or ""
		if code:match("%S") then
			hasScripts = true
			local isMod = o:IsA("ModuleScript")
			out[#out + 1] = ind .. "do"
			out[#out + 1] = ind .. "  local script = {Parent = " .. pv .. ", Name = " .. luaVal(o.Name) .. "}"
			out[#out + 1] = ind .. "  " .. (isMod and ("__mods[#__mods + 1] = {" .. luaVal(o.Name) .. ", function()") or "__runs[#__runs + 1] = function()")
			out[#out + 1] = code
			out[#out + 1] = ind .. "  " .. (isMod and "end}" or "end")
			out[#out + 1] = ind .. "end"
		end
		return
	end
	local base = (o.Name:gsub("[^%w_]", "_"))
	if base == "" or base:match("^%d") then base = "_" .. base end
	local var = base .. "_" .. d
	out[#out + 1] = ind .. "do"
	out[#out + 1] = ind .. "  local " .. var .. " = Instance.new(\"" .. o.ClassName .. "\")"
	local def = defs[o.ClassName]
	if not def then def = Instance.new(o.ClassName); defs[o.ClassName] = def end
	out[#out + 1] = ind .. "  " .. var .. ".Name = " .. luaVal(o.Name)
	for _, p in ipairs(propsOf(o)) do
		if p.t ~= "ro" and p.n ~= "Name" and not SP[p.n] then
			local ok, v = pcall(getP, o, p.n)
			local ok2, dv = pcall(getP, def, p.n)
			if ok and ok2 and v ~= dv then out[#out + 1] = ind .. "  " .. var .. "." .. p.n .. " = " .. luaVal(v) end
		end
	end
	if o.ClassName == "UIGradient" then
		out[#out + 1] = ind .. "  " .. var .. ".Color = ColorSequence.new(" .. luaVal(getP(o, "ColorA")) .. ", " .. luaVal(getP(o, "ColorB")) .. ")"
		out[#out + 1] = ind .. "  " .. var .. ".Transparency = NumberSequence.new(" .. n4(getP(o, "TransparencyAll")) .. ")"
	end
	out[#out + 1] = ind .. "  " .. var .. ".Parent = " .. pv
	for _, c in ipairs(o:GetChildren()) do gen(c, var, d + 1, out) end
	out[#out + 1] = ind .. "end"
end
local function generate()
	local out = { "-- Generado con GuiMaker", "local gui = Instance.new(\"ScreenGui\")",
		"gui.Name = " .. luaVal(root.Name), "gui.ResetOnSpawn = " .. tostring(root.ResetOnSpawn),
		"gui.ZIndexBehavior = " .. tostring(root.ZIndexBehavior), "" }
	hasScripts = false
	for _, c in ipairs(root:GetChildren()) do gen(c, "gui", 0, out) end
	if hasScripts then
		local shim = { "local Modules, __mods, __runs = {}, {}, {}",
			"local __req = require",
			"local function require(m) if type(m) == \"string\" then return Modules[m] elseif type(m) == \"table\" then return m end return __req(m) end" }
		for i, l in ipairs(shim) do table.insert(out, 5 + i + 1, l) end
	end
	out[#out + 1] = ""
	if S.target == "executor" then
		out[#out + 1] = "gui.Parent = (gethui and gethui()) or game:GetService(\"CoreGui\")"
	else
		out[#out + 1] = "gui.Parent = game:GetService(\"Players\").LocalPlayer:WaitForChild(\"PlayerGui\")"
	end
	if hasScripts then
		out[#out + 1] = ""
		out[#out + 1] = "-- ModuleScripts: usa require(\"Nombre\") o Modules.Nombre"
		out[#out + 1] = "for _, m in ipairs(__mods) do Modules[m[1]] = m[2]() end"
		out[#out + 1] = "for _, f in ipairs(__runs) do task.spawn(f) end"
	end
	for _, d in pairs(defs) do d:Destroy() end
	defs = {}
	return table.concat(out, "\n")
end
local codeFull = ""
local expScroll = ui("ScrollingFrame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -76), CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y }, expW.body, "bg2")
corner(expScroll, 6)
local codeBox = ui("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	TextWrapped = true, MultiLine = true, ClearTextOnFocus = false, TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top,
	TextSize = 11, Text = "", Position = UDim2.fromOffset(3, 0) }, expScroll, nil, "text")
codeBox.Font = Enum.Font.Code
local function regen()
	local ok, code = pcall(generate)
	if not ok then toast("Error al generar: " .. tostring(code)) return end
	codeFull = code
	codeBox.Text = #code > 12000 and (code:sub(1, 12000) .. "\n-- ... (vista recortada; Copiar/Archivo exportan todo)") or code
end
local tgtBtn
local function eb(txt, idx, cb)
	return btn(expW.body, txt, UDim2.new((idx - 1) / 4, 3, 1, -66), UDim2.new(0.25, -5, 0, 28), cb)
end
eb("Generar", 1, regen)
eb("Copiar", 2, function()
	regen()
	local cp = setclipboard or toclipboard or (syn and syn.write_clipboard)
	if cp then pcall(cp, codeFull); toast("Codigo copiado") else toast("Tu ejecutor no tiene portapapeles") end
end)
eb("Archivo", 3, function()
	regen()
	if not (hasFS) then toast("Sin acceso a archivos") return end
	ensureFolder()
	local fn = FOLDER .. "/export_" .. (clean(root.Name) ~= "" and clean(root.Name) or "gui") .. ".lua"
	local ok = pcall(FS.w, fn, codeFull)
	toast(ok and ("Guardado en " .. fn) or "Error al escribir")
end)
eb("Probar", 4, function()
	regen()
	local f, err = loadstring and loadstring(codeFull)
	if not f then toast("No se pudo ejecutar: " .. tostring(err)) return end
	local ok, e = pcall(f)
	toast(ok and "GUI exportado ejecutado" or ("Error: " .. tostring(e)))
end)
tgtBtn = btn(expW.body, "", UDim2.new(0, 4, 1, -34), UDim2.new(1, -8, 0, 28), nil)
local function tgtText() tgtBtn.Text = "Destino: " .. (S.target == "executor" and "Ejecutor (gethui/CoreGui)" or "LocalScript (PlayerGui)") end
tgtBtn.Activated:Connect(function() S.target = S.target == "executor" and "local" or "executor"; tgtText(); regen() end)
tgtText()
expW.onShow = regen

---------------------------------------------------------------- AJUSTES
local function applyTheme(full)
	for _, e in ipairs(themed) do
		local o, bg, tx, fx = e[1], e[2], e[3], e[4]
		if bg then o.BackgroundColor3 = col(bg); o.BackgroundTransparency = fx or S.alpha end
		if tx then o.TextColor3 = col(tx) end
	end
	if full then refreshDex(); refreshProps(); refreshSaves() end
end
do
	local b = setW.body
	local function lbl(txt, y)
		ui("TextLabel", { Text = txt, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, 18),
			TextXAlignment = LEFT, TextSize = 12 }, b, nil, "sub")
	end
	lbl("Tema del maker", 6)
	btn(b, "Oscuro", UDim2.fromOffset(10, 26), UDim2.new(0.5, -14, 0, 28), function() S.theme = "dark"; applyTheme(true) end)
	btn(b, "Claro", UDim2.new(0.5, 4, 0, 26), UDim2.new(0.5, -14, 0, 28), function() S.theme = "light"; applyTheme(true) end)
	lbl("Transparencia del maker (Dex/Propiedades)", 64)
	local hit = ui("TextButton", { Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 86), Size = UDim2.new(1, -28, 0, 26) }, b)
	local bar = ui("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6),
		BackgroundTransparency = 0 }, hit, "bg3")
	corner(bar, 3)
	local knob = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 0,
		Position = UDim2.fromScale(S.alpha / 0.85, 0.5) }, hit, "acc")
	corner(knob, 9)
	local function setX(x, final)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		S.alpha = a * 0.85
		applyTheme(final)
	end
	hit.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		setX(input.Position.X, false)
		local last = input.Position.X
		startDrag(input, function(p) last = p.X; setX(p.X, false) end, function() setX(last, true) end)
	end)
	lbl("Snap al mover/redimensionar (px)", 122)
	local snapB
	snapB = btn(b, "Snap: " .. S.snap, UDim2.fromOffset(10, 142), UDim2.new(1, -20, 0, 28), function()
		local order = { [0] = 1, [1] = 5, [5] = 10, [10] = 0 }
		S.snap = order[S.snap] or 0
		snapB.Text = "Snap: " .. S.snap .. (S.snap == 0 and " (off)" or "")
	end)
	snapB.Text = "Snap: off"
	ui("TextLabel", { Text = "Los cambios de tema/transparencia solo afectan al maker, no a tu GUI ni al juego.",
		BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 178), Size = UDim2.new(1, -20, 0, 34), TextWrapped = true,
		TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 11 }, b, nil, "sub")
	local closeB
	local armed = false
	closeB = btn(b, "Cerrar GuiMaker", UDim2.fromOffset(10, 218), UDim2.new(1, -20, 0, 28), function()
		if not armed then
			armed = true; closeB.Text = "Seguro? (se pierde lo no guardado)"
			task.delay(3, function() armed = false; if closeB.Parent then closeB.Text = "Cerrar GuiMaker" end end)
			return
		end
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		UI:Destroy(); root:Destroy()
	end)
	closeB.BackgroundColor3 = Color3.fromRGB(190, 60, 60); closeB.TextColor3 = Color3.new(1, 1, 1)
	for i = #themed, 1, -1 do if themed[i][1] == closeB then table.remove(themed, i) end end
end

---------------------------------------------------------------- BARRA DE HERRAMIENTAS
local bar = ui("Frame", { Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X,
	Active = true, ZIndex = 5 }, UI, "bg")
corner(bar, 8)
ui("UIStroke", { Color = Color3.fromRGB(120, 120, 130), Transparency = 0.5 }, bar)
ui("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
	VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, bar)
ui("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, bar)
local grip = ui("TextLabel", { Text = "::", Size = UDim2.fromOffset(24, 26), BackgroundTransparency = 1, Active = true,
	TextSize = 16, LayoutOrder = 0 }, bar, nil, "sub")
grip.InputBegan:Connect(function(input)
	if not isPress(input) then return end
	local sp = bar.Position
	startDrag(input, function(_, d)
		local V = VPsize()
		bar.Position = UDim2.fromOffset(math.clamp(sp.X.Offset + d.X, 0, V.X - 60), math.clamp(sp.Y.Offset + d.Y, 0, V.Y - 40))
	end)
end)
local tbOrder = 1
local tbBtns, barCollapsed = {}, false
local toggleB
toggleB = btn(bar, "<", UDim2.new(), UDim2.fromOffset(28, 26), function()
	barCollapsed = not barCollapsed
	toggleB.Text = barCollapsed and ">" or "<"
	for _, x in ipairs(tbBtns) do x.Visible = not barCollapsed end
end)
toggleB.LayoutOrder = 1
local function tb(text, cb)
	tbOrder += 1
	local b = btn(bar, text, UDim2.new(), UDim2.fromOffset(#text > 5 and 62 or 52, 26), cb)
	b.LayoutOrder = tbOrder
	tbBtns[#tbBtns + 1] = b
	return b
end
tb("Dex", function() dexW.toggle() end)
tb("Props", function() propW.toggle() end)
tb("Anadir", function() addW.toggle() end)
tb("Guardar", function() refreshSaves(); saveW.toggle() end)
tb("Export", function() expW.toggle(); if expW.f.Visible then regen() end end)
tb("Ajustes", function() setW.toggle() end)
tb("Undo", undo)
tb("Redo", redo)
local playB
playB = tb("Probar", function()
	S.preview = not S.preview
	playB.Text = S.preview and "Editar" or "Probar"
	toast(S.preview and "Modo prueba: tu GUI responde como en el juego" or "Modo edicion")
end)
local hidden, vis = false, {}
tb("Ocultar", function()
	hidden = not hidden
	for k, w in pairs(WIN) do
		if hidden then vis[k] = w.f.Visible; w.f.Visible = false
		elseif vis[k] then w.f.Visible = true end
	end
end)

---------------------------------------------------------------- inicio
BUILDING = false
refreshDex(); refreshProps(); refreshSaves()
dexW.show(); propW.show()
toast("GuiMaker listo - toca '+' o 'Anadir' para crear elementos")
