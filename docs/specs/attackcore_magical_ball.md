# 攻撃コア（魔法）追加 仕様テンプレート

新しいプレイヤー攻撃コアを追加するときに埋めるフォーム。
`docs/blessing_magic_enchantment_gauge_design.md`（システム設計）と `CLAUDE.md`「Adding New Attack Patterns」（新パターン型の実装手順）の前段に位置する。

**使い方**：本ファイルをコピーして `docs/specs/attackcore_<id>.md` として埋める → 設計レビュー → 実装。
未確定は「TBD」と書く（空欄にしない）。`※` は記入時のガイド。

---

## 0. メタ情報

| 項目 | 値 | ※ |
|---|---|---|
| コアID | `attackcore_magical_ball` | `resources/data/attackcore_<name>.tres` のファイル名＋`id` と一致させる |
| 表示名 | マジカルボール| `display_name`。既存はカタカナ短名（エネルギーショット / ファイアボール / バリアオーブ …） |
| 説明文 | 画面端でバウンドする弾を発射します。| `description`。インベントリ表示用。1〜2文 |
| アイコン | `assets/gfx/sprites/icon_magic_magical_ball.png` | |
| 弾スプライト | `assets/gfx/sprites/bullet_magical_ball.png` | ビームなら beam 用アセット |
| 発射SE | なし| `BulletVisualConfig.spawn_sound`。無しなら「なし」 |

## 1. コンセプト

- **一言で**：バウンドによる不規則な挙動と残留時間の長さでダメージゾーンを広げる
- **プレイヤー体験の役割**：扇状にランダム発射されるため、狙った敵に的確に当てることは難しいが、弾は長時間残留するため、敵の移動先に撒いておくなどの戦略的な使い方ができる。
- **既存コアとの差別化**：重力、バウンドを使う初めての攻撃パターン

| 既存コア | 型 | damage_base | cooldown | 特徴 |
|---|---|---|---|---|
| エネルギーショット | SINGLE_SHOT | 1.0 | 0.2 | 高速直進・高連射 |
| ファイアボール | SINGLE_SHOT | 5.0 | 1.0 | 低速・単発重火力 |
| バブルショット | RAPID_FIRE | 2.0 | 1.0 | 低速カーブ弾を連射 |
| バリアオーブ | BARRIER_BULLETS | 2.0 | 5.0 | 自機周回→直進、貫通1 |
| ビーム | BEAM | 1.0 | 2.0 | 持続ダメージ |
| トリプルバースト | BURST_WITH_TRACKING | 3.0 | 0.1 | 弾が消えるまで撃てない高速3連 |
| エレキショック | SHOT_ON_HIT | 5.0 | 0.3 | 着弾時に拡散弾 |

- **想定される組み合わせ**：
  - 速射：単純なDPS向上
  - 貫通、残留：弾の残留時間を活かしてヒット数を増やす

## 2. 挙動仕様

| 項目 | 値 | 選択肢（`.tres` に書く整数） |
|---|---|---|
| `pattern_type` | 0 | 0 SINGLE_SHOT / 1 RAPID_FIRE / 2 BARRIER_BULLETS / 3 SPIRAL / 4 BEAM / 5 CUSTOM / 6 BURST_WITH_TRACKING / 7 SHOT_ON_HIT |
| `direction_type` | 2 | 0 FIXED / 1 TO_PLAYER / 2 RANDOM / 3 CIRCLE / 4 CUSTOM / 5 TO_OWNER |
| `base_direction` | `Vector2(0, -1)` | プレイヤーは基本 `Vector2(0, -1)` |
| `angle_spread` / `angle_offset` | 45 / 0 | 扇状の広がり（度）。`bullet_count>1` のとき効く |
| `spawn_position_mode` | 0 | 0 OWNER / 1 FIXED_ABSOLUTE / 2 RELATIVE_TO_OWNER / 3 RELATIVE_TO_TARGET / 4 CUSTOM |
| `bullet_movement_config.movement_type` | 5 | 0 STRAIGHT / 1 DECELERATE / 2 ACCELERATE / 3 SINE_WAVE / 4 HOMING / 5 GRAVITY / 6 SPIRAL |
| `bullet_lifetime` | 3.5 | 0 は無限。エンチャント「残留」は **0 だと効かない** |
| `penetration_count` | 2 | 0 なし / n 回 / -1 無限 |
| `target_group` | `enemies` | プレイヤー弾は固定。HOMING の索敵グループも兼ねる |

