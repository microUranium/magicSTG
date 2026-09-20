# 攻撃コア（魔法）追加 仕様：ニードルショット

`docs/attack_core_spec_template.md` を元に記入。
`docs/blessing_magic_enchantment_gauge_design.md`（システム設計）と `CLAUDE.md`「Adding New Attack Patterns」（新パターン型の実装手順）の前段に位置する。

---

## 0. メタ情報

| 項目 | 値 | ※ |
|---|---|---|
| コアID | `attackcore_needleshot` | `resources/data/attackcore_<name>.tres` のファイル名＋`id` と一致させる |
| 表示名 | ニードルショット | `display_name` |
| 説明文 | 敵に持続的にダメージを与える針状の弾を発射します。 | `description`。インベントリ表示用 |
| アイコン | `assets/gfx/sprites/icon_magic_needleshot.png` | 作成済み |
| 弾スプライト | `assets/gfx/sprites/bullet_needleshot.png` | 作成済み |
| 発射SE | なし | `BulletVisualConfig.spawn_sound` |

## 1. コンセプト

- **一言で**：ダメージ効率が敵の当たり判定の大きさに依存する。ボスなどの大型の敵向き
- **プレイヤー体験の役割**：直進かつ連射性能が低いが、敵に当たると持続的にダメージを与える。狙いを定めて撃つ必要があるが、命中すれば高DPSを発揮する。
- **既存コアとの差別化**：弾に「滞在時間」というリソースを持たせた初のコア。無限貫通なので縦一列をまとめて削る
  - **差別化の上限は実測で約2倍**：当たり判定の縦幅はボス 126〜182px に対し雑魚 66〜70px。弾の当たり判定半径をどう動かしてもこの比は 1.9〜2.1倍から動かない。「大型に2倍効く」というトーンが実態に合う

| 既存コア | 型 | damage_base | cooldown | 特徴 |
|---|---|---|---|---|
| エネルギーショット | SINGLE_SHOT | 1.0 | 0.2 | 高速直進・高連射 |
| ファイアボール | SINGLE_SHOT | 5.0 | 1.0 | 低速・単発重火力 |
| バブルショット | RAPID_FIRE | 2.0 | 1.0 | 低速カーブ弾を連射 |
| バリアオーブ | BARRIER_BULLETS | 2.0 | 5.0 | 自機周回→直進、貫通1 |
| ビーム | BEAM | 1.0 | 2.0 | 持続ダメージ |
| トリプルバースト | BURST_WITH_TRACKING | 3.0 | 0.1 | 弾が消えるまで撃てない高速3連 |
| エレキショック | SHOT_ON_HIT | 5.0 | 0.3 | 着弾時に拡散弾 |
| **ニードルショット** | **SINGLE_SHOT + 接触tick** | **2.0** | **1.5** | **接触中 2F毎にダメージ。無限貫通** |

- **想定される組み合わせ**：
  - 速射：単純なDPS向上（唯一の主力エンチャント）
  - 接近／背水（加護）：与ダメージ補正が tick ごとに乗るため相性が良い

## 2. 挙動仕様

| 項目 | 値 | 選択肢（`.tres` に書く整数） |
|---|---|---|
| `pattern_type` | 0（SINGLE_SHOT） | 0 SINGLE_SHOT / 1 RAPID_FIRE / 2 BARRIER_BULLETS / 3 SPIRAL / 4 BEAM / 5 CUSTOM / 6 BURST_WITH_TRACKING / 7 SHOT_ON_HIT |
| `direction_type` | 0（FIXED） | 0 FIXED / 1 TO_PLAYER / 2 RANDOM / 3 CIRCLE / 4 CUSTOM / 5 TO_OWNER |
| `base_direction` | `Vector2(0, -1)` | プレイヤーは基本 `Vector2(0, -1)` |
| `angle_spread` / `angle_offset` | 0 / 0 | `bullet_count > 1` のとき効く。本コアは 1 固定運用（4章） |
| `spawn_position_mode` | 0（OWNER） | 0 OWNER / 1 FIXED_ABSOLUTE / 2 RELATIVE_TO_OWNER / 3 RELATIVE_TO_TARGET / 4 CUSTOM |
| `bullet_movement_config.movement_type` | **2（ACCELERATE）** | 0 STRAIGHT / 1 DECELERATE / 2 ACCELERATE / 3 SINE_WAVE / 4 HOMING / 5 GRAVITY / 6 SPIRAL |
| `bullet_lifetime` | 0（無限） | エンチャント「残留」は 0 だと効かない（意図通り） |
| `bullet_range` | 0（無限） | |
| `penetration_count` | -1（無限） | tick モードでは参照されない（6章）が、フォールバックとして -1 を明記する |
| `target_group` | `enemies` | プレイヤー弾は固定 |

