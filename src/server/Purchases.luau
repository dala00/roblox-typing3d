--!strict
-- 課金アイテム(開発者プロダクト)の購入処理。
-- 薬(PotionProductId)を買うと、購入したプレイヤーへ時間加算を通知する。
--
-- ゲームのタイマーはクライアント側なので、サーバーは購入成立(ProcessReceipt)を
-- 受けて RemoteEvent "AddTime" でそのプレイヤーに秒数を送るだけ。
-- ※ ProcessReceipt はゲーム内で1つだけ設定できる。ここで一括管理する。

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Purchases = {}

function Purchases.start()
	local addTime = Instance.new("RemoteEvent")
	addTime.Name = "AddTime"
	addTime.Parent = ReplicatedStorage

	MarketplaceService.ProcessReceipt = function(receipt)
		-- 薬の購入
		if GameConfig.PotionProductId ~= 0 and receipt.ProductId == GameConfig.PotionProductId then
			local plr = Players:GetPlayerByUserId(receipt.PlayerId)
			if plr then
				addTime:FireClient(plr, GameConfig.PotionTimeSeconds)
			end
			-- 時間加算はそのセッション限りなので、プレイヤー不在でも消費扱いにする
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		-- 未対応のプロダクトは保留(後で処理し直される)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print("[typing3d] 課金処理を開始")
end

return Purchases
