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
	-- 起動直後の暗さ(ライト計算の立ち上がり)の落差を抑えるため、基礎の明るさを
	-- 少しだけ底上げしておく(暗い部屋の雰囲気は維持)。
	Lighting.Ambient = Color3.fromRGB(20, 22, 32)
	Lighting.OutdoorAmbient = Color3.fromRGB(16, 18, 28)
	Lighting.Brightness = 1.0
	Lighting.ClockTime = 0 -- 夜
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(0, 0, 0)
	Lighting.FogStart = 120
	Lighting.FogEnd = 420

	-- 背景は真っ黒・星なし。星/太陽/月を消した真っ黒な空にする。
	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	sky.SunAngularSize = 0
	sky.MoonAngularSize = 0
	sky.SkyboxBk = "rbxasset://textures/blackBkg_SkyBox.png"
	sky.SkyboxDn = "rbxasset://textures/blackBkg_SkyBox.png"
	sky.SkyboxFt = "rbxasset://textures/blackBkg_SkyBox.png"
	sky.SkyboxLf = "rbxasset://textures/blackBkg_SkyBox.png"
	sky.SkyboxRt = "rbxasset://textures/blackBkg_SkyBox.png"
	sky.SkyboxUp = "rbxasset://textures/blackBkg_SkyBox.png"
	sky.Parent = Lighting

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
	spot.Brightness = 2.5
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

-- 机(一番下の台)。手前(+Z=人が座る側)はキーボードのすぐ先で切って短くし、
-- その先の床/風景が見えるようにする。奥(-Z)はディスプレイの先まで伸ばす。
local function buildDesk(folder: Folder)
	local cfg = GameConfig
	local kbdWidth = 10 * cfg.Pitch

	-- キーは z: 0(手前) .. -(rows-1)*pitch(奥)
	local zFront = cfg.Pitch * 1.5 -- 手前の切り位置(キーボード前端のちょっと先)
	local zBack = -130 -- 奥は遠くまで
	local depth = zFront - zBack
	local centerZ = (zFront + zBack) / 2

	local desk = Instance.new("Part")
	desk.Name = "Desk"
	desk.Anchored = true
	desk.Size = Vector3.new(kbdWidth + 90, 4, depth)
	-- 天面をデッキより少し下(DeskY-1)に。机→デッキ→キーの段差を作る。
	desk.Position = Vector3.new(0, cfg.DeskY - 1 - 2, centerZ)
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
	deck.Size = Vector3.new(kbdWidth + 8, deckThick, rowsN * cfg.Pitch + cfg.DeckDepthMargin)
	deck.Position = Vector3.new(0, cfg.DeskY - deckThick / 2, centerZ)
	deck.Color = Color3.fromRGB(26, 26, 34)
	deck.Material = Enum.Material.Metal
	deck.TopSurface = Enum.SurfaceType.Smooth
	deck.Parent = folder

	-- 画面の中心CFrame(GameConfigと共有=看板と位置が揃う)
	local screenH = cfg.ScreenH
	local screenW = cfg.screenWidth()
	local screenCenter = cfg.screenCenterCFrame()

	-- 画面の裏ガワ(暗い板)
	local back = Instance.new("Part")
	back.Name = "DisplayBack"
	back.Anchored = true
	back.Size = Vector3.new(screenW + 3, screenH + 3, 1.5)
	back.CFrame = screenCenter * CFrame.new(0, 0, -0.9)
	back.Color = Color3.fromRGB(18, 18, 24)
	back.Material = Enum.Material.Metal
	back.Parent = folder

	-- 発光ディスプレイ(光る四角)
	local screen = Instance.new("Part")
	screen.Name = "DisplayScreen"
	screen.Anchored = true
	screen.CanCollide = false
	screen.Size = Vector3.new(screenW, screenH, 0.4)
	screen.CFrame = screenCenter
	screen.Color = Color3.fromRGB(140, 160, 235)
	screen.Material = Enum.Material.Neon
	screen.Parent = folder

	-- ディスプレイに画像を貼る(IDが設定されていれば)。プレイヤー側=+Z面(Back)に表示。
	if cfg.DisplayImageId ~= "" then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.LightInfluence = 0 -- 暗くても画面は明るいまま(光る画面風)
		gui.Parent = screen

		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = cfg.DisplayImageId
		img.ScaleType = Enum.ScaleType.Stretch
		img.Parent = gui
	end

	-- 画面からキーボードへ降りる光(雰囲気の主光源)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(180, 170, 255)
	light.Brightness = 1.2
	light.Range = 70
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

