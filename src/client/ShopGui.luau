--!strict
-- 課金ボタン。商品は薬1種だけなので、パネルは作らず「ボタン＝購入」。
-- 押すと onBuy(init.client の promptPotion = 購入ダイアログ)を呼ぶ。

local ShopGui = {}

function ShopGui.new(parent: Instance, onBuy: () -> (), iconId: string?)
	local hasIcon = iconId ~= nil and iconId ~= ""

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = parent

	-- 右端中央(上下のHUD・モバイルのジャンプボタンと被らない位置)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(76, 100)
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, -14, 0.5, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	-- 購入ボタン(丸・緑)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(72, 72)
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 0)
	button.BackgroundColor3 = Color3.fromRGB(70, 200, 120)
	button.AutoButtonColor = true
	button.Text = if hasIcon then "" else "+1:00"
	button.TextSize = 18
	button.Font = Enum.Font.FredokaOne
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(180, 255, 200)
	stroke.Parent = button

	if hasIcon then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(0.66, 0.66)
		img.Position = UDim2.fromScale(0.17, 0.17)
		img.BackgroundTransparency = 1
		img.Image = iconId :: string
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = button
	end

	-- 何が買えるか分かるよう、ボタン下に説明
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.new(1, 0, 0, 22)
	caption.Position = UDim2.new(0, 0, 0, 76)
	caption.BackgroundTransparency = 1
	caption.Text = "+1:00"
	caption.TextSize = 16
	caption.Font = Enum.Font.FredokaOne
	caption.TextColor3 = Color3.fromRGB(160, 255, 190)
	caption.TextStrokeTransparency = 0.4
	caption.TextStrokeColor3 = Color3.fromRGB(10, 40, 20)
	caption.Parent = holder

	button.Activated:Connect(onBuy)

	return gui
end

return ShopGui
