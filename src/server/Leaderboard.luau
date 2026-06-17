--!strict
-- 全体ハイスコア・ランキング。OrderedDataStore に各プレイヤーの自己ベストを保存し、
-- 上位N人を世界内の看板(ディスプレイ脇)に表示する。
--
-- スコアはクライアントが RemoteEvent "SubmitScore" で送る。サーバーは最大値だけ
-- 保存する(ゲームロジックがクライアント側のため厳密な検証は不可=改ざんは割り切り)。
-- ※ Studioで動かすには「Game Settings → Security → Enable Studio Access to
--   API Services」をONにする必要がある(DataStore利用のため)。

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Leaderboard = {}

local TOP_N = 10
local SCORE_MAX = 10000000 -- ざっくり上限(明らかな異常値を弾く)
-- Studioのテストは本番ランキングを汚さないよう別ストア(_dev)に分ける。
-- 公開サーバーでは "TypingHighScores_v1"(本番)を使う。
local STORE_NAME = "TypingHighScores_v2" .. (if RunService:IsStudio() then "_dev" else "")
local store = DataStoreService:GetOrderedDataStore(STORE_NAME)

local rowName: { TextLabel } = {}
local rowScore: { TextLabel } = {}
local statusLabel: TextLabel? = nil

-- ===== 看板 =====
local function buildBoard()
	-- ディスプレイ画面の左部分に重ねて「画面に表示されてる風」にする。
	local screenCenter = GameConfig.screenCenterCFrame()
	local screenW = GameConfig.screenWidth()
	local screenH = GameConfig.ScreenH
	local boardW = screenW * 0.4
	local boardH = screenH * 0.86
	-- 画面左寄り・少し手前(+Z)に配置。向き・傾きは画面と同じ。
	local localX = -screenW / 2 + boardW / 2 + screenW * 0.03

	local part = Instance.new("Part")
	part.Name = "Leaderboard"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Size = Vector3.new(boardW, boardH, 0.3)
	part.Color = Color3.fromRGB(8, 10, 16)
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = screenCenter * CFrame.new(localX, 0, 0.5)
	part.Parent = workspace

	local gui = Instance.new("SurfaceGui")
	-- Partの「Front」面は-Z側。プレイヤーは+Z側から見るので Back(+Z)に表示する。
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(400, 480)
	gui.LightInfluence = 0 -- 暗い部屋でも読める
	gui.Brightness = 1.5
	gui.Parent = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(12, 14, 24)
	bg.BackgroundTransparency = 0.05
	bg.Parent = gui

	-- 縁取り(暗い部屋でも板の存在が分かるように)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(120, 150, 230)
	stroke.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 56)
	title.BackgroundTransparency = 1
	title.Text = "HIGH SCORES"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 40
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.Parent = bg

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, 0, 0, 36)
	status.Position = UDim2.fromOffset(0, 56)
	status.BackgroundTransparency = 1
	status.Text = "Loading..."
	status.Font = Enum.Font.Gotham
	status.TextSize = 22
	status.TextColor3 = Color3.fromRGB(150, 160, 180)
	status.Parent = bg
	statusLabel = status

	-- 行
	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, -24, 1, -64)
	list.Position = UDim2.fromOffset(12, 64)
	list.BackgroundTransparency = 1
	list.Parent = bg

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list

	for i = 1, TOP_N do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 38)
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		row.BackgroundTransparency = if i % 2 == 0 then 0.92 else 0.97
		row.LayoutOrder = i
		row.Parent = list

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.72, 0, 1, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Font = Enum.Font.GothamMedium
		nameLbl.TextSize = 24
		nameLbl.TextColor3 = Color3.fromRGB(225, 230, 240)
		nameLbl.Text = string.format("%d.", i)
		nameLbl.Parent = row

		local scoreLbl = Instance.new("TextLabel")
		scoreLbl.Size = UDim2.new(0.28, 0, 1, 0)
		scoreLbl.Position = UDim2.fromScale(0.72, 0)
		scoreLbl.BackgroundTransparency = 1
		scoreLbl.TextXAlignment = Enum.TextXAlignment.Right
		scoreLbl.Font = Enum.Font.GothamBold
		scoreLbl.TextSize = 24
		scoreLbl.TextColor3 = Color3.fromRGB(120, 230, 255)
		scoreLbl.Text = ""
		scoreLbl.Parent = row

		rowName[i] = nameLbl
		rowScore[i] = scoreLbl
	end
end

-- ===== 名前解決(キャッシュ) =====
local nameCache: { [number]: string } = {}
local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local n = (ok and name) or ("User " .. userId)
	nameCache[userId] = n
	return n
end

-- ===== 看板更新 =====
local function setRows(entries: { { name: string, score: number } })
	for i = 1, TOP_N do
		local e = entries[i]
		if e then
			rowName[i].Text = string.format("%d. %s", i, e.name)
			rowScore[i].Text = tostring(e.score)
		else
			rowName[i].Text = string.format("%d.", i)
			rowScore[i].Text = ""
		end
	end
end

local refreshing = false
function Leaderboard.refresh()
	if refreshing then
		return
	end
	refreshing = true
	task.spawn(function()
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, TOP_N)
		end)
		if ok and pages then
			local page = pages:GetCurrentPage()
			local entries = {}
			for _, e in page do
				local uid = tonumber(e.key)
				entries[#entries + 1] = { name = uid and nameFor(uid) or tostring(e.key), score = e.value }
			end
			setRows(entries)
			if statusLabel then
				statusLabel.Text = if #entries == 0 then "No scores yet" else "Global Ranking"
			end
		else
			if statusLabel then
				statusLabel.Text = "(Ranking unavailable: enable API)"
			end
		end
		refreshing = false
	end)
end

-- ===== スコア送信受付 =====
function Leaderboard.submit(player: Player, score: any)
	if typeof(score) ~= "number" or score ~= score then -- NaN除外
		return
	end
	score = math.floor(score)
	if score <= 0 or score > SCORE_MAX then
		return
	end
	local key = tostring(player.UserId)
	local ok = pcall(function()
		store:UpdateAsync(key, function(old)
			return math.max((old :: number?) or 0, score)
		end)
	end)
	if ok then
		Leaderboard.refresh()
	end
end

function Leaderboard.start()
	buildBoard()

	local ev = Instance.new("RemoteEvent")
	ev.Name = "SubmitScore"
	ev.Parent = ReplicatedStorage
	ev.OnServerEvent:Connect(function(player, score)
		Leaderboard.submit(player, score)
	end)

	Leaderboard.refresh()
	-- 定期更新(他プレイヤーの更新を反映)
	task.spawn(function()
		while true do
			task.wait(60)
			Leaderboard.refresh()
		end
	end)
end

return Leaderboard
