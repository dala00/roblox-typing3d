# Roblox ゲーム開発 共通知見（スキル化用メモ）

Rojo + Luau で Roblox ゲームを作るときに繰り返し使える知見。1プロジェクト（3Dタイピング）で得たものを汎用化してまとめたもの。「落とし穴 → 対処」と「再利用パターン」中心。

---

## 1. Rojo + Studio ワークフロー

- **`src/` が唯一の正**。Rojo は `src/` → Studio の **一方向同期**。Studio で直接編集してもファイルに戻らない。必ず `src/` を編集する。
- `default.project.json` が **ファイル↔Studioインスタンスのマッピング**。典型：
  - `src/shared` → `ReplicatedStorage.Shared`（共有モジュール）
  - `src/server` → `ServerScriptService.Server`
  - `src/client` → `StarterPlayer.StarterPlayerScripts.Client`
- **init スクリプトの挙動（重要）**：
  - `init.server.luau` があるフォルダ自体が **Script**、`init.client.luau` なら **LocalScript** になる。
  - **その兄弟ファイルは「そのスクリプトの子」**になる。だから `require(script.Foo)`。**`script.Parent.Foo` ではない**（よくハマる）。
- **起動**：Rojo公式VSCode拡張（`evaera.vscode-rojo`）を入れると**ステータスバーのボタン**で serve 開始/停止できて楽（タスクやキーバインド不要）。`rojo serve default.project.json` を直接叩いてもよい。
- **ゼロからプレイス生成**：`rojo build -o "name.rbxlx"`（gitignore推奨）。クラウドのプレイスが開けなくてもローカルで開発継続できる保険になる。
- `default.project.json` では Baseplate/Lighting/SoundService などの初期インスタンスも定義できる。シーンの初期状態はここで管理。
- **テンプレ残骸に注意**：Baseplateテンプレ由来の `SpawnLocation`（星マーク）等は Rojo 管理外なので消えない。対処は (a) Studio で手動削除、(b) サーバー起動時に Workspace を走査して不要インスタンスを `Destroy()`。Rojo は **project.json に書いたものから外すと同期時に消す**（管理下のもののみ）。

---

## 2. 公開・リリース運用

- **勝手に本番反映されない**。`rojo serve` も `git push` も**本番に触れない**。ライブ更新は **Studio の「Publish to Roblox」(Alt+P) だけ**。
- 更新フロー：`src/編集 → Rojo同期 → Studioでテスト →（git push）→ Publish to Roblox`。
- Publish後、**既存サーバーは旧版のまま**。新規サーバーから新版。即時反映は **Creator Hub → サーバー管理 → 全シャットダウン**。
- **バージョン履歴**があるので壊れたら**ロールバック**可能。
- 公開に必要（Creator Hub）：
  - Publish 済み
  - **Playability → Public**
  - **コンテンツ成熟度アンケート（必須）**：回答しないと公開・検索対象にできない
  - **Devices** で対応端末（PC/Phone/Tablet）を ON
  - アイコン(512×512)・サムネ
- **名前/説明のモデレーション**：自動審査が**絵文字・全部大文字・記号に過敏**。弾かれたら**プレーン文（絵文字なし・強調大文字なし）**に。名前と説明は別々に保存して切り分け。新規Experienceは厳しめ。
- 公開直後に **プレイ不可＆Studioで開けない** → だいたい**モデレーションでレビュー/停止**。Creator Hub のバナーとメールで理由確認、Appeal。**コードは git にあるので失われない**。

---

## 3. DataStore（永続化・ランキング）

- **Studio と本番は既定で同じデータ層**（「Enable Studio Access to API Services」ON時）。テスト書き込みが**本番を汚す**。
  - 対処：**`RunService:IsStudio()` でストア名に `_dev` を付ける**。
    ```lua
    local name = "Scores_v1" .. (if RunService:IsStudio() then "_dev" else "")
    ```
