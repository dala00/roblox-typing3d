--!strict
-- サーバー本体。3Dタイピングは1人用で、ワールド生成・ゲームロジック・判定は
-- すべてクライアント側(各プレイヤー自分のワールド)で完結する。
-- サーバーは現状、起動ログのみ。将来スコア保存(DataStore)やランキングを
-- 入れるときにここへRemoteEvent経由の権威ロジックを足す。

local Players = game:GetService("Players")

Players.CharacterAutoLoads = true

-- テンプレート由来の星のスポーンパッドなど、Rojo管理外で残った
-- 不要なSpawnLocationを実行時に掃除する(管理下の "SpawnPad" は残す)。
for _, inst in workspace:GetDescendants() do
	if inst:IsA("SpawnLocation") and inst.Name ~= "SpawnPad" then
		inst:Destroy()
	end
end

Players.PlayerAdded:Connect(function(plr)
	print(string.format("[typing3d] %s が参加", plr.Name))
end)

print("[typing3d] サーバー起動: タイピング(クライアント駆動)")
