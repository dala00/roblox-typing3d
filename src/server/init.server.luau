--!strict
-- 文字キューブを空中に浮かべ、クリックされたら消して新しいものを出す。
-- クリックした人のスコアを加算し、RemoteEventでクライアントに通知する。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- クライアントへスコアを送るためのRemoteEventを用意
local scoreEvent = Instance.new("RemoteEvent")
scoreEvent.Name = "ScoreUpdate"
scoreEvent.Parent = ReplicatedStorage

-- キューブをまとめておくフォルダ
local cubesFolder = Instance.new("Folder")
cubesFolder.Name = "Cubes"
cubesFolder.Parent = workspace

-- プレイヤーごとのスコア
local scores: { [Player]: number } = {}

-- ランダムな出現位置を返す
local function randomSpawnPosition(): Vector3
	local angle = math.random() * math.pi * 2
	local dist = math.random() * GameConfig.SpawnRadius
	local x = math.cos(angle) * dist
	local z = math.sin(angle) * dist
	local y = math.random(GameConfig.SpawnHeightMin, GameConfig.SpawnHeightMax)
	return Vector3.new(x, y, z)
end

local function randomLetter(): string
	local letters = GameConfig.Letters
	local i = math.random(1, #letters)
	return string.sub(letters, i, i)
end

-- 1個ぶんのキューブを生成
local function spawnCube()
	local cube = Instance.new("Part")
	cube.Size = Vector3.one * GameConfig.CubeSize
	cube.Position = randomSpawnPosition()
	cube.Anchored = true
	cube.Material = Enum.Material.Neon
	cube.Color = Color3.fromHSV(math.random(), 0.7, 1)
	cube.Name = "LetterCube"

	-- キューブの面に文字を表示
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(200, 200)
	gui.Parent = cube

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = randomLetter()
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui

	-- クリック判定
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 64
	click.Parent = cube

	click.MouseClick:Connect(function(player: Player)
		scores[player] = (scores[player] or 0) + GameConfig.PointsPerHit
		print(string.format("[typing3d] %s が '%s' をクリック → %d点", player.Name, label.Text, scores[player]))
		scoreEvent:FireClient(player, scores[player])

		cube:Destroy()
		task.wait(0.3)
		spawnCube() -- 1個消えたら1個補充
	end)

	cube.Parent = cubesFolder
end

-- 浮遊アニメーション（全キューブをゆっくり上下＆回転）
RunService.Heartbeat:Connect(function()
	for _, cube in cubesFolder:GetChildren() do
		if cube:IsA("BasePart") then
			cube.CFrame = cube.CFrame * CFrame.Angles(0, math.rad(0.5), 0)
		end
	end
end)

-- プレイヤー参加時にスコアを初期化
Players.PlayerAdded:Connect(function(player)
	scores[player] = 0
end)
Players.PlayerRemoving:Connect(function(player)
	scores[player] = nil
end)

-- 初期キューブをまとめて生成
for _ = 1, GameConfig.CubeCount do
	spawnCube()
end

print(string.format("[typing3d] サーバー起動: キューブを%d個生成しました", GameConfig.CubeCount))