- **1発射サイクルの流れ**：
  1. プレイヤー位置から真上へ 200px/s で発射
  2. `acceleration_rate = 600` で 500px/s まで加速（0.5秒／175pxで上限到達）
  3. 敵の当たり判定に触れている間は**速度が 200px/s に固定**され、`contact_damage_tick_sec = 1/30` 秒ごとに `damage` を与える
  4. 敵から抜けると 200px/s から再加速
  5. 画面外に出て消滅（`bullet_lifetime = 0` / `persist_offscreen = false` なので消滅条件は画面外判定のみ）

- **弾の見た目・回転**：`MOVEMENT_DIRECTION`。方向は常に真上なので回転は不変
- **画面外・持続**：`persist_offscreen = false` ／ `max_offscreen_distance`・`forced_lifetime` は未使用
  - `true` にすると `bullet_lifetime = 0` と組み合わさって弾が永久残留するため**必ず false**

### 2.1 新設パラメータ

| パラメータ | 置き場所 | 値 | 意味 |
|---|---|---|---|
| `contact_damage_tick_sec` | `AttackPattern` | `1.0 / 30.0` | 接触中のダメージ間隔（秒）。**0 = 無効＝従来の進入時1回ダメージ**。既定 0 なので既存パターンは無変更 |
| `contact_speed` | `BulletMovementConfig` | `200.0` | 敵に接触している間に強制する速度。**0 = 無効**。既定 0 なので既存弾は無変更 |

- **敵が縦に重なっている／連続している場合も 200px/s のまま貫く**（接触対象が1体でも残っていれば上書きが続く）。無限貫通と合わせて、縦一列の雑魚をまとめて削る挙動になる
- **時間ベースで実装すること**（フレーム数で数えない）。`project.godot` に `max_fps` / `vsync` の指定がないため `_process` はモニタのリフレッシュレートで回る。フレームカウンタだと 144Hz 環境で火力が 2.4 倍になる
- 累積方式（`_contact_tick_accum += delta` → 間隔を超えた分だけ tick）にする。フレーム落ち時に tick が飛ばないうえ、Timer ノードを弾ごとに持たずに済む（大量発射時のコスト対策）。ただし長時間のハングで `while` が暴走しないよう1フレームあたりの tick 数に上限を設ける

## 3. 数値設計

| パラメータ | 値 | 反映先 |
|---|---|---|
| `damage_base` | **2.0** | → `pattern.damage`（1 tick あたりのダメージ） |
| `cooldown_sec_base` | **1.5** | → `pattern.burst_delay`（＝実クールダウン） |
| `base_modifiers.bullet_speed` | 200 | → `pattern.bullet_speed`。`movement_config.initial_speed` と同値にする（9章） |
| `bullet_movement_config.initial_speed` | 200.0 | 発射速度 |
| `bullet_movement_config.acceleration_rate` | **600.0** | **既定の 50.0 では 200→500 に6秒かかり加速が見えない** |
| `bullet_movement_config.max_speed` | 500.0 | |
| `bullet_movement_config.contact_speed` | 200.0 | 接触中の固定速度 |
| `bullet_visual_config.collision_radius` | 6.0 | 小さいほど「敵のサイズ依存」が純化する |
| `contact_damage_tick_sec` | 1/30 | |

