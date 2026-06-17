--!strict
-- サーバー・クライアント両方から参照する共有設定。
-- ReplicatedStorage.Shared.GameConfig として両方からrequireできる。

local GameConfig = {
	-- 同時に浮かべておくキューブの数
	CubeCount = 8,

	-- キューブが出現する範囲（Baseplate中心からの広がり）
	SpawnRadius = 24,
	SpawnHeightMin = 6,
	SpawnHeightMax = 20,

	-- キューブのサイズと出題に使う文字
	CubeSize = 4,
	Letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",

	-- クリック1回ぶんの得点
	PointsPerHit = 10,
}

return GameConfig
