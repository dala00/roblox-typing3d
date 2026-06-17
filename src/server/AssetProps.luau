--!strict
-- Creator Store のアセット(マウス/コップ/スマホ)を InsertService で読み込み、
-- 机上の所定位置に配置する。サーバー実行(LoadAssetはサーバー専用)。
-- 配置情報は GameConfig.AssetProps。読込に失敗してもその小物が出ないだけ。

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local AssetProps = {}

-- パーツを固定し、光りすぎ(Neon/高反射)を鎮める
local function tamePart(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Reflectance = 0
	-- 自発光・鏡面っぽい素材は通常素材へ落とす
	if p.Material == Enum.Material.Neon or p.Material == Enum.Material.ForceField or p.Material == Enum.Material.Glass then
		p.Material = Enum.Material.SmoothPlastic
	end
end

local function freeze(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			tamePart(d)
		end
	end
	if root:IsA("BasePart") then
		tamePart(root)
	end
end

local DESK_TOP = GameConfig.DeskY - 1 -- 机の天面y

-- LoadAsset失敗時の代替プリミティブ
local function buildFallback(folder: Folder, spec)
	local fb = spec.fallback
	if fb == nil then
		return
	end
	local p = Instance.new("Part")
	p.Name = "Prop_" .. spec.name .. "_fallback"
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Color = fb.color
	p.Material = fb.material or Enum.Material.SmoothPlastic
	if fb.kind == "cylinder" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(fb.h, fb.d, fb.d)
		local y = DESK_TOP + fb.h / 2 + spec.yOffset
		-- Z周りに90°で縦置き＋鉛直軸の向き
		p.CFrame = CFrame.new(spec.x, y, spec.z) * CFrame.Angles(0, math.rad(spec.rotY), 0) * CFrame.Angles(0, 0, math.rad(90))
	else
		p.Shape = Enum.PartType.Block
		p.Size = fb.size
		local y = DESK_TOP + fb.size.Y / 2 + spec.yOffset
		p.CFrame = CFrame.new(spec.x, y, spec.z) * CFrame.Angles(0, math.rad(spec.rotY), 0)
	end
	p.Parent = folder
end

local function placeOne(folder: Folder, spec)
	local deskTop = DESK_TOP

	local ok, container = pcall(function()
		return InsertService:LoadAsset(spec.assetId)
	end)
	if not ok or container == nil then
		print(string.format("[typing3d] アセット読込不可 %s (%s) → 代替表示", spec.name, tostring(container)))
		buildFallback(folder, spec)
		return
	end

	local obj = container:GetChildren()[1]
	if obj == nil then
		warn("[typing3d] アセットが空: " .. spec.name .. " → 代替表示")
		container:Destroy()
		buildFallback(folder, spec)
		return
	end
	obj.Name = "Prop_" .. spec.name
	freeze(obj)

	local rot = CFrame.Angles(math.rad(spec.rotX or 0), math.rad(spec.rotY or 0), math.rad(spec.rotZ or 0))

	if obj:IsA("Model") then
		-- 最大寸法を spec.size に合わせて縮尺
		local _, bsize = obj:GetBoundingBox()
		local maxDim = math.max(bsize.X, bsize.Y, bsize.Z)
		if maxDim > 0 then
			obj:ScaleTo(spec.size / maxDim)
		end
		-- まず向きだけ適用(原点で)
		obj:PivotTo(rot)
		-- 回転後の有向BBから、世界AABBの高さ半分を求めて底面を机に乗せる。
		-- 水平中心(=BB中心)を (x, z) に合わせる。
		local obbCF, obbSize = obj:GetBoundingBox()
		local halfH = obbSize.X / 2 * math.abs(obbCF.RightVector.Y)
			+ obbSize.Y / 2 * math.abs(obbCF.UpVector.Y)
			+ obbSize.Z / 2 * math.abs(obbCF.LookVector.Y)
		local desired = Vector3.new(spec.x, deskTop + halfH + spec.yOffset, spec.z)
		obj:PivotTo(obj:GetPivot() + (desired - obbCF.Position))
	elseif obj:IsA("BasePart") then
		local s = obj.Size
		local halfH = s.X / 2 * math.abs(rot.RightVector.Y)
			+ s.Y / 2 * math.abs(rot.UpVector.Y)
			+ s.Z / 2 * math.abs(rot.LookVector.Y)
		obj.CFrame = CFrame.new(spec.x, deskTop + halfH + spec.yOffset, spec.z) * rot
	end

	obj.Parent = folder
	container:Destroy()
	print("[typing3d] 置物を配置: " .. spec.name)
end

function AssetProps.spawnAll()
	local folder = Instance.new("Folder")
	folder.Name = "AssetProps"
	folder.Parent = workspace
	for _, spec in GameConfig.AssetProps do
		task.spawn(placeOne, folder, spec)
	end
end

return AssetProps