- **1発射サイクルの流れ**：発射→弾が画面端でバウンド→敵に当たる／寿命切れ（3.5秒）で**破裂エフェクトを出して**消滅
  ただし、上向きに発射した場合は重力方向が上になり、下向きに発射した場合は重力方向が下になる。
  - 意図：重力を常に下向きにすると弾が画面下に溜まり、上側の敵に当てにくくなる。本作は後方発射（`FairyContainer.set_rear_firing_mode()`）で攻撃方向を上下に切り替えられるため、重力方向も追従させて弾が片側に寄る問題を解消する。
  - 帰結：重力が発射方向と同じなので弾は**放物線を描かず、撃った方向へ加速し続ける**。「奥の壁まで加速 → バウンド → 減速して停止 → 再び壁へ加速」という往復運動になる。`bounce_factor = 1.0` だと毎回発射地点の高さまで戻って画面を縦断してしまうため、**反発係数は1未満**にして弾を奥の壁際に収束させる。
- **弾の見た目・回転**：FIXED
- **画面外・持続**：`persist_offscreen = true` ／ `max_offscreen_distance = 2000.0` ／ `forced_lifetime = 16.0`
  - **安全弁として `true` にする**（当初の想定より必要性は低い）。
    - 当初は「`super._process` の画面外判定がバウンド処理より前に走るので画面外に出た弾は消える」「判定帯は内側4pxしかなく高速だと飛び越える」と整理していたが、いずれも正確ではなかった。
      - バウンド判定は `global_position.y <= play_rect.position.y + bounce_margin` という**半空間判定**なので、どれだけオーバーシュートしても取りこぼさない。
      - さらに GRAVITY は `speed = 0` で `_velocity` 一本に移動を集約したため、`super._process()` の `position += direction * speed * delta` は何も動かさない。画面外判定が見るのは前フレームのバウンドでクランプ済みの位置であり、`max_bounces = 0`（無制限）なら弾は画面外の位置で観測されない。
    - それでも `true` を採用する理由：`max_bounces > 0` に変更すると `_handle_boundary_bounce()` が早期 return してクランプされなくなり、その瞬間に `false` だと即消滅する。加えて `forced_lifetime` を有効化できる（迷子弾の上限）。

### 2.2 消失エフェクト

バブルショットと同じ `ExplosionConfig`（パーティクル拡散・`explosion_duration = 0.5`）を `bullet_visual_config.explosion_config` に設定し、弾が「弾けて」消えるようにする。`explosion_damage = 0` / `explosion_radius = 0` なので**見た目のみでバランスには影響しない**。

- 発火経路は2つ。敵ヒットで貫通を使い切ったとき（`_immediate_removal()`）と、寿命切れのとき（`_start_fade_out()` → `_finalize_bullet_removal()`）。どちらも `_create_explosion_effect()` を通る
- **`fade_out_duration` は 0.0 にする**。0 より大きいと弾がフェードで消えきってから破裂エフェクトが出るため、「弾けた」ではなく「消えたあとに何か出た」ように見える
  - `forced_lifetime` は `persist_offscreen = true` のとき最優先で `queue_free()` する上限値。**`bullet_lifetime` より短いと寿命を切り詰めてしまう**ため、残留Lv3（+200% → 10.5秒）を通す前提で 16.0 とする（10章の未決事項も参照）。

### 2.1 `bullet_movement_config` 設定値