- **全リセットは「ストア名のバージョン上げ」** が最速（`_v1`→`_v2`）。旧データは参照されなくなるだけ。
- **OrderedDataStore は Creator Hub の DataStore Manager に出ない**ことが多い → UIから消せない。リセットはバージョン上げ or ワイプスクリプト（`GetSortedAsync` で全キー→`RemoveAsync`）。「RTBFの削除」タブは userId 個別削除用。
- ランキング：`GetOrderedDataStore` + `GetSortedAsync(false, N)` で上位取得、`UpdateAsync` で `math.max` 保存。名前は `Players:GetNameFromUserIdAsync`（pcall＋キャッシュ）。
- DataStore は**一度Publishしないと使えない**。全アクセスは `pcall` で包む。
- 値が完全クライアント計算なら**厳密検証は不可**（カジュアルは割り切り）。権威が要るならロジックをサーバーへ。

---

## 4. Luau `--!strict` 型の落とし穴

- **型エラーは解析時のみ。実行時には型注釈は剥がれる**ので、型エラーがあってもゲームは動く（＝「動くのに赤い」はだいたい型警告）。ただし**構文/パースエラーはモジュール読込ごと壊す**ので別物。
- **シールドテーブル**：中身のあるテーブルリテラルは「確定」扱い。**後から `t.x = ...` で新フィールド追加するとエラー**（"Cannot add property"）。
  - 対処：**全部を最初のリテラル内に書く**。関数やデータも。
  - 関数をリテラル内に入れるとき、**そのリテラルの local 自身はまだスコープ外**なので `GameConfig.x` を関数内から参照できない → **必要な定数を先に module-level local に出して**、関数はそれを参照する。
- **異種配列**：要素ごとに形が違う配列は、型推論が1個目から決まり2個目以降を弾く。
  - 対処：`local t: { any } = {...}`（データ配列として割り切り）。オプショナルフィールド型にすると今度は**消費側で nil チェックが連鎖**するので注意。

---

## 5. ワールドのコード生成 / 1人用設計

- **「薄いシーン＋コード生成」**：空の DataModel に対し、机/ライト/キャラ/UI 等を全部 `Instance.new` でスクリプト生成。バージョン管理しやすく、**共有 `GameConfig` モジュール**で寸法・色・パラメータを一元化（マジックナンバー直書き禁止）。
- **マルチエンジンでの1人用**：
  - 各クライアントが**自分のワールドをローカル生成**するのが単純。ローカルプレイヤーのキャラは**クライアントが network owner** なので、クライアント生成の Anchored パーツの上に普通に乗れる/当たる。
  - ただし**他プレイヤーの複製アバターは、相手のワールドが自分側に無いので宙に浮いて見える**。→ **Max Players = 1 ＋ ソーシャルスロット無効化**で各人専用サーバーにするのが正解。
  - 永続/権威データ（スコア等）だけサーバー（DataStore）に。ランキングは DataStore 共有なので人数1でも全体機能する。

---

## 6. 見た目・レンダリングの落とし穴

- **Bloom ポストプロセスは無い**。光らせたいものは **Neon マテリアル**。暗所でも明るく見せたい文字/画像は **SurfaceGui + `LightInfluence = 0`**。
- **SurfaceGui の Face**：Part の「**Front 面は -Z**」。プレイヤーは多くの場合 **+Z 側（=Back 面）**から見るので、Front に貼ると**裏（真っ黒/無地）**を見ることになる → **見る側を向く Face を選ぶ**。
- **Top 面の SurfaceGui は文字が90°寝る** → `TextLabel.Rotation` で補正。
- **GUI のピクセル上限（約32767px）**：`UDim2.fromScale(N, 1)` で巨大化させた ImageLabel（スライス技など）は上限超えで壊れ、各面にフル画像が出る「ギャラリー化」になる。→ **`SurfaceGui.PixelsPerStud` を下げて**上限内に収める。
- **画像を円柱内側に1周巻く**パターン：
  - **N枚の縦平面パネルを円状**に配置し、各パネルに**画像の 1/N 横スライス**を表示。スライスは **clipフレーム＋スケールで N倍幅の ImageLabel を -i ずらす**（ピクセル寸法不要）。
  - **内側から見ると左右反転**しやすく、反転すると**継ぎ目ごとに絵が飛ぶ**。面の向き or スライス順を片方だけ反転して合わせる（向きと順を両方変えると相殺して直らない）。
  - 360パノラマでない普通の絵は**継ぎ目が1本残る**（仕様）→ 見えない方向（ディスプレイの裏など）に回す。
  - **歪み無しの高さ = 円周 × (画像高/画像幅)**。普通の絵だと壁が極端に高くなるので、**半径を小さく**して現実的な高さに。