-- キーボード周囲を透明な壁で囲い、移動範囲を制限する。
-- bounds はキー中心の最小/最大。そこに余白を足した外側に壁を立てる。
local function buildWalls(folder: Folder, bounds: { minX: number, maxX: number, minZ: number, maxZ: number })
	local cfg = GameConfig
	local margin = cfg.KeycapTop / 2 + cfg.Pitch * 0.5 -- キー外縁から半ピッチぶんの歩く余白
	local minX = bounds.minX - margin
	local maxX = bounds.maxX + margin
	local minZ = bounds.minZ - margin
	local maxZ = bounds.maxZ + margin
	local thick = 2
	local height = 30 -- ジャンプで越えられない高さ
	local cy = cfg.DeskY + height / 2
	local wSpan = maxX - minX
	local dSpan = maxZ - minZ

	local function wall(name: string, size: Vector3, pos: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = true
		p.CanTouch = false
		p.Transparency = 1
		p.Size = size
		p.Position = pos
		p.Parent = folder
	end

	wall("WallLeft", Vector3.new(thick, height, dSpan + thick * 2), Vector3.new(minX - thick / 2, cy, (minZ + maxZ) / 2))
	wall("WallRight", Vector3.new(thick, height, dSpan + thick * 2), Vector3.new(maxX + thick / 2, cy, (minZ + maxZ) / 2))
	wall("WallBack", Vector3.new(wSpan + thick * 2, height, thick), Vector3.new((minX + maxX) / 2, cy, minZ - thick / 2))
	wall("WallFront", Vector3.new(wSpan + thick * 2, height, thick), Vector3.new((minX + maxX) / 2, cy, maxZ + thick / 2))
end

-- キーボード左右の机上に置く小物(雰囲気用)。壁の外側=プレイ範囲外に置く。
local function buildProps(folder: Folder)
	local cfg = GameConfig
	local top = cfg.DeskY - 1 -- 机の天面y

	local function block(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material, rotY: number?)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Shape = Enum.PartType.Block
		p.Size = size
		p.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotY or 0), 0)
		p.Color = color
		p.Material = material
		p.Parent = folder
		return p
	end

	-- 立てた円柱(Cylinderは既定でX軸が軸なのでZ周りに90°回して縦置き)
	local function pillar(name: string, height: number, diam: number, pos: Vector3, color: Color3, material: Enum.Material, tiltDeg: number?)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(height, diam, diam)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90 + (tiltDeg or 0)))
		p.Color = color
		p.Material = material
		p.Parent = folder
		return p
	end

	-- ※ マウス/コップ/スマホは Creator Store のアセットをサーバーで配置するため、
	--   ここではプリミティブを作らない(重なり防止)。読込失敗時のフォールバックは無し。

	-- ===== 右側: マウスパッド(マウス本体はアセット) =====
	block("MousePad", Vector3.new(24, 0.4, 30), Vector3.new(56, top + 0.2, -2), Color3.fromRGB(28, 28, 38), Enum.Material.SmoothPlastic)

	-- ===== 左側: ペン立て＋発光ペン＋付箋 =====
	pillar("PenCup", 9, 8, Vector3.new(-60, top + 4.5, -16), Color3.fromRGB(26, 26, 38), Enum.Material.Metal)
	local penColors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 160, 255), Color3.fromRGB(110, 255, 150) }
	local penTilts = { 8, -6, 5 }
	for i = 1, 3 do
		pillar("Pen" .. i, 13, 0.9, Vector3.new(-60 + (i - 2) * 1.6, top + 9.5, -16), penColors[i], Enum.Material.Neon, penTilts[i])
	end

	-- 付箋メモ
	block("StickyNote", Vector3.new(6, 0.5, 6), Vector3.new(-48, top + 0.3, -6), Color3.fromRGB(220, 205, 80), Enum.Material.SmoothPlastic, -15)
