--!strict
-- サーバー・クライアント両方から参照する共有設定。
-- ReplicatedStorage.Shared.GameConfig として両方からrequireできる。
--
-- 3Dタイピング: アバターが巨大キーボードの上を走り、お題の次の文字キーへ
-- 移動してジャンプ着地で打鍵する。ここに寸法・スコア・色・単語をまとめる。
--
-- 注意: strict型チェックでは「テーブル確定後のプロパティ後付け」がエラーになるため、
-- 関数やWordsも含めて全部を最初のテーブルリテラル内に入れている。
-- 関数が参照する定数は先にローカルへ出してから使う。

local Pitch = 7.5 -- キー中心間の距離
local DeskY = 0.0 -- キーが乗る基準面y(ノートPCデッキの天面)
local Rows = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" } -- QWERTY=奥、ZXC=手前
local ScreenH = 36 -- ディスプレイの高さ
local ScreenTiltDeg = 12 -- 画面の後ろへの傾き(度)
local DeckDepthMargin = 10 -- デッキ奥行きのキー範囲からの余白

-- 画面(ディスプレイ)の幅
local function screenWidth(): number
	return ScreenH * 16 / 9
end

-- ディスプレイ中心のCFrame(前=+Z面がプレイヤー側)。
-- クライアントの画面生成(buildLaptop)とサーバーの看板配置で同じ値を使う。
local function screenCenterCFrame(): CFrame
	local rowsN = #Rows
	local centerZ = -((rowsN - 1) * Pitch) / 2
	local deckDepth = rowsN * Pitch + DeckDepthMargin
	local backZ = centerZ - deckDepth / 2
	local hinge = CFrame.new(0, DeskY, backZ) * CFrame.Angles(math.rad(-ScreenTiltDeg), 0, 0)
	return hinge * CFrame.new(0, ScreenH / 2 + 1, 0)
end

-- Creator Store のアセットで置く小物(サーバーがInsertService:LoadAssetで生成)。
-- x/z=机上の配置, size=最大寸法(スタッド)に縮尺, yOffset=高さ微調整。
-- rotX/rotY/rotZ=向き(度)。配置は回転後の寸法から机に接地＆水平中心合わせ。
-- fallback: LoadAsset失敗時に出すプリミティブ(kind=block/cylinder)。
-- ※ fallback は block(size)/cylinder(h,d) で形が違う異種データなので { any } 扱い。
local AssetProps: { any } = {
	{
		name = "Mouse", assetId = 12401982160, x = 56, z = -2, size = 9,
		rotX = 0, rotY = -90, rotZ = 0, yOffset = 0,
		fallback = { kind = "block", size = Vector3.new(6, 3, 9), color = Color3.fromRGB(40, 40, 52) },
	},
	{
		name = "Cup", assetId = 2786693128, x = 64, z = -24, size = 9,
		rotX = 0, rotY = 0, rotZ = -90, yOffset = 0,
		fallback = { kind = "cylinder", h = 7, d = 8, color = Color3.fromRGB(120, 110, 130) },
	},
	{
		name = "Phone", assetId = 1413698014, x = -54, z = 6, size = 14,
		rotX = -90, rotY = 12, rotZ = 0, yOffset = 0,
		fallback = { kind = "block", size = Vector3.new(8, 0.8, 16), color = Color3.fromRGB(22, 22, 32) },
	},
}