- **Cylinder Part**：軸はローカルX。立てるにはZ周りに90°。**内側から見るとテクスチャが裏面で出ない**ことがある → 内向きの平面パネル方式が無難。
- **起動直後だけ暗い**：動的ライトの計算立ち上がり。`Lighting.Technology = "Future"` でローカルライトが即時反映＋**環境光のベースを少し上げて**明暗差を減らす（完全には消えない＝ストリーミング待ち）。
- **真っ黒な空・星なし**：`Sky` を作り `CelestialBodiesShown = false` / `StarCount = 0`。**レガシー fog は skybox を覆わない**ので、空自体を黒くするには黒スカイボックステクスチャか囲うジオメトリが要る。

---

## 7. アセット（音・画像・モデル）

- **実行時に PCM 音声合成は不可** → **Sound アセット(rbxassetid)** を使う。ID未設定でも**無音で安全に動く**ようにフォールバック実装。
- **ID の探し方**：Studio ツールボックス（Audio/Images/Decals/Models タブ、右クリックで Copy Asset ID）／Creator Store の**URL内の数字がID**／挿入して `SoundId`/`MeshId`/`Image` プロパティを見る。
- **画像は Decal と Image の2種**ができることがあり、`ImageLabel.Image` に使うのは **Image の方**。Studio の**アセットマネージャー**から取ると表示に使えるIDが取れて安全。
- **画像は必ずアップロード＋自動モデレーション**。ツールボックスの画像は**承認済みを再利用**（IDを借りるだけ）。自作は**アセットマネージャー**からアップ（無料、数分審査）。
- **音声プライバシー**：ツールボックスの Audio タブに出るものは基本使える（古い web の ID は無効が多い）。最長7分。
- **モデルを実行時に出す**：`InsertService:LoadAsset(id)`（**サーバー側**）。
  - **"User is not authorized to access Asset"** で失敗することがある＝**所有していない/配布不可**アセット（ツールボックスのドラッグは通るが他人の `LoadAsset` は不可なことがある）。回避：一度**挿入して削除**すると所有扱いになり通ることがある。**失敗時はプリミティブで代替**を出すと壊れない。
  - 配置・縮尺：`Model:ScaleTo`、`GetBoundingBox`。**机に底面接地**は、回転後の**有向BBから世界AABBの高さ半分**を出す：
    ```lua
    local cf, size = obj:GetBoundingBox()
    local halfH = size.X/2*math.abs(cf.RightVector.Y)
                + size.Y/2*math.abs(cf.UpVector.Y)
                + size.Z/2*math.abs(cf.LookVector.Y)
    ```
  - アセットの**素の向きはバラバラ** → `rotX/rotY/rotZ` を個別指定できるようにしておくと調整が速い。光りすぎ対策に **Neon/反射を落とす**正規化も有効。

---

## 8. 入力・モバイル対応

- **プレイヤーのアバター＋標準操作**を使うと、**モバイルは移動スティック＋ジャンプボタンが自動で出る**（追加実装不要）。WASD/SPACE と等価。
- **着地/踏み判定**：`Humanoid.StateChanged` の `Landed` を拾い、`HumanoidRootPart` から半径内の最寄り対象を取る。入力方法に依存しない。
- **確定/リトライをキーボード固定にしない**：`Space` だけだとモバイルで詰む。**画面内 TextButton（`Activated` はタップ/クリック両対応）**を併用。
- **端末判定でヒント文言を切替**：`UserInputService.KeyboardEnabled`（PCはtrue、モバイルfalse）。
- **不要なコアUIを消す**：`StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList/Chat/Backpack/EmotesMenu, false)`。**タッチ操作UIは別管理なので残る**。
- **トップバー回避**：`ScreenGui.IgnoreGuiInset = false` で Roblox のトップバー（左上メニュー/右上一覧）と被らない位置に。
- 確認は Studio の**デバイスエミュレータ**で Phone/Tablet。

---

## 9. よく使うパターン / 規約

