--!strict
-- サーバー本体。3Dタイピングは1人用で、ワールド生成・ゲームロジック・判定は
-- すべてクライアント側(各プレイヤー自分のワールド)で完結する。
-- サーバーは現状、起動ログのみ。将来スコア保存(DataStore)やランキングを
-- 入れるときにここへRemoteEvent経由の権威ロジックを足す。

local Players = game:GetService("Players")

Players.CharacterAutoLoads = true

Players.PlayerAdded:Connect(function(plr)
	print(string.format("[typing3d] %s が参加", plr.Name))
end)

print("[typing3d] サーバー起動: タイピング(クライアント駆動)")