local GameConfig = {
	-- ===== キーボードの寸法（スタッド） =====
	-- Robloxアバター(約5スタッド)が乗れるよう、実物より大きく作る。
	KeycapTop = 5.5, -- キートップの一辺(正方形)
	KeycapHeight = 1.5, -- キーの高さ
	Pitch = Pitch,
	DeskY = DeskY,

	-- アバターの移動速度(既定16では巨大キーボード上で遅すぎる)
	WalkSpeed = 26,

	-- ノートPCディスプレイの寸法(クライアントの画面生成とサーバーの看板で共有)
	ScreenH = ScreenH,
	ScreenTiltDeg = ScreenTiltDeg,
	DeckDepthMargin = DeckDepthMargin,
	-- ディスプレイに貼る画像(rbxassetid)。空なら光る四角のまま。
	DisplayImageId = "rbxassetid://119139201724852",
	-- 背景の部屋画像(rbxassetid)。空なら部屋背景なし。
	RoomImageId = "rbxassetid://73576819764784",

	-- 3行のキー配列と横ずらし(キー数ぶん)。QWERTY=奥、ZXC=手前。
	Rows = Rows,
	RowStagger = { 0.0, 0.5, 1.0 },

	-- ホームポジション(開始キー)
	HomeKey = "F",

	-- ===== 判定 =====
	-- 着地時、最寄りキーがこの半径内なら「踏んだ」と判定
	StompRadius = 4.5,

	-- ===== スコア =====
	ScorePer = 100, -- 1キー正解 × コンボ
	WordBonus = 500, -- 単語クリア
	MissTimePenalty = 1.5, -- お手つきの時間ペナルティ(秒)

	-- ===== 制限時間(プラス制: 1本の連続タイマー) =====
	-- 正解キーごとに時間を加算。加算量はレベルで減衰(序盤大・終盤小)。
	-- 序盤に速く打つほど時間を貯金でき、終盤は貯金を取り崩して粘る設計。
	StartTime = 15.0, -- 開始時のタイマー
	TimeCap = 30.0, -- タイマー上限(貯金しすぎ防止)
	KeyTimeMax = 1.8, -- 1キー正解の加算(序盤)
	KeyTimeMin = 0.55, -- 1キー正解の加算(終盤の下限)
	KeyTimeDecay = 0.06, -- レベルごとの減衰
	WordTimeBonus = 1.0, -- 単語クリアの時間ボーナス
	RetryDelay = 0.7, -- ゲームオーバー後リトライ受付までの猶予

	-- ===== 課金アイテム(薬: 買うと制限時間+) =====
	-- Creator Hub で「開発者プロダクト(Developer Product)」を作り、そのIDをここに。
	-- 0 のままだと販売無効(瓶は出るが購入ダイアログは開かない)。価格はRobux側で設定。
	PotionProductId = 3605243594,
	PotionTimeSeconds = 60, -- 1回購入で増える秒数
	ShopIconId = "rbxassetid://93061313779692", -- ショップ/薬アイコン画像(空ならテキスト表示)

	-- ===== 色 =====
	-- キー上面ラベル(発光想定)。通常=青白、次に踏む=金。
	LabelBase = Color3.fromRGB(150, 200, 255),
	LabelNext = Color3.fromRGB(255, 215, 70),
	LabelOk = Color3.fromRGB(255, 255, 255),
	LabelErr = Color3.fromRGB(255, 90, 90),

	-- お題UIの配色(RichText)
	UiDone = Color3.fromRGB(80, 220, 120), -- 入力済み
	UiCurrent = Color3.fromRGB(255, 150, 60), -- 次の文字
	UiRest = Color3.fromRGB(200, 205, 215), -- 未入力

	-- アセット小物(上で型付き定義したものを参照)
	AssetProps = AssetProps,

	-- お題の単語(英字大文字のみ)。長さ別。レベルで長い語が出やすくなる。
	Words = {
		-- 3
		"CAT", "DOG", "RUN", "SKY", "FOX", "ZAP", "SUN", "MAP", "BUG", "CUP",
		"HAT", "ICE", "JAM", "KEY", "LOG", "NET", "OWL", "PEN", "RAT", "TOP",
		"VAN", "WAX", "YES", "ZIP", "ARM", "BOX", "EAR", "FAN", "GAP", "JOY",
		-- 4
		"JUMP", "GAME", "CODE", "DARK", "GLOW", "KEYS", "FAST", "STAR", "MOON", "TYPE",
		"WAVE", "FIRE", "WIND", "SNOW", "RAIN", "LEAF", "ROCK", "GOLD", "BLUE", "PINK",
		"FROG", "BIRD", "FISH", "LION", "BEAR", "WOLF", "DUCK", "CITY", "ROAD", "SHIP",
		"COIN", "DASH", "GRID", "HERO", "KING", "MAZE", "BEAM", "BOLT", "CAVE", "DUSK",
		-- 5
		"BLOCK", "PIXEL", "LEVEL", "SCORE", "SPEED", "LIGHT", "NIGHT", "BRAVE", "QUEST", "MAGIC",
		"ROBOT", "LASER", "POWER", "GHOST", "CLOUD", "STORM", "FLAME", "RIVER", "OCEAN", "TIGER",
		"EAGLE", "SNAKE", "PANDA", "HONEY", "CANDY", "DREAM", "SPACE", "EARTH", "PLANT", "MOUSE",
		"SWORD", "SHARP", "QUICK", "JOLLY", "ZEBRA",
		-- 6
		"TYPING", "RUNNER", "PLAYER", "JUMPER", "ROCKET", "DRAGON", "KNIGHT", "WIZARD", "PLANET", "GALAXY",
		"SHADOW", "BRIGHT", "FROZEN", "GARDEN", "FOREST", "SILVER", "GOLDEN", "PURPLE", "ORANGE", "CASTLE",
		-- 7
		"VICTORY", "THUNDER", "CRYSTAL", "DIAMOND", "JOURNEY", "MACHINE", "PROGRAM", "RAINBOW", "MONSTER",
		-- 8
		"KEYBOARD", "COMPUTER", "MOUNTAIN", "ELEPHANT", "SUNLIGHT", "MOONBEAM", "FIREWORK", "DINOSAUR",
	},

	-- 画面まわりのヘルパ(クライアント/サーバー共有)
	screenWidth = screenWidth,
	screenCenterCFrame = screenCenterCFrame,
}

return GameConfig