- **共有 `GameConfig` モジュール**（定数・色・寸法・単語など）を client/server 両方から `require`。クライアントは `ReplicatedStorage:WaitForChild("Shared")` で待ってから。
- **RemoteEvent** は `ReplicatedStorage` に動的生成、クライアントは `WaitForChild` で待つ（生成タイミングに依存しない）。
- **ログ接頭辞**（例 `[gamename]`）を付けると Output で追いやすい。サーバー/クライアント双方の起動ログを出すと Rojo 同期確認になる。
- 毎フレームは `RunService.Heartbeat`。
- 公開リポジトリでは**フルパス・ユーザー名・メール・APIキー・ローカル絶対パス入り settings.json をコミットしない**。`commit`/`push` はユーザー指示時のみ等の運用ルールを CLAUDE.md に明記。

---

## 10. ゲームデザイン・難易度調整

- パラメータは全部 `GameConfig` に出して**数値1つで調整**できるように。
- **連続タイマー（プラス制）**が良い感触：1本のタイマーが減り続け、正解ごとに時間加算、加算量はレベルで減衰。**序盤に速く打つほど貯金でき、終盤は貯金を取り崩す**。
- **難易度の頭打ちに注意**：「単語長の上限＋per-charの下限」だと、ある時点から**毎回同じ制限時間で一定**になり終盤が緩くなる。減衰の下限・速度で終盤まで効かせる。
- 速さを報酬に（コンボ、時間貯金）。リトライは猶予（受付ディレイ）を入れて誤連打を防ぐ。

---

## 11. マネタイズ（課金アイテム）

- **種類の選択**：
  - **何度でも買える消耗品** → **Developer Product（開発者プロダクト）**。
  - **買い切りの永続効果** → **Game Pass**。
- **購入を出す**：`MarketplaceService:PromptProductPurchase(player, productId)`（**クライアントから呼べる**）。出る購入ダイアログは**Roblox標準UI＝見た目は変えられない**（全ゲーム共通。出し方だけ自由）。
- **成立処理**：`MarketplaceService.ProcessReceipt`（**サーバー、ゲーム内で1つだけ設定可**）。
  - `Enum.ProductPurchaseDecision.PurchaseGranted` を返すまで Roblox が**再呼び出し**する（確実付与の仕組み）。
  - プレイヤー不在なら通常 `NotProcessedYet`（後で再処理）。ただし**そのセッション限定の効果**（その場で時間+等）は不在時 `PurchaseGranted` で消費扱いにする等、割り切りが必要。
- **クライアント側ロジックへ反映**：ゲームのタイマー/状態がクライアントにある場合、`ProcessReceipt` → `RemoteEvent:FireClient(plr, ...)` で本人に通知して反映。
- **落とし穴：上限丸めで課金分が消える**。無料加算に上限がある設計（例 TimeCap）で `addTime = min(cap, cur+amt)` にしていると、**課金で上限超にした直後に無料加算が走ると上限まで引き下げられて課金分が消える**。
  - 対処：無料加算は「上限まで増やすが**今より減らさない**」＝`cur = math.max(cur, math.min(cap, cur+amt))`。**課金分は上限を超えて満額保持**する（無料の貯金だけ上限）。
- **購入ダイアログ中の一時停止**：不利にならないよう、`PromptProductPurchase` を呼ぶ前に停止し、`MarketplaceService.PromptProductPurchaseFinished`（**買っても買わなくても発火**）で再開。停止しても得しない設計なら公平（フリーズ＝スコアも止まる）。
- **テスト**：Studioでは開発者プロダクト購入を**無料でシミュレート**でき、`ProcessReceipt` も走る（※プロダクトが Creator Hub に存在し、IDが正しいこと）。
- **価格は Creator Hub 側で設定**（コードに持たない・いつでも変更可）。消耗品のブーストは**衝動買いされる安さ**が回転◎（目安 10〜30 Robux、Roblox取り分 約30%）。
- **購入UXの設計**：
  - world object の ClickDetector/ProximityPrompt は**走行中に押しにくい・誤発動しやすい**。
  - 商品が1つなら**画面の購入ボタン直結**がシンプル。複数なら**ショップボタン→パネルGUI**が定番。多くのゲームは購入エリア/ショップUIを**自作**している（人気の無料UIキット/テンプレ流用も多い）。
  - 設定IDは `GameConfig` に（`ProductId=0` で販売無効＝開発中も安全）。
- **アイコン画像**：ボタンに `ImageLabel`（`Image="rbxassetid://..."`, `ScaleType=Fit`, 背景透明）。**ID未設定ならテキストにフォールバック**。角丸/縁取りは `UICorner`/`UIStroke` で“それっぽく”。