| パラメータ | 値 | 意味 |
|---|---|---|
| `movement_type` | 5（GRAVITY） | |
| `initial_speed` | 250.0 | `base_modifiers.bullet_speed` と一致させる（9章の落とし穴） |
| `gravity_strength` | 600.0 | |
| `gravity_direction` | `Vector2(0, 1)` | `gravity_follows_direction = true` のときはフォールバック値としてのみ使用 |
| `gravity_follows_direction` | true（**新設フラグ**） | 弾の初期進行方向のY符号から重力方向を決める。既定 false で既存挙動を維持 |
| `air_resistance` | 0.0 | |
| `bounce_factor` | 0.8 | **0だとバウンド処理自体が呼ばれない**（`UniversalBullet._process()` の分岐条件）。X軸にも適用される |
| `max_bounces` | 0 | 0 = 無制限 |
| `rotation_mode` | 2（FIXED） | |

**想定軌道**（プレイ領域 896×960px、上向き発射、扇の端 22.5°の弾）

- 初速の内訳：縦 231px/s ／ 横 96px/s
- 上端到達まで **約1.45秒**、到達時の縦速度 約1098px/s
- 反発で跳ね返り、減速して折り返して再び上端へ戻る
- 折り返し幅は毎回 `bounce_factor^2` 倍に縮む（速度が `bounce_factor` 倍 → 距離は v² 比）
- 横方向は96px/sで流れ、左右の壁（896px幅）でも反射する

**実装での実測**（`tests/unit/MagicalBallFeatureTest.gd` で固定）

上の想定は弾が画面最下部（y=960）から昇る前提で計算していた。実際のプレイヤー初期位置は y=748 なので登り距離が短くなる。

| | 想定（y=960 起点） | 実測（y=748 起点・真上発射） |
|---|---|---|
| 上端到達 | 1.45秒 | **1.22秒** |
| 到達時の縦速度 | 1098px/s | **982px/s** |
| 反発後の折り返し幅 | 251px | **201px** |
| 寿命5秒中の上端帯滞在 | 約3.5秒(70%) | 約4.0秒(81%) |

離散シミュレーション（60fps）で想定条件（y=960）を再現すると 1.43秒 / 1101px/s / 248px となり、想定値と一致する。差は起点の違いのみ。

**反発係数による挙動の違い**（y=748 起点・扇の端22.5°・寿命5秒）

| `bounce_factor` | 折り返し幅の推移 | 上端251px帯の滞在 | 上端反射回数 |
|---|---|---|---|
| 0.5 | 192 → 47 → 11 → 2px | 81% | 48回 |
| **0.8（採用）** | **496px** | **32%** | **2回** |
| 1.0 | 778px（減衰なし） | 22% | — |

0.5 では数回の反射で上端に張り付き毎フレーム微小な反射を繰り返す（速度が0へ収束）。**採用値 0.8 では弾が画面を大きく縦断し、寿命5秒で上端反射は2回に留まる**。「奥の壁際に居座る」よりも「画面を縦に往復する」挙動に寄り、ダメージゾーンが縦に広く分布する。

横方向は壁に当たるまで減衰しない（`air_resistance = 0`）。ただし横96px/s で中央 x=448 から左右の壁まで448pxあり到達に約4.67秒かかるため、**寿命5秒のうち左右の壁に触れるのは1回程度**。`bounce_factor` はX軸にも適用されるので、当たれば横成分も同率で減衰する。

## 3. 数値設計

| パラメータ | 値 | 反映先 |
|---|---|---|
| `damage_base` | 3 | → `pattern.damage` |
| `cooldown_sec_base` | 1.5 | → `pattern.burst_delay`（＝実クールダウン） |
| `base_modifiers.bullet_speed` | 250 | → `pattern.bullet_speed`（`initial_speed` と同値） |
| その他 `base_modifiers` | 不要（重力・反発の値は `bullet_movement_config` 側に持たせる） | 例：`spread_bullet_count`（SHOT_ON_HIT用） |