### 理論DPS

本コアは tick 型なので `damage_base ÷ cooldown_sec_base` の式は意味を持たない（1.33 になる）。正しい式は:

```
接触中DPS    = damage × (1 / contact_damage_tick_sec) = 2 × 30 = 60 DPS
1発のダメージ = damage × floor( (敵の縦幅 + 弾半径×2) ÷ contact_speed ÷ tick )
実効DPS      = 1発のダメージ ÷ cooldown_sec_base
```

### 実測当たり判定に基づく実効DPS（`damage 2` / `contact_speed 200` / `r 6` / CT 1.5）

| 対象 | 縦幅 | 通過距離 | 滞在 | tick数 | 1発 | 実効DPS | 3スロット |
|---|---|---|---|---|---|---|---|
| ボス bear (r53 h182) | 182 | 194px | 0.97s | 29 | 58 | **38.7** | 116.0 |
| ボス doll (r30 h144) | 144 | 156px | 0.78s | 23 | 46 | **30.7** | 92.0 |
| ボス spider (r59 h135) | 135 | 147px | 0.73s | 22 | 44 | 29.3 | 88.0 |
| ボス devil (r28 h126) | 126 | 138px | 0.69s | 20 | 40 | 26.7 | 80.0 |
| ボス snake (circle r48) | 96 | 108px | 0.54s | 16 | 32 | 21.3 | 64.0 |
| 雑魚 44×70 | 70 | 82px | 0.41s | 12 | 24 | **16.0** | 48.0 |
| 雑魚 42×66 | 66 | 78px | 0.39s | 11 | 22 | 14.7 | 44.0 |

- **比較基準はビーム**。ビームは `damage 1 × 30tick/s = 30 DPS/体`、かつ `cooldown_sec 2.0` / `beam_duration 2.0` で CT が発射時点から走る（`AttackCoreBase._start_cooldown()`）ため**実質常時オン・無照準・射線上の全員**に 30 DPS。tick 型どうしなのでここが唯一の正しい比較対象（テンプレートの「エレキショック 16.7」は単発型の値）
- ニードルショットはボスで 27〜39 DPS、雑魚で 15〜16 DPS。**ボスでビームと同格、雑魚では半分**という位置付け。照準が要る代償として大型に寄せた形
- **CT は唯一の調整ノブ**。`damage` は整数なので 2→1 では半減してしまい細かく下げられない

| CT | ボス doll | 雑魚 44×70 | 位置付け |
|---|---|---|---|
| 1.0 | 46.0 | 24.0 | ビームを大きく超える（過剰） |
| **1.5** | **30.7** | **16.0** | **ビーム同格（採用）** |
| 2.0 | 23.0 | 12.0 | エレキショック(16.7)寄りに落としたい場合 |

### 速射適用時

| | CT | ボス doll DPS | 3スロット |
|---|---|---|---|
| なし | 1.5 | 30.7 | 92.0 |
| 速射Lv1 (-20%) | 1.20 | 38.3 | 115.0 |
| 速射Lv2 (-50%) | 0.75 | 61.3 | 184.0 |
| 速射Lv3 (-75%) | 0.375 | 122.7 | 368.0 |

下限は `max(cooldown, 0.02)`（`PlayerAttackPatternFactory`）。加護のCT倍率（背水「必死」）と併用しても `AttackCoreBase` 側で 1/60 秒にクランプされる。

### damage_base を 2 にした理由（1 ではなく）

加護の与ダメージ補正は `int(round(base_damage * (1.0 + bonus)))`（`BlessingContainer.process_outgoing_damage()`）。`damage_base = 1` だと **bonus が 50% 未満のとき丸めで消える**ため、接近（最大 +50%）・背水（最大 +150%）がほぼ死ぬ。2 なら bonus 25% から反応する。

## 4. エンチャント適合