end

-- 背景の部屋: 円柱の内側に画像を「ちょうど1周」だけ巻く。
-- 縦パネルを円状に並べ、各パネルに画像の横スライス(1/segments)を表示する。
-- スライスはスケール(割合)指定なので画像のピクセル数を知らなくても合う。
-- RoomImageId が空ならスキップ。
local function buildRoom(folder: Folder)
	local id = GameConfig.RoomImageId
	if id == "" then
		return
	end
	local segments = 50 -- 円の分割数(多いほど滑らか)
	local radius = 160
	-- 全体的に下げて埋める＋縦を伸ばして潰れを緩和(下へ深く)
	local yFloor, yCeil = -120, 25
	local height = yCeil - yFloor
	local centerY = (yFloor + yCeil) / 2
	local dim = Color3.fromRGB(95, 95, 110) -- 減光(暗い部屋になじませる)
	local chord = 2 * radius * math.sin(math.pi / segments)
	local segW = chord * 1.05 -- 少し広げて継ぎ目を消す
	-- 継ぎ目(画像の端と端が出会う所)をディスプレイの裏(-Z)に持っていく
	local angOffset = math.pi

	for i = 0, segments - 1 do
		local ang = angOffset + (i / segments) * math.pi * 2
		local dir = Vector3.new(math.sin(ang), 0, math.cos(ang)) -- 外向き
		local pos = Vector3.new(dir.X * radius, centerY, dir.Z * radius)

		local p = Instance.new("Part")
		p.Name = "RoomSeg" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = Vector3.new(segW, height, 1)
		-- 外を向ける(+Z=Back面が中心=プレイヤー側を向く)。内側から見て左右反転しない。
		p.CFrame = CFrame.lookAt(pos, pos + dir)
		p.Color = Color3.fromRGB(4, 5, 9)
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = folder

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.LightInfluence = 0
		-- 画像をN枚分の幅に引き伸ばすため、ピクセル上限を超えないよう解像度を落とす
		gui.PixelsPerStud = 8
		gui.Parent = p

		-- クリップ枠の中で、横N枚分の画像をiぶんずらして該当スライスだけ見せる
		local clip = Instance.new("Frame")
		clip.Size = UDim2.fromScale(1, 1)
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Parent = gui

		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = id
		img.ImageColor3 = dim
		img.ScaleType = Enum.ScaleType.Stretch
		img.Size = UDim2.fromScale(segments, 1)
		-- 内側から見ると各パネルが左右反転するため、スライス順も逆にして境界を合わせる
		img.Position = UDim2.fromScale(-(segments - 1 - i), 0)
		img.Parent = clip
	end

	-- 床(暗いまま。中央は机が覆う)
	local floor = Instance.new("Part")
	floor.Name = "RoomFloor"
	floor.Anchored = true
	floor.CanCollide = false
	floor.CanQuery = false
	floor.Size = Vector3.new(radius * 2.2, 2, radius * 2.2)
	floor.Position = Vector3.new(0, yFloor, 0)
	floor.Color = Color3.fromRGB(6, 6, 9)
	floor.Material = Enum.Material.SmoothPlastic
	floor.Parent = folder
end

function Keyboard.build(): KeyInfo
	local cfg = GameConfig

	setupAtmosphere()

	local folder = Instance.new("Folder")
	folder.Name = "TypingWorld"
	folder.Parent = workspace

	buildRoom(folder)
	buildDesk(folder)
	buildLaptop(folder)
	buildProps(folder)

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

	buildWalls(folder, info.bounds)

	info.homePos = info.pos[cfg.HomeKey] or Vector3.zero
	return info
end

return Keyboard
