--!strict
-- 3Dタイピング クライアント本体。
-- Godot版 world.gd のゲームループ部分(_next_word / _on_land / _advance /
-- スコア・制限時間・ゲームオーバー・リトライ)をRoblox化したもの。
--
-- 操作はRoblox標準: WASDで移動、SPACEでジャンプ。お題の次の文字キーへ移動し、
-- ジャンプ着地したとき最寄りキーを「踏んだ」と判定する。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- init.client.luau があるフォルダ自体がこの LocalScript(Client)。
-- 兄弟の .luau は「この LocalScript の子」になるので script.<名前> で参照する。
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Keyboard = require(script.Keyboard)
local Hud = require(script.Hud)
local Sounds = require(script.Sounds)

local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1人用なので不要なコアUIを消して画面を広く使う(スコア等との重なりも防ぐ)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
end)

-- ===== ワールド生成 =====
local keys = Keyboard.build()
local hud = Hud.new(playerGui)

-- ハイスコア送信用(サーバーが自己ベストを保存→看板更新)
local submitScore = ReplicatedStorage:WaitForChild("SubmitScore") :: RemoteEvent

-- ===== ゲーム状態 =====
local target = ""
local charIdx = 0
local highlightChar = ""
local score = 0
local combo = 0
local level = 1
local timeLeft = 0.0
local timeLimit = 1.0
local playing = false
local gameOver = false
local goReady = false -- ゲームオーバー後リトライ受付可
local best = 0

-- ===== キー演出 =====
local function setLabelColor(ch: string, color: Color3)
	local lbl = keys.label[ch]
	if lbl then
		lbl.TextColor3 = color
	end
end

-- 現在のハイライトを完全に解除(ラベル色＋キーのNeon/色を通常へ戻す)
local function clearHighlight()
	if highlightChar ~= "" then
		setLabelColor(highlightChar, GameConfig.LabelBase)
		local prev = keys.part[highlightChar]
		if prev then
			prev.Material = Enum.Material.SmoothPlastic
			prev.Color = Color3.fromRGB(18, 18, 24)
		end
	end
	highlightChar = ""
end

local function setHighlight()
	clearHighlight()
	if charIdx < #target then
		local ch = string.sub(target, charIdx + 1, charIdx + 1)
		if keys.label[ch] then
			setLabelColor(ch, GameConfig.LabelNext)
			local part = keys.part[ch]
			if part then
				part.Material = Enum.Material.Neon
				part.Color = Color3.fromRGB(90, 70, 20) -- 控えめな金の発光
			end
			highlightChar = ch
		end
	end
end

local function flashLabel(ch: string, color: Color3)
	local lbl = keys.label[ch]
	if not lbl then
		return
	end
	lbl.TextColor3 = color
	task.delay(0.3, function()
		-- 次の対象でなければ通常色へ
		if ch ~= highlightChar then
			lbl.TextColor3 = GameConfig.LabelBase
		end
	end)
end

local function depressKey(ch: string)
	local part = keys.part[ch]
	if not part then
		return
	end
	-- キー中心の通常Y(上面 - 高さの半分)
	local restY = keys.pos[ch].Y - GameConfig.KeycapHeight / 2
	local downPos = Vector3.new(part.Position.X, restY - 0.6, part.Position.Z)
	local upPos = Vector3.new(part.Position.X, restY, part.Position.Z)
	-- 押し込み→戻し
	local down = TweenService:Create(part, TweenInfo.new(0.05), { Position = downPos })
	down:Play()
	down.Completed:Once(function()
		TweenService:Create(part, TweenInfo.new(0.09), { Position = upPos }):Play()
	end)
end

-- ===== HUD反映 =====
local function updateHud()
	hud:setScore(score, combo)
	local ratio = if timeLimit > 0.01 then math.clamp(timeLeft / timeLimit, 0, 1) else 0
	hud:setTime(level, timeLeft, ratio)
end