- **理論DPS**：`damage_base ÷ cooldown_sec_base` ＝ **2.0**（1ヒット時／既存最低）／ 既存比較：エネルギーショット 5.0、ファイアボール 5.0、エレキショック 16.7
- **命中期待込みの実効DPS**：**上限 6.0**（貫通2＝1発あたり最大3ヒット）。ただし `direction_type = RANDOM` で命中が確率的なうえ、バウンドによる同一敵への再ヒットも絡むため、**机上で期待値を出せない。実測して `damage_base` を後調整する前提**（10章）
- **速射Lv3（-75%）適用時**：CT **0.375** → DPS **8.0**（1ヒット基準）／最大24.0（3ヒット基準） ※ 下限は `max(cooldown, 0.02)`

## 4. エンチャント適合

既存の攻撃コア向け5種が「効く／効かない」を明示する。効かないキーがあるのは可（意図の明記が必要）。

| エンチャント | キー | このコアでの挙動 | 期待する強さ |
|---|---|---|---|
| 速射 | `cooldown_pct` |◯| 主力。ただし寿命5秒に対しCTが縮むため滞留弾が急増する（8.1の負荷確認対象） |
| 増輪 | `bullet_count_add` | ◯ | 主力。`angle_spread 45°` の扇内にランダム配置され、面の制圧力が上がる |
| 貫通 | `penetration_add` |◯| 強い。バウンドで同一敵に再進入するため、ヒット数に乗りやすい |
| 残留 | `bullet_lifetime_pct` | ◯ | 強い。Lv3で寿命10.5秒。`forced_lifetime = 16.0` が実質の上限 |
| 炸裂 | `spread_bullet_count_add` | ✕ | 対象外（`on_hit_pattern` なし） |

- **新規エンチャントキーが必要か**：不要
  - 必要な場合：キー名 `____`、集計箇所（`PlayerAttackPatternFactory.update_pattern_from_enchantments()` への追記）、tier値 Lv1/2/3
  - `docs/blessing_magic_enchantment_gauge_design.md` 3.5 の追加手順に従う

## 5. HUDゲージ

- スタイル：`cooldown`（攻撃コア標準。`AttackCoreBase._ready()` が `init_gauge("cooldown",100,0,...)`）
- 標準から外す必要があるか：不要（理由：弾の滞留状況は画面上の弾そのもので可視化されるため、ゲージはCT表示のみで足りる）

## 6. 実装コスト判定

| 判定 | 結果 |
|---|---|
| 既存 `PatternType` で表現できるか | **できる**（SINGLE_SHOT。バウンド・重力は弾側の責務であり、攻撃コアの発射・CT処理は既存のまま） |
| 既存 `BulletMovementConfig` で表現できるか | **できない**（GRAVITY は存在するが下記3点が不足） |
| GDScript の変更が必要か | 必要（弾側のみ） |

**GRAVITY の既存実装で不足している点**

1. **二重移動**：`ProjectileBullet._process()` が `position += direction * speed * delta` を無条件で加算し、`_update_gravity()` も `position += _velocity * delta` を加算する。`_velocity` は `direction * speed` で初期化されるため初速が実質2倍になっている。
2. **バウンドで等速成分が反転しない**：`_handle_boundary_bounce()` は GRAVITY のとき `_velocity` のみ反転させるが、`direction * speed` の等速成分は残る。奥の壁で跳ね返っても等速成分が壁向きのままで、**弾が壁に張り付く**。
3. **重力方向を発射方向に追従させる手段がない**：`gravity_direction` は `BulletMovementConfig` のエクスポートで、パターン内のサブリソースは全弾・全個体で共有される。弾ごとに書き換えると同装備の他個体にも波及する（エレキショックの `on_hit_pattern` と同じ浅いコピー問題）。

> 既存で GRAVITY を使っている3箇所（`BossDollAI` / `enemy_flower_b.tscn` / `single_shot_circle_gravity.tres`）は**すべて `bounce_factor = 0.0`** のため、GRAVITY×バウンドは本作で前例のない未検証パスである。