| エンチャント | キー | このコアでの挙動 | 対応 |
|---|---|---|---|
| 速射 | `cooldown_pct` | ◯ 主力。CT が唯一の火力ノブなので素直に効く | pool に入れる |
| 増輪 | `bullet_count_add` | **機構上は効く（✕ではない）**。ただし `angle_spread = 0` なので弾が完全に重なり、接触tick×無限貫通で**素直にN倍DPS**になる（Lv3 = 7本 = 7倍） | **pool から除外** |
| 貫通 | `penetration_add` | **構造的に無効**。tick モードでは `BulletBase._on_area_entered()` のダメージ・貫通判定経路を通らないため `penetration_count` を誰も読まない（6章）。付いても無害 | 念のため pool から除外 |
| 残留 | `bullet_lifetime_pct` | ✕ `bullet_lifetime = 0`（無限）なのでファクトリが 0 のまま返す。意図通り | — |
| 炸裂 | `spread_bullet_count_add` | ✕ `on_hit_pattern` なし | — |

- **新規エンチャントキー**：不要

### 除外の実装

`DropTableEntry` は `prototype`（アイテム）と `enchant_rule` が1対1で、`LootSystem._roll_enchantments()` は `entry.enchant_rule.pool` からしか抽選しない。したがって **`droptableentry_needleshot.tres` に専用の `enchantmentrule_needleshot.tres`（`pool` は `cooldown_pct` のみ）を紐付けるだけ**でよく、コード変更は不要。既存の `enchantmentrule_debug_bullet.tres` は使い回さない。

- `default_player_save.json` は `LootSystem` を通らないので、手置き個体に増輪／貫通を付けないこと
- 「-1 に `penetration_add` を加算して有限化する」という根本の挙動（`PlayerAttackPatternFactory.update_pattern_from_enchantments()`）は本コアでは無害化されるが、**他コアで `penetration_count = -1` を使うと同じ穴を踏む**。別途の課題として残す

## 5. HUDゲージ

- スタイル：`cooldown`（攻撃コア標準。`AttackCoreBase._ready()` が `init_gauge("cooldown",100,0,...)`）
- 標準から外す必要があるか：不要（理由：接触中の滞在は弾の位置そのもので可視化されるため、ゲージはCT表示のみで足りる）

## 6. 実装コスト判定

| 判定 | 結果 |
|---|---|
| 既存 `PatternType` で表現できるか | **できる**（SINGLE_SHOT。接触tickは弾側の責務で、コアの「いつ・どこに・何発」は既存のまま） |
| 既存 `BulletMovementConfig` で表現できるか | **できない**（ACCELERATE はあるが「接触中だけ速度を固定する」手段がない） |
| GDScript の変更が必要か | **必要**（弾側のみ。新 `PatternType` は不要） |

### 変更点

- **`scripts/core/AttackPattern.gd`**
  - `@export var contact_damage_tick_sec: float = 0.0` を追加（0 = 無効）
- **`scripts/core/BulletMovementConfig.gd`**
  - `@export var contact_speed: float = 0.0` を追加（0 = 無効）
- **`scripts/core/BulletBase.gd`**
  - `contact_damage_tick_sec: float = 0.0` / `_contact_targets: Array[Node] = []` / `_contact_tick_accum: float = 0.0` を追加
  - `_ready()` で `area_exited` を接続（現状は `area_entered` のみ）
  - `_on_area_entered()`：`target_group` に属する相手を `_contact_targets` に追加。**tick モード（`contact_damage_tick_sec > 0`）のときはダメージ適用と貫通判定をスキップ**する。`on_hit_pattern`（SHOT_ON_HIT）の発火は「初回接触イベント」なので従来どおり残す
  - `_on_area_exited()`：`_contact_targets` から除去
  - `_update_contact_damage(delta)` を追加。累積が `contact_damage_tick_sec` を超えた回数だけ `_contact_targets` 全員に `take_damage(_resolve_damage(target))`。無効インスタンスは毎tickで除去
- **`scripts/player/ProjectileBullet.gd`**
  - `_process()` の先頭で `_update_contact_damage(delta)` を呼ぶ
  - ※ `BulletBase` に `_process()` を新設してはいけない。`ProjectileBullet._process()` は `super._process()` を呼んでいないため呼ばれない