-- ===== お題選択 =====
local lastWord = ""
local function pickWord(): string
	local targetLen = math.clamp(3 + math.floor(level / 3), 3, 8)
	local cands = {}
	for _, w in GameConfig.Words do
		if math.abs(#w - targetLen) <= 1 then
			table.insert(cands, w)
		end
	end
	if #cands == 0 then
		cands = GameConfig.Words
	end
	local w = cands[math.random(1, #cands)]
	if w == lastWord and #cands > 1 then
		w = cands[(table.find(cands, w) :: number % #cands) + 1]
	end
	lastWord = w
	return w
end

local function nextWord()
	target = pickWord()
	charIdx = 0
	local perChar = math.clamp(GameConfig.PerCharMax - level * GameConfig.PerCharDecay, GameConfig.PerCharMin, GameConfig.PerCharMax)
	timeLimit = GameConfig.TimeBase + #target * perChar
	timeLeft = timeLimit
	playing = true
	hud:setWord(target, charIdx)
	updateHud()
	setHighlight()
end

local function startGame()
	score = 0
	combo = 0
	level = 1
	nextWord()
end

-- ===== 打鍵判定 =====
local function nearestKey(pos: Vector3): string
	local best_ch = ""
	local bestd = GameConfig.StompRadius
	for ch, kp in keys.pos do
		local d = (Vector2.new(pos.X, pos.Z) - Vector2.new(kp.X, kp.Z)).Magnitude
		if d < bestd then
			bestd = d
			best_ch = ch
		end
	end
	return best_ch
end

local function onWordClear()
	playing = false
	local timeBonus = math.floor(timeLeft * GameConfig.TimeBonusPer)
	local gained = GameConfig.WordBonus + timeBonus
	score += gained
	level += 1
	Sounds.play("clear")
	hud:popup("CLEAR!  +" .. gained, Color3.fromRGB(150, 255, 180), 64)
	updateHud()
	task.delay(0.95, function()
		if not gameOver then
			nextWord()
		end
	end)
end

local function advance()
	charIdx += 1
	hud:setWord(target, charIdx)
	setHighlight()
	if charIdx >= #target then
		onWordClear()
	end
end

local gameOverNow -- 前方宣言

local function onLand(rootPos: Vector3)
	local ch = nearestKey(rootPos)
	if ch == "" then
		return
	end
	depressKey(ch)
	Sounds.play("stomp")
	if not playing then
		return
	end
	if ch == highlightChar then
		combo += 1
		score += GameConfig.ScorePer * combo
		flashLabel(ch, GameConfig.LabelOk)
		Sounds.play("ok")
		updateHud()
		advance()
	else
		-- お手つき: コンボ消滅＋時間ペナルティ
		combo = 0
		timeLeft = math.max(0, timeLeft - GameConfig.MissTimePenalty)
		flashLabel(ch, GameConfig.LabelErr)
		Sounds.play("err")
		updateHud()
	end
end

function gameOverNow()
	playing = false
	gameOver = true
	goReady = false
	combo = 0
	best = math.max(best, score)
	Sounds.play("err")
	updateHud()
	hud:gameOver(score, best)
	-- サーバーへ今回のスコアを送る(自己ベストならランキング更新)
	if score > 0 then
		submitScore:FireServer(score)
	end
	task.delay(GameConfig.RetryDelay, function()
		goReady = true
	end)
end

-- ===== アバター設定 =====
local currentHumanoid: Humanoid? = nil

local function placeOnHome(char: Model)
	-- ホームキーの少し上へ。着地して乗る。
	char:PivotTo(CFrame.new(keys.homePos + Vector3.new(0, 4, 0)))
end

local function setupCharacter(char: Model)
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	char:WaitForChild("HumanoidRootPart")
	currentHumanoid = humanoid
	humanoid.WalkSpeed = GameConfig.WalkSpeed
	placeOnHome(char)

	-- 着地イベントで打鍵判定(ジャンプ→着地で踏んだキーを判定)
	humanoid.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Landed then
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				onLand(root.Position)
			end
		end
	end)
end

if player.Character then
	setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

-- ===== リトライ入力 =====
local function restart()
	gameOver = false
	goReady = false
	hud:clearPop()
	clearHighlight()
	if player.Character then
		placeOnHome(player.Character)
	end
	startGame()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if gameOver and goReady and input.KeyCode == Enum.KeyCode.Space then
		restart()
	end
end)

-- ===== 制限時間カウントダウン =====
RunService.Heartbeat:Connect(function(dt)
	if not playing or gameOver then
		return
	end
	timeLeft -= dt
	if timeLeft <= 0 then
		timeLeft = 0
		updateHud()
		gameOverNow()
		return
	end
	updateHud()
end)

-- ===== 開始 =====
Sounds.startBgm()
task.wait(0.5) -- アバターがキーに乗るのを待つ
startGame()

print("[typing3d] クライアント起動: 3Dタイピング開始")
