--!strict
-- 暗い部屋＋机＋発光キーボード(英字26)をコードから生成する。
-- Godot版 world.gd の _build_keyboard / _make_key 相当をRoblox化したもの。
-- 生成物はクライアントローカル(各プレイヤー自分のワールド)。
--
-- build() は各文字のキー情報を返す:
--   pos[ch]   = キー上面中心のVector3(着地判定に使う)
--   part[ch]  = キーのPart(押し込みアニメ用)
--   label[ch] = 文字を描くTextLabel(色変更用)

local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Keyboard = {}

export type KeyInfo = {
	pos: { [string]: Vector3 },
	part: { [string]: BasePart },
	label: { [string]: TextLabel },
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
	homePos: Vector3,
}

-- 暗い部屋の雰囲気。ディスプレイ素材は無いので、ライティングだけで寄せる。
local function setupAtmosphere()
	Lighting.Ambient = Color3.fromRGB(12, 14, 22)
	Lighting.OutdoorAmbient = Color3.fromRGB(10, 12, 20)
	Lighting.Brightness = 0.6
	Lighting.ClockTime = 0 -- 夜
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(4, 6, 12)
	Lighting.FogStart = 60
	Lighting.FogEnd = 260

	-- 画面光に見立てたマゼンタ寄りの主光源(キーボード奥から手前へ照らす)
	local mainPart = Instance.new("Part")
	mainPart.Name = "ScreenLight"
	mainPart.Size = Vector3.one
	mainPart.Transparency = 1
	mainPart.Anchored = true
	mainPart.CanCollide = false
	mainPart.CanQuery = false
	mainPart.Position = Vector3.new(0, 40, -60)
	mainPart.Parent = workspace

	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Color = Color3.fromRGB(255, 150, 220)
	spot.Brightness = 4
	spot.Range = 200
	spot.Angle = 75
	spot.Shadows = true
	spot.Parent = mainPart

	-- 青紫の弱い補助光
	local fill = Instance.new("Part")
	fill.Name = "FillLight"
	fill.Size = Vector3.one
	fill.Transparency = 1
	fill.Anchored = true
	fill.CanCollide = false
	fill.CanQuery = false
	fill.Position = Vector3.new(0, 30, 40)
	fill.Parent = workspace

	local omni = Instance.new("PointLight")
	omni.Color = Color3.fromRGB(120, 110, 230)
	omni.Brightness = 1.2
	omni.Range = 120
	omni.Parent = fill
end

-- 机(一番下の台。ノートPCデッキの下に広がり、キーから外れて歩いても落下しない)
local function buildDesk(folder: Folder)
	local cfg = GameConfig
	local kbdWidth = 10 * cfg.Pitch
	local kbdDepth = #cfg.Rows * cfg.Pitch

	local desk = Instance.new("Part")
	desk.Name = "Desk"
	desk.Anchored = true
	desk.Size = Vector3.new(kbdWidth + 90, 4, kbdDepth + 90)
	-- 天面をデッキより少し下(DeskY-1)に。机→デッキ→キーの段差を作る。
	desk.Position = Vector3.new(0, cfg.DeskY - 1 - 2, -kbdDepth / 2 + cfg.Pitch / 2)
	desk.Color = Color3.fromRGB(8, 8, 11)
	desk.Material = Enum.Material.Wood
	desk.TopSurface = Enum.SurfaceType.Smooth
	desk.Parent = folder
end