- **`scripts/core/UniversalBullet.gd`**
  - `_update_advanced_movement()` の `match` の**後**に、`movement_config.contact_speed > 0 and not _contact_targets.is_empty()` なら `speed = movement_config.contact_speed` を適用
  - ※ `UniversalBullet._process()` は `super._process(delta)`（＝移動）→ `_update_advanced_movement()`（＝速度更新）の順なので、接触検知から減速反映まで**1フレームの遅れ**が出る。500px/s で約8pxの過剰進入に相当するので許容する
- **`scripts/core/UniversalAttackCore.gd`**
  - `_spawn_bullet()` で `if "contact_damage_tick_sec" in bullet: bullet.contact_damage_tick_sec = pattern.contact_damage_tick_sec`
- **`scripts/core/PlayerAttackPatternFactory.gd`**：変更不要

### 既存挙動への影響

両方の新パラメータが既定 0（無効）なので、既存の `.tres` / シーンは無変更で従来どおり動く。

- **`continuous_damage` を流用してはいけない**。このフラグは現状どこからも読まれていない死んだフラグだが、`enemy_fugu_a.tscn` と `enemy_piranha.tscn` が**弾パターンに対して `true`** を設定している。`UniversalBullet` がこれを見るようにすると、その2体の弾が突然持続ダメージを獲得する。

### 当たり判定の形状に関する注意

`UniversalBullet._apply_visual_settings()` は `collision_radius > 0` のとき **必ず `CircleShape2D`** を作る。針の長いスプライトを使っても当たり判定は円なので、**スプライトの長さは滞在時間に一切影響しない**。「長い針だから長く刺さる」を成立させたい場合は `CapsuleShape2D` に対応させる別途の変更が必要（今回はスコープ外）。

## 7. 成果物チェックリスト

- [x] `assets/gfx/sprites/bullet_needleshot.png`
- [x] `assets/gfx/sprites/icon_magic_needleshot.png`
- [ ] `scripts/core/AttackPattern.gd` に `contact_damage_tick_sec`
- [ ] `scripts/core/BulletMovementConfig.gd` に `contact_speed`
- [ ] `scripts/core/BulletBase.gd` の接触tick機構
- [ ] `scripts/player/ProjectileBullet.gd` の `_update_contact_damage()` 呼び出し
- [ ] `scripts/core/UniversalBullet.gd` の `contact_speed` 上書き
- [ ] `scripts/core/UniversalAttackCore.gd` の `contact_damage_tick_sec` 受け渡し
- [ ] `resources/data/attackcore_needleshot.tres`（**未作成**）
- [ ] `resources/data/default_player_save.json` に `inventory.attack_core` エントリ追加（`uid` はユニークに）
  - 無エンチャント／速射Lv2／速射Lv3 の3個体（増輪・貫通は付けない）
- [ ] `resources/itemdrop/droptableentry_needleshot.tres`
- [ ] `resources/itemdrop/enchantmentrule_needleshot.tres`（`pool` は `cooldown_pct` のみ）
- [ ] `tests/unit/` にテスト追加
- [ ] スクリプト変更に対するテスト更新

## 8. テスト観点

- [ ] `.tres` がエラーなくロードできる（`ExtResource` 参照になっているか。パス文字列直書きは失敗する）
- [ ] インベントリに表示され装備できる
- [ ] 発射・クールダウンが仕様どおり（CT 1.5）
- [ ] エンチャント適用後の値（3章・4章の数値）が一致
- [ ] 弾の見た目・初期回転が正しい（1フレーム目の向き崩れなし）
- [ ] 画面端／敵密集／敵ゼロの状況で破綻しない
- [ ] 加護のCT倍率（背水「必死」等）と併用して下限 1/60 秒を割らない

### 8.1 ニードルショット固有