**変更点**（ファイル：内容）

不足点1・2および既存3箇所の移行は **Step1（コミット `1ef0f7c`）で完了済み**。本コアの実装で追加したのは不足点3の解消のみ。

- `scripts/core/BulletMovementConfig.gd`：`@export var gravity_follows_direction: bool = false` を追加（既定 false で既存挙動を維持）
- `scripts/core/UniversalBullet.gd`：
  - 弾ごとの `_gravity_dir: Vector2` を追加。`apply_movement_config()` で `gravity_follows_direction` が true なら `Vector2(0, signf(direction.y))`、false なら `movement_config.gravity_direction` を採用（共有リソースは書き換えない）
  - Y成分が0（真横発射）のときは `signf` が 0 になるため `gravity_direction` にフォールバックする
  - `_update_gravity()` が `movement_config.gravity_direction` ではなく `_gravity_dir` を参照
- ~~`apply_movement_config()` の GRAVITY 分岐で `speed = 0.0`~~ → Step1 で実施済み
- ~~既存GRAVITY 3箇所の `initial_speed` 2倍化~~ → Step1 で実施済み（`BossDollAI` 450→900、`enemy_flower_b.tscn` 200→400、`single_shot_circle_gravity.tres` 200→400）。60fps/144fps で240フレーム分を数値検証し最大差 1.9e-11 px を確認
- `scripts/core/AttackPattern.gd`：**変更不要**
- `scripts/core/UniversalAttackCore.gd`：**変更不要**
- `scripts/core/PlayerAttackPatternFactory.gd`：**変更不要**

> 新 `PatternType` を足す場合は `CLAUDE.md`「Adding New Attack Patterns」の手順（enum追加 → `_pattern_executors` 登録 → `_validate_firing_conditions` → 実行関数）を必ず通す。本コアは新 `PatternType` を足さないため、この手順は不要。

## 7. 成果物チェックリスト

- [◯] `assets/gfx/sprites/bullet_magical_ball.png`
- [◯] `assets/gfx/sprites/icon_magic_magical_ball.png`
- [x] `resources/data/attackcore_magical_ball.tres`
- [x] `resources/data/default_player_save.json` に `inventory.attack_core` エントリ追加（`uid` はユニークに）
  - 無エンチャント／残留Lv2／速射Lv2＋貫通Lv1 の3個体
- [ ] （ドロップさせる場合）`resources/itemdrop/` のドロップテーブル／`enchantmentrule_*.tres` の `pool`
- [x] `tests/unit/MagicalBallFeatureTest.gd`（15件）
- [x] スクリプト変更に対するテスト更新
- [x] 既存GRAVITY 3箇所の `initial_speed` 2倍化（Step1 で完了）

## 8. テスト観点

- [ ] `.tres` がエラーなくロードできる（`ExtResource` 参照になっているか。パス文字列直書きは失敗する）
- [ ] インベントリに表示され装備できる
- [ ] 発射・クールダウンが仕様どおり
- [ ] エンチャント適用後の値（3章・4章の数値）が一致
- [ ] 弾の見た目・初期回転が正しい（1フレーム目の向き崩れなし）
- [ ] 画面端／敵密集／敵ゼロの状況で破綻しない
- [ ] 加護のCT倍率（背水「必死」等）と併用して下限 1/60 秒を割らない

### 8.1 マジカルボール固有

ユニットテスト済み（`tests/unit/MagicalBallFeatureTest.gd`）:

