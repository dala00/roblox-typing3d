--!strict
-- Creator Store のアセット(マウス/コップ/スマホ)を InsertService で読み込み、
-- 机上の所定位置に配置する。サーバー実行(LoadAssetはサーバー専用)。
-- 配置情報は GameConfig.AssetProps。読込に失敗してもその小物が出ないだけ。

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local AssetProps = {}

-- 全パーツを固定(落下・衝突しない置物にする)
local function freeze(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	if root:IsA("BasePart") then
		root.Anchored = true
		root.CanCollide = false
		root.CanTouch = false
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

	if obj:IsA("Model") then
		-- 最大寸法を spec.size に合わせて縮尺
		local _, bsize = obj:GetBoundingBox()
		local maxDim = math.max(bsize.X, bsize.Y, bsize.Z)
		if maxDim > 0 then
			obj:ScaleTo(spec.size / maxDim)
		end
		-- 机上に底面を乗せ、鉛直軸まわりに回転。pivotとAABB中心のズレを補正して
		-- AABB中心を目標位置へ正確に置く。
		local centerCF, size2 = obj:GetBoundingBox()
		local rel = centerCF:Inverse() * obj:GetPivot()
		local y = deskTop + size2.Y / 2 + spec.yOffset
		local desiredCenter = CFrame.new(spec.x, y, spec.z) * CFrame.Angles(0, math.rad(spec.rotY), 0)
		obj:PivotTo(desiredCenter * rel)
	elseif obj:IsA("BasePart") then
		local y = deskTop + obj.Size.Y / 2 + spec.yOffset
		obj.CFrame = CFrame.new(spec.x, y, spec.z) * CFrame.Angles(0, math.rad(spec.rotY), 0)
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