- [ ] 接触中に `contact_damage_tick_sec` 間隔でダメージが入る（進入時1回だけになっていない）
- [ ] **フレームレート非依存**：異なる `delta` で 1秒あたりの tick 数が 30 に保たれる
- [ ] 接触中に速度が 200px/s に落ち、抜けると再加速する
- [ ] **敵が縦に重なった／連続した場合も 200px/s のまま貫通し続ける**
- [ ] 縦一列に並べた敵全員にダメージが入る（無限貫通）
- [ ] 1発のダメージが 3章の表と一致する（doll で 46、雑魚44×70 で 24）
- [ ] **貫通エンチャントを手動で付けても挙動が変わらない**（tick モードで `penetration_count` が参照されないことの確認）
- [ ] 敵が tick 中に撃破された場合に `_contact_targets` から除去され、無効インスタンスへの `take_damage()` が起きない
- [ ] 弾が画面外で消滅する（`persist_offscreen = false` の確認。永久残留しないこと）
- [ ] 接近／背水の与ダメージ補正が tick ごとに乗る
- [ ] 既存弾（`contact_damage_tick_sec = 0` / `contact_speed = 0`）の挙動が一切変わっていないこと
  - 特に `enemy_fugu_a` / `enemy_piranha`（`continuous_damage = true` を持つ）の弾が持続ダメージ化していないこと
- [ ] 速射Lv3（CT 0.375）で滞留弾が増えたときの当たり判定・tick 処理の負荷

## 9. 既知の落とし穴（記入不要・確認用）

- `.tres` のリソース参照は必ず `ExtResource("id")`。`"res://..."` 文字列だとロード失敗する。
- `bullet_movement_config` を指定すると `UniversalBullet.apply_movement_config()` が `speed = movement_config.initial_speed` で上書きする。**`pattern.bullet_speed`（＝`base_modifiers.bullet_speed`）は効かなくなる**ので、両方に同じ値を書くこと。
- 逆に `bullet_movement_config` 未指定なら `universal_bullet.tscn` のデフォルト movement_config はコア側でクリアされる（初期回転バグ対策）。
- `bullet_lifetime = 0` は「無限」。この場合エンチャント「残留」は無効（ファクトリが 0 のまま返す）。
- `bullet_count` は最低1にクランプ、クールダウンは最低 0.02 秒にクランプされる。
- SHOT_ON_HIT の `on_hit_pattern` は `duplicate()` の浅いコピー経路を通るため、拡散弾数は `base_modifiers.spread_bullet_count` を基準値として持たせる。
- `ProjectileBullet._ready()` の減速tween（`speed > min_speed` で `min_speed` まで補間）は、`UniversalBullet._ready()` が `super._ready()` を先に呼ぶ構造上、判定時点の `speed` がシーン既定の 500、`min_speed` も 500 になるため**コア経由の弾では発火しない**。`max_speed` に 500 超の値を置いても問題ない。

## 10. 未決事項

- **`damage_base` が整数で刻みが粗い**：2 → 1 では半減してしまう。微調整は `cooldown_sec_base` か `contact_speed` で行う（`contact_speed` を上げると滞在が短くなり火力が下がる）。
- **CT 1.5 はビーム基準**。ビーム（30 DPS/体・常時・無照準・射線上全員）自体が既存コア群（5〜17 DPS）から大きく外れているため、ビームを過剰と判断するなら CT 2.0（ボス 23／雑魚 12）に落とす。実測後に判断する。
- **雑魚密集列での上振れ**：無限貫通＋接触中 200px/s 固定なので、縦に並んだ雑魚5体（間隔100px）を約4.2秒かけて貫き、その間ダメージを与え続ける。ユーザー判断でこの挙動は許容する方針だが、実プレイでの掃討力を確認する。
- **`CapsuleShape2D` の向き**：3章の通過距離は当たり判定カプセルが縦向き（height が Y 軸方向）である前提。シーン側で回転しているボスがいれば数値を再計算する。
- **針の長さが当たり判定に反映されない**：6章末尾の通り当たり判定は円固定。見た目と挙動の乖離が気になる場合は `CapsuleShape2D` 対応を別課題として立てる。
