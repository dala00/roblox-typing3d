--!strict
-- 効果音。Godot版はPCM合成だったが、Robloxは実行時PCM生成ができないので
-- Soundアセット(rbxassetid)を鳴らす方式にする。
--
-- まだ音アセットを決めていないので、ID未設定でも「無音で安全に動く」ようにしてある。
-- 後で Ids の各値に rbxassetid を入れれば鳴る(例: "rbxassetid://9120386436")。

local SoundService = game:GetService("SoundService")

local Sounds = {}

-- name -> rbxassetid。空文字なら無音(放置でOK)。
local Ids: { [string]: string } = {
	jump = "", -- ジャンプ音は無し
	stomp = "", -- 着地音は無し
	ok = "rbxassetid://128170212983132", -- 正解
	err = "rbxassetid://91730465068215", -- お手つき
	clear = "", -- クリア音は無し
}

-- 事前生成してSoundServiceにぶら下げておく
local cache: { [string]: Sound } = {}

local function ensure(name: string): Sound?
	local id = Ids[name]
	if id == nil or id == "" then
		return nil
	end
	local existing = cache[name]
	if existing then
		return existing
	end
	local s = Instance.new("Sound")
	s.Name = "SFX_" .. name
	s.SoundId = id
	s.Volume = 0.5
	s.Parent = SoundService
	cache[name] = s
	return s
end

function Sounds.play(name: string)
	local s = ensure(name)
	if s then
		s:Play()
	end
end

-- ===== BGM(ループ・静かめ) =====
local BgmId = "rbxassetid://107646882617030"
local BgmVolume = 0.5 -- 既定値(0〜10、0=無音)

local bgm: Sound? = nil

function Sounds.startBgm()
	if BgmId == "" or bgm ~= nil then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "BGM"
	s.SoundId = BgmId
	s.Looped = true
	s.Volume = BgmVolume
	s.Parent = SoundService
	s:Play()
	bgm = s
end

return Sounds