-- ノートPC: キーボードの土台(デッキ)と、奥に立つ発光ディスプレイ。
-- 画像素材は無いのでディスプレイはNeonの面で「光る四角」として表現する。
local function buildLaptop(folder: Folder)
	local cfg = GameConfig
	local kbdWidth = 10 * cfg.Pitch
	local rowsN = #cfg.Rows
	-- キーは x≈±kbdWidth/2、z: 0 .. -(rowsN-1)*pitch を占める
	local centerZ = -((rowsN - 1) * cfg.Pitch) / 2
	local deckThick = 1.5

	-- デッキ(キーボードの土台。天面=DeskY、キーはこの上に乗る)
	local deck = Instance.new("Part")
	deck.Name = "LaptopDeck"
	deck.Anchored = true
	deck.Size = Vector3.new(kbdWidth + 8, deckThick, rowsN * cfg.Pitch + 10)
	deck.Position = Vector3.new(0, cfg.DeskY - deckThick / 2, centerZ)
	deck.Color = Color3.fromRGB(26, 26, 34)
	deck.Material = Enum.Material.Metal
	deck.TopSurface = Enum.SurfaceType.Smooth
	deck.Parent = folder

	-- ヒンジ(デッキ奥端)。画面はここから上へ、やや後ろへ倒して立てる。
	local backZ = centerZ - (rowsN * cfg.Pitch + 10) / 2
	local hinge = CFrame.new(0, cfg.DeskY, backZ) * CFrame.Angles(math.rad(-12), 0, 0)

	local screenH = 36
	local screenW = screenH * 16 / 9

	-- 画面の裏ガワ(暗い板)
	local back = Instance.new("Part")
	back.Name = "DisplayBack"
	back.Anchored = true
	back.Size = Vector3.new(screenW + 3, screenH + 3, 1.5)
	back.CFrame = hinge * CFrame.new(0, screenH / 2 + 1, -0.9)
	back.Color = Color3.fromRGB(18, 18, 24)
	back.Material = Enum.Material.Metal
	back.Parent = folder

	-- 発光ディスプレイ(光る四角)
	local screen = Instance.new("Part")
	screen.Name = "DisplayScreen"
	screen.Anchored = true
	screen.CanCollide = false
	screen.Size = Vector3.new(screenW, screenH, 0.4)
	screen.CFrame = hinge * CFrame.new(0, screenH / 2 + 1, 0)
	screen.Color = Color3.fromRGB(140, 160, 235)
	screen.Material = Enum.Material.Neon
	screen.Parent = folder

	-- 画面からキーボードへ降りる光(雰囲気の主光源)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(180, 170, 255)
	light.Brightness = 2.5
	light.Range = 90
	light.Parent = screen
end

local function makeKey(folder: Folder, ch: string, base: Vector3, info: KeyInfo)
	local cfg = GameConfig

	local key = Instance.new("Part")
	key.Name = "Key_" .. ch
	key.Anchored = true
	key.Size = Vector3.new(cfg.KeycapTop, cfg.KeycapHeight, cfg.KeycapTop)
	-- base はキーが乗る床面(y=DeskY)。中心は半分上。
	key.Position = base + Vector3.new(0, cfg.KeycapHeight / 2, 0)
	key.Color = Color3.fromRGB(18, 18, 24)
	key.Material = Enum.Material.SmoothPlastic
	key.TopSurface = Enum.SurfaceType.Smooth
	key.Parent = folder

	-- 上面に文字。SurfaceGui + TextLabel。発光感はTextStrokeとLightInfluence=0で。
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 0 -- 暗くても文字は明るいまま(発光風)
	gui.Brightness = 2
	gui.Parent = key

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.9)
	label.Position = UDim2.fromScale(0.05, 0.05)
	label.BackgroundTransparency = 1
	label.Text = ch
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = cfg.LabelBase
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(20, 60, 120)
	-- Top面のSurfaceGuiは文字が90°寝るので、見る向き(手前=+Z)に合わせて回す。
	-- もし逆向きに傾いたら -90 にする。
	label.Rotation = 90
	label.Parent = gui

	-- 上面中心(着地判定はXZのみ使うがYも入れておく)
	info.pos[ch] = base + Vector3.new(0, cfg.KeycapHeight, 0)
	info.part[ch] = key
	info.label[ch] = label
end

function Keyboard.build(): KeyInfo
	local cfg = GameConfig

	setupAtmosphere()

	local folder = Instance.new("Folder")
	folder.Name = "TypingWorld"
	folder.Parent = workspace

	buildDesk(folder)
	buildLaptop(folder)

	local info: KeyInfo = {
		pos = {},
		part = {},
		label = {},
		bounds = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge },
		homePos = Vector3.zero,
	}

	local kbdWidth = 10 * cfg.Pitch
	local rows = cfg.Rows
	for r = 1, #rows do
		local row = rows[r]
		-- r=1(QWERTY)が奥(-Z)、最終行(ZXC)が手前(z≈0)
		local z = -(#rows - r) * cfg.Pitch
		local xOff = cfg.RowStagger[r] * cfg.Pitch
		for i = 1, #row do
			local ch = string.sub(row, i, i)
			local x = -kbdWidth / 2 + xOff + (i - 1) * cfg.Pitch + cfg.Pitch / 2
			local base = Vector3.new(x, cfg.DeskY, z)
			makeKey(folder, ch, base, info)

			info.bounds.minX = math.min(info.bounds.minX, x)
			info.bounds.maxX = math.max(info.bounds.maxX, x)
			info.bounds.minZ = math.min(info.bounds.minZ, z)
			info.bounds.maxZ = math.max(info.bounds.maxZ, z)
		end
	end

	info.homePos = info.pos[cfg.HomeKey] or Vector3.zero
	return info
end

return Keyboard
