--!strict
-- 画面UI(お題・スコア・LV/時間・中央ポップ)。Godot版 _build_ui 相当。
-- RichText対応のTextLabelで、お題の「済/次/未入力」を色分け表示する。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Hud = {}
Hud.__index = Hud

export type Hud = typeof(setmetatable({} :: {
	gui: ScreenGui,
	word: TextLabel,
	score: TextLabel,
	time: TextLabel,
	pop: TextLabel,
}, Hud))

local function rgbHex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function Hud.new(parent: Instance): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "TypingHud"
	gui.ResetOnSpawn = false
	-- Robloxのトップバー(左上メニュー/右上一覧)と被らないよう、その下に配置する
	gui.IgnoreGuiInset = false
	gui.Parent = parent

	-- 上部の薄い帯
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 96)
	bar.BackgroundColor3 = Color3.fromRGB(230, 235, 245)
	bar.BackgroundTransparency = 0.8
	bar.BorderSizePixel = 0
	bar.Parent = gui

	-- お題(中央上)
	local word = Instance.new("TextLabel")
	word.Size = UDim2.new(1, 0, 0, 80)
	word.Position = UDim2.fromOffset(0, 8)
	word.BackgroundTransparency = 1
	word.RichText = true
	word.Text = ""
	word.TextScaled = false
	word.TextSize = 56
	word.Font = Enum.Font.FredokaOne
	word.TextColor3 = Color3.new(1, 1, 1)
	word.TextStrokeTransparency = 0.2
	word.TextStrokeColor3 = Color3.fromRGB(8, 12, 24)
	word.Parent = gui

	-- スコア(左上)
	local score = Instance.new("TextLabel")
	score.Size = UDim2.fromOffset(420, 36)
	score.Position = UDim2.fromOffset(22, 14)
	score.BackgroundTransparency = 1
	score.TextXAlignment = Enum.TextXAlignment.Left
	score.Text = "SCORE 0"
	score.TextSize = 26
	score.Font = Enum.Font.GothamBold
	score.TextColor3 = Color3.fromRGB(30, 36, 50)
	score.TextStrokeTransparency = 0.2
	score.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	score.Parent = gui

	-- LV/時間(右上)
	local time = Instance.new("TextLabel")
	time.Size = UDim2.fromOffset(300, 64)
	time.Position = UDim2.new(1, -322, 0, 14)
	time.BackgroundTransparency = 1
	time.TextXAlignment = Enum.TextXAlignment.Right
	time.TextYAlignment = Enum.TextYAlignment.Top
	time.Text = "LV 1\nTIME 0.0"
	time.TextSize = 26
	time.Font = Enum.Font.GothamBold
	time.TextColor3 = Color3.fromRGB(30, 36, 50)
	time.TextStrokeTransparency = 0.2
	time.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	time.Parent = gui

	-- 中央ポップ(CLEAR/GAME OVER)
	local pop = Instance.new("TextLabel")
	pop.Size = UDim2.fromScale(1, 1)
	pop.BackgroundTransparency = 1
	pop.Text = ""
	pop.TextSize = 64
	pop.Font = Enum.Font.FredokaOne
	pop.TextColor3 = Color3.new(1, 1, 1)
	pop.TextTransparency = 1
	pop.TextStrokeTransparency = 1
	pop.Parent = gui

	-- 操作ヒント(左下)
	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.fromOffset(420, 50)
	hint.Position = UDim2.new(0, 18, 1, -60)
	hint.BackgroundTransparency = 1
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = "WASD 移動    SPACE ジャンプで打鍵"
	hint.TextSize = 16
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(220, 220, 230)
	hint.TextTransparency = 0.4
	hint.Parent = gui

	return setmetatable({
		gui = gui,
		word = word,
		score = score,
		time = time,
		pop = pop,
	}, Hud)
end

-- お題: 済(緑)/次(橙太字)/未入力(灰) の色分け。RichTextで組む。
function Hud.setWord(self: Hud, target: string, charIdx: number)
	local done = string.sub(target, 1, charIdx)
	local cur = ""
	local rest = ""
	if charIdx < #target then
		cur = string.sub(target, charIdx + 1, charIdx + 1)
		rest = string.sub(target, charIdx + 2)
	end
	self.word.Text = string.format(
		'<font color="%s">%s</font><font color="%s"><b>%s</b></font><font color="%s">%s</font>',
		rgbHex(GameConfig.UiDone), done,
		rgbHex(GameConfig.UiCurrent), cur,
		rgbHex(GameConfig.UiRest), rest
	)
end

function Hud.setScore(self: Hud, score: number, combo: number)
	local text = string.format("SCORE %d", score)
	if combo >= 2 then
		text ..= string.format("    COMBO x%d", combo)
	end
	self.score.Text = text
end

function Hud.setTime(self: Hud, level: number, timeLeft: number, ratio: number)
	self.time.Text = string.format("LV %d\nTIME %0.1f", level, timeLeft)
	-- 残り少なくなったら赤
	self.time.TextColor3 = if ratio < 0.4 then Color3.fromRGB(220, 40, 40) else Color3.fromRGB(30, 36, 50)
end

-- 中央ポップ(一定時間後フェードアウト)
function Hud.popup(self: Hud, text: string, color: Color3, size: number?)
	local pop = self.pop
	pop.TextSize = size or 64
	pop.Text = text
	pop.TextColor3 = color
	pop.TextTransparency = 0
	pop.TextStrokeTransparency = 0.4
	task.delay(0.5, function()
		if pop.Text ~= text then
			return -- 別のポップに差し替わっていたら何もしない
		end
		TweenService:Create(pop, TweenInfo.new(0.5), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end)
end

-- ゲームオーバー表示(消えない)
function Hud.gameOver(self: Hud, score: number, best: number)
	local pop = self.pop
	pop.TextSize = 52
	pop.Text = string.format("GAME OVER\nSCORE %d    BEST %d\n\n[ SPACE ] でリトライ", score, best)
	pop.TextColor3 = Color3.fromRGB(255, 140, 140)
	pop.TextTransparency = 0
	pop.TextStrokeTransparency = 0.4
end

function Hud.clearPop(self: Hud)
	self.pop.Text = ""
	self.pop.TextTransparency = 1
	self.pop.TextStrokeTransparency = 1
end

return Hud