- [x] 上端・下端・左右の**4辺すべて**で反射すること
- [x] 上向き発射で重力が上向き、後方発射（下向き）で下向きになること
- [x] 斜め発射でも重力は真上／真下（Y符号のみを見る）
- [x] Y成分が0のとき `gravity_direction` にフォールバックすること
- [x] 弾が壁に張り付かないこと（反射位置にクランプ→壁から離れていく）
- [x] 反発係数どおりに速度が減衰すること
- [x] 2.1節の想定軌道と実装が一致すること（上端到達1.22秒 / 到達時982px/s）
- [x] **共有 movement_config を書き換えないこと**（上撃ちと下撃ちの弾が互いの重力方向を壊さない）
- [x] `gravity_follows_direction` 既定 false で従来どおり `gravity_direction` を使うこと（回帰）
- [x] `single_shot_circle_gravity.tres` がフラグ無効かつ Step1 の移行値（400）を保っていること
- [x] 消失時の破裂エフェクトが設定されていること（`explosion_config` あり / `fade_out_duration = 0` / ダメージ0）
- [x] `forced_lifetime` が残留Lv3適用後の寿命（10.5秒）を切り詰めないこと

実機で確認が必要:

- [ ] 弾が画面外で消滅しないこと（`persist_offscreen` の実挙動）
- [ ] 貫通2の消費のされ方（同一敵へのバウンド再ヒットを含めて何回で消えるか）
- [ ] 速射Lv3＋増輪Lv3＋残留Lv3 の同時適用時の滞留弾数と描画・当たり判定の負荷
- [ ] プレイヤー弾が敵弾と見分けられること（滞留数が多いため）
- [ ] 既存GRAVITY 3箇所（`BossDollAI` / `enemy_flower_b` / `single_shot_circle_gravity`）の弾道が変わっていないこと
- [ ] 実効DPSの実測（10章）

**テスト環境の注意**：ヘッドレスのビューポートは 64x64 で、`PlayArea.get_play_rect()` が幅の負な矩形 `Rect2(0, 0, -320, 64)` を返すためバウンド判定が成立しない。`MagicalBallFeatureTest` は `before_test` で `PlayArea._play_rect` を実機相当の `Rect2(0, 0, 896, 960)` に差し替え、`after_test` で復元している。

## 9. 既知の落とし穴（記入不要・確認用）

- `.tres` のリソース参照は必ず `ExtResource("id")`。`"res://..."` 文字列だとロード失敗する。
- `bullet_movement_config` を指定すると `UniversalBullet.apply_movement_config()` が `speed = movement_config.initial_speed` で上書きする。**`pattern.bullet_speed`（＝`base_modifiers.bullet_speed`）は効かなくなる**ので、両方に同じ値を書くこと。
- 逆に `bullet_movement_config` 未指定なら `universal_bullet.tscn` のデフォルト movement_config はコア側でクリアされる（初期回転バグ対策）。
- `bullet_lifetime = 0` は「無限」。この場合エンチャント「残留」は無効（ファクトリが 0 のまま返す）。
- `bullet_count` は最低1にクランプ、クールダウンは最低 0.02 秒にクランプされる。
- SHOT_ON_HIT の `on_hit_pattern` は `duplicate()` の浅いコピー経路を通るため、拡散弾数は `base_modifiers.spread_bullet_count` を基準値として持たせる。

## 10. 未決事項

- **実効DPSの実測**：`direction_type = RANDOM` ＋ バウンド再ヒットで期待値が机上計算できない。理論DPS 2.0 は既存最低なので、実測後に `damage_base`（3→4）または `cooldown_sec_base`（1.5→1.2）で引き上げる余地を残す。
- **滞留弾数の許容ライン**：速射Lv3（CT 0.375秒）＋増輪Lv3（7発）＋残留Lv3（寿命10.5秒）で理論上196発が同時に存在しうる。`forced_lifetime` を 16.0 より短く設定して残留の上限を意図的に切る案も含めて、実測後に判断する。
- **`rotation_mode = FIXED` でよいか**：ボールが無回転で跳ねる見た目になる。転がり感を出すなら `SELF_ROTATION`＋`angular_velocity` に変更する。
- ~~**仕様ファイル名**~~：解決。コアID `attackcore_magical_ball` に合わせて本ファイルを `attackcore_magical_ball.md` へリネームした。
