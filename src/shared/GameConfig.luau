--!strict
-- サーバー・クライアント両方から参照する共有設定。
-- ReplicatedStorage.Shared.GameConfig として両方からrequireできる。
--
-- 3Dタイピング: アバターが巨大キーボードの上を走り、お題の次の文字キーへ
-- 移動してジャンプ着地で打鍵する。ここに寸法・スコア・色・単語をまとめる。

local GameConfig = {
	-- ===== キーボードの寸法（スタッド） =====
	-- Robloxアバター(約5スタッド)が乗れるよう、実物より大きく作る。
	KeycapTop = 5.5, -- キートップの一辺(正方形)
	KeycapHeight = 1.5, -- キーの高さ
	Pitch = 7.5, -- キー中心間の距離
	DeskY = 0.0, -- キーが乗る基準面y(ノートPCデッキの天面)

	-- アバターの移動速度(既定16では巨大キーボード上で遅すぎる)
	WalkSpeed = 30,

	-- 3行のキー配列と横ずらし(キー数ぶん)。QWERTY=奥、ZXC=手前。
	Rows = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" },
	RowStagger = { 0.0, 0.5, 1.0 },

	-- ホームポジション(開始キー)
	HomeKey = "F",

	-- ===== 判定 =====
	-- 着地時、最寄りキーがこの半径内なら「踏んだ」と判定
	StompRadius = 4.5,

	-- ===== スコア =====
	ScorePer = 100, -- 1キー正解 × コンボ
	WordBonus = 500, -- 単語クリア
	TimeBonusPer = 50, -- 残り時間1秒あたりのボーナス
	MissTimePenalty = 1.0, -- お手つきの時間ペナルティ(秒)

	-- ===== 制限時間 =====
	-- 巨大キーボード上の移動時間を見込んで長めに。time = Base + 文字数 × PerChar。
	-- PerCharはレベルで微減(下限あり)。
	TimeBase = 2.5,
	PerCharMax = 2.8,
	PerCharMin = 1.8,
	PerCharDecay = 0.08, -- レベルごとの減衰
	RetryDelay = 0.7, -- ゲームオーバー後リトライ受付までの猶予

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
}

-- お題の単語(英字大文字のみ)。長さ別。レベルで長い語が出やすくなる。
GameConfig.Words = {
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
}

return GameConfig
