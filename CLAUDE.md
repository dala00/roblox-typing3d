# typing3d

Roblox の 3D タイピングゲーム（開発初期）。Rojo で Studio と接続して開発する。

## 重要: 公開リポジトリ

このリポジトリは**公開**されている。以下をコミット・ドキュメントに含めない:

- フォルダのフルパス（例: `D:\users\...`、`C:\Users\<名前>\...`）。パスを書くときはリポジトリルートからの相対パス（`src/server/...`）にする。
- ユーザー名・メールアドレス・PC 名などの個人情報やマシン固有情報。
- API キー・トークン・認証情報。
- ローカル環境に依存する設定（ローカル絶対パスを含む `settings.json` など）。

コミット前に diff を確認し、上記が混入していないかチェックすること。

## ツールチェーン

- **Rojo 7.6.1**（`rokit.toml` で管理）。Rokit がツールのバージョンを固定する。
- 言語は **Luau**（`.luau` 拡張子）。型チェックを使うファイル先頭に `--!strict` を付ける。
- エディタは VS Code 想定。Rojo の Luau LSP のために sourcemap を使う場合は `rojo sourcemap default.project.json -o sourcemap.json --watch`（`sourcemap.json` は gitignore 済み）。

## 開発フロー（Rojo + Studio）

1. ターミナルで `rojo serve` を起動（このリポジトリのルートで）。
2. Studio 側の Rojo プラグインで **Connect**。以降 `src/` の変更を保存すると Studio に即同期される。
3. Studio で **Play (F5)** して挙動を確認。`print` は **Output** ウィンドウに出る（View → Output）。
4. ゼロからプレイスファイルを作るには `rojo build -o "typing3d.rbxlx"`（生成物は gitignore 済み）。

注意: Rojo は `src/` → Studio の**一方向同期**。Studio 上で直接編集した内容はファイルに戻らない。コードは必ず `src/` 側を編集する。

## プロジェクト構造（`default.project.json` のマッピング）

| ファイルパス | Studio 上の場所 | 用途 |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` | サーバー/クライアント共有モジュール |
| `src/server/` | `ServerScriptService.Server` | サーバースクリプト |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` | クライアントスクリプト |

- `init.server.luau` → そのフォルダ自体が **Script**（サーバー実行）になる。
- `init.client.luau` → そのフォルダ自体が **LocalScript**（クライアント実行）になる。
- それ以外の `*.luau` は **ModuleScript**。`require()` で読み込む。
- `default.project.json` には Baseplate / Lighting / SoundService などの初期インスタンスも定義済み。シーンの初期状態を変えたいときはここを編集する。

## 規約・知見

- 共有設定は `ReplicatedStorage.Shared` のモジュールにまとめ、サーバー/クライアント両方から `require` する（例: `GameConfig.luau`）。マジックナンバーを直書きしない。
- サーバー→クライアントの通知は `RemoteEvent` を `ReplicatedStorage` に動的生成し、クライアントは `WaitForChild` で待ち受ける。クライアントは生成タイミングに依存しないこと。
- スコアなどの権威ある状態は**サーバーで保持**し、クライアントには結果だけ送る（クライアントを信用しない）。
- ログは `[typing3d]` プレフィックスを付けると Output で追いやすい。サーバー/クライアント双方の起動ログを出しておくと Rojo 同期の確認になる。
- 毎フレーム処理は `RunService.Heartbeat`。クリック操作は `ClickDetector.MouseClick`（引数に押した Player が渡る）。

## 現状

Godot 版 3D タイピング（`godot/typing-3d`）からの移植 MVP を実装済み。アバターが巨大キーボードの上を走り、お題の次の文字キーへ移動して**ジャンプ着地で打鍵**する。1 人用。

- 操作は **Roblox 標準**（WASD 移動＋SPACE ジャンプ）。タンク操作ではなく、キャラはプレイヤーのアバターそのまま。
- ワールド生成・ゲームロジック・判定は**すべてクライアント側で完結**（各プレイヤー自分のワールド）。サーバーは起動ログのみ。スコア保存やランキングを足すときに権威ロジックをサーバーへ。
- ファイル構成:
  - `src/shared/GameConfig.luau` 寸法・スコア・色・単語リストなど定数。
  - `src/client/Keyboard.luau` 暗い部屋＋机＋キーボード 26 キーを生成。キー位置/Part/ラベルを返す。発光は **Neon マテリアル**＋`SurfaceGui`(`LightInfluence=0`)で表現（Roblox に Bloom ポストプロセスは無い）。
  - `src/client/Hud.luau` ScreenGui（お題の済/次/未入力を RichText 色分け・スコア・LV/時間・中央ポップ）。
  - `src/client/Sounds.luau` 効果音。**Roblox は実行時 PCM 合成不可**なので Sound アセット方式。ID 未設定でも無音で安全に動く（後で `rbxassetid` を入れる）。
  - `src/client/init.client.luau` アバター配置・ゲームループ・着地打鍵判定・スコア・ゲームオーバー/リトライ。
- 着地判定は `Humanoid.StateChanged` の `Landed` を拾い、`HumanoidRootPart` の XZ から `StompRadius` 内の最寄りキーを「踏んだ」とする。

### 未対応（素材待ち。Godot 版にあるが Roblox では後回し）

- 効果音 ID（`Sounds.luau` の `Ids` が空 = 無音）。BGM（DOVA 素材はライセンス都合で持ち込まない想定）。
- ディスプレイの発光画像・部屋の 360° パノラマ背景（画像アップロード＆審査が要るため省略。暗い部屋＋ライティングで雰囲気のみ再現）。
- 凝った机上小物・runner.glb 由来の専用キャラ（アバター流用で代替）。
