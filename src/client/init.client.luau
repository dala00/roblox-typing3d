--!strict
-- 画面にスコアを表示し、サーバーからのScoreUpdateを受けて更新する。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- スコア表示用のScreenGuiを組み立てる
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScoreHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(260, 80)
frame.Position = UDim2.new(0.5, 0, 0, 16)
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.2
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.4, 0)
title.BackgroundTransparency = 1
title.Text = "SCORE"
title.TextColor3 = Color3.fromRGB(150, 150, 170)
title.Font = Enum.Font.GothamMedium
title.TextScaled = true
title.Parent = frame

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(1, 0, 0.6, 0)
scoreLabel.Position = UDim2.fromScale(0, 0.4)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Text = "0"
scoreLabel.TextColor3 = Color3.fromRGB(120, 230, 255)
scoreLabel.Font = Enum.Font.FredokaOne
scoreLabel.TextScaled = true
scoreLabel.Parent = frame

-- サーバーからのスコア更新を待ち受ける
local scoreEvent = ReplicatedStorage:WaitForChild("ScoreUpdate") :: RemoteEvent

scoreEvent.OnClientEvent:Connect(function(newScore: number)
	scoreLabel.Text = tostring(newScore)

	-- 得点時にラベルをポンと拡大させて気持ちよく
	scoreLabel.TextColor3 = Color3.fromRGB(255, 240, 120)
	local tween = TweenService:Create(
		scoreLabel,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextColor3 = Color3.fromRGB(120, 230, 255) }
	)
	tween:Play()
end)

print(string.format("[typing3d] クライアント起動: キューブをクリックすると%d点入ります", GameConfig.PointsPerHit))
