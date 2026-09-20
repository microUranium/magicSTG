# 攻撃コア（魔法）追加 仕様テンプレート

新しいプレイヤー攻撃コアを追加するときに埋めるフォーム。
`docs/blessing_magic_enchantment_gauge_design.md`（システム設計）と `CLAUDE.md`「Adding New Attack Patterns」（新パターン型の実装手順）の前段に位置する。

**使い方**：本ファイルをコピーして `docs/specs/attackcore_<id>.md` として埋める → 設計レビュー → 実装。
未確定は「TBD」と書く（空欄にしない）。`※` は記入時のガイド。

---

## 0. メタ情報

| 項目 | 値 | ※ |
|---|---|---|
| コアID | `attackcore_____` | `resources/data/attackcore_<name>.tres` のファイル名＋`id` と一致させる |
| 表示名 | | `display_name`。既存はカタカナ短名（エネルギーショット / ファイアボール / バリアオーブ …） |
| 説明文 | | `description`。インベントリ表示用。1〜2文 |
| アイコン | `assets/gfx/sprites/icon_magic_____.png` | |
| 弾スプライト | `assets/gfx/sprites/bullet_____.png` | ビームなら beam 用アセット |
| 発射SE | | `BulletVisualConfig.spawn_sound`。無しなら「なし」 |

## 1. コンセプト

- **一言で**：
- **プレイヤー体験の役割**：※ 何を得て何を失う装備か（例：狙わなくていい代わりに単発火力が低い）
- **既存コアとの差別化**：※ 下表の空いている軸を埋めているか

| 既存コア | 型 | damage_base | cooldown | 特徴 |
|---|---|---|---|---|
| エネルギーショット | SINGLE_SHOT | 1.0 | 0.2 | 高速直進・高連射 |
| ファイアボール | SINGLE_SHOT | 5.0 | 1.0 | 低速・単発重火力 |
| バブルショット | RAPID_FIRE | 2.0 | 1.0 | 低速カーブ弾を連射 |
| バリアオーブ | BARRIER_BULLETS | 2.0 | 5.0 | 自機周回→直進、貫通1 |
| ビーム | BEAM | 1.0 | 2.0 | 持続ダメージ |
| トリプルバースト | BURST_WITH_TRACKING | 3.0 | 0.1 | 弾が消えるまで撃てない高速3連 |
| エレキショック | SHOT_ON_HIT | 5.0 | 0.3 | 着弾時に拡散弾 |

- **想定される組み合わせ**：※ どの加護／エンチャントと噛み合わせたいか

## 2. 挙動仕様

| 項目 | 値 | 選択肢（`.tres` に書く整数） |
|---|---|---|
| `pattern_type` | | 0 SINGLE_SHOT / 1 RAPID_FIRE / 2 BARRIER_BULLETS / 3 SPIRAL / 4 BEAM / 5 CUSTOM / 6 BURST_WITH_TRACKING / 7 SHOT_ON_HIT |
| `direction_type` | | 0 FIXED / 1 TO_PLAYER / 2 RANDOM / 3 CIRCLE / 4 CUSTOM / 5 TO_OWNER |
| `base_direction` | | プレイヤーは基本 `Vector2(0, -1)` |
| `angle_spread` / `angle_offset` | | 扇状の広がり（度）。`bullet_count>1` のとき効く |
| `spawn_position_mode` | | 0 OWNER / 1 FIXED_ABSOLUTE / 2 RELATIVE_TO_OWNER / 3 RELATIVE_TO_TARGET / 4 CUSTOM |
| `bullet_movement_config.movement_type` | | 0 STRAIGHT / 1 DECELERATE / 2 ACCELERATE / 3 SINE_WAVE / 4 HOMING / 5 GRAVITY / 6 SPIRAL |
| `bullet_lifetime` | | 0 は無限。エンチャント「残留」は **0 だと効かない** |
| `penetration_count` | | 0 なし / n 回 / -1 無限 |
| `target_group` | `enemies` | プレイヤー弾は固定。HOMING の索敵グループも兼ねる |

- **1発射サイクルの流れ**：※ 箇条書きで時系列に（例：発射→1.5秒追尾→直進→寿命3秒で消滅）
- **弾の見た目・回転**：※ `RotationMode`（MOVEMENT_DIRECTION / SELF_ROTATION / FIXED）
- **画面外・持続**：`persist_offscreen` / `forced_lifetime`

## 3. 数値設計

| パラメータ | 値 | 反映先 |
|---|---|---|
| `damage_base` | | → `pattern.damage` |
| `cooldown_sec_base` | | → `pattern.burst_delay`（＝実クールダウン） |
| `base_modifiers.bullet_speed` | | → `pattern.bullet_speed` |
| その他 `base_modifiers` | | 例：`spread_bullet_count`（SHOT_ON_HIT用） |

- **理論DPS**：`damage_base ÷ cooldown_sec_base` ＝ ____ ／ 既存比較：エネルギーショット 5.0、ファイアボール 5.0、エレキショック 16.7
- **命中期待込みの実効DPS**：※ 自動命中なら理論値に近い、要照準なら割り引く。ここが差別化の根拠
- **速射Lv3（-75%）適用時**：CT ____ → DPS ____ ※ 下限は `max(cooldown, 0.02)`

## 4. エンチャント適合

既存の攻撃コア向け5種が「効く／効かない」を明示する。効かないキーがあるのは可（意図の明記が必要）。

| エンチャント | キー | このコアでの挙動 | 期待する強さ |
|---|---|---|---|
| 速射 | `cooldown_pct` | | |
| 増輪 | `bullet_count_add` | ※ `angle_spread` が 0 だと弾が重なるだけになる | |
| 貫通 | `penetration_add` | | |
| 残留 | `bullet_lifetime_pct` | ※ `bullet_lifetime > 0` が前提 | |
| 炸裂 | `spread_bullet_count_add` | ※ `on_hit_pattern` がある場合のみ | |

- **新規エンチャントキーが必要か**：必要／不要
  - 必要な場合：キー名 `____`、集計箇所（`PlayerAttackPatternFactory.update_pattern_from_enchantments()` への追記）、tier値 Lv1/2/3
  - `docs/blessing_magic_enchantment_gauge_design.md` 3.5 の追加手順に従う

## 5. HUDゲージ

- スタイル：`cooldown`（攻撃コア標準。`AttackCoreBase._ready()` が `init_gauge("cooldown",100,0,...)`）
- 標準から外す必要があるか：不要／必要（理由：____）

## 6. 実装コスト判定

| 判定 | 結果 |
|---|---|
| 既存 `PatternType` で表現できるか | できる（型：____）／できない |
| 既存 `BulletMovementConfig` で表現できるか | できる（型：____）／できない |
| GDScript の変更が必要か | 不要（`.tres` のみ）／必要 |

**必要な場合の変更点**（ファイル：内容）
- `scripts/core/AttackPattern.gd`：
- `scripts/core/UniversalAttackCore.gd`：
- `scripts/core/PlayerAttackPatternFactory.gd`：

> 新 `PatternType` を足す場合は `CLAUDE.md`「Adding New Attack Patterns」の手順（enum追加 → `_pattern_executors` 登録 → `_validate_firing_conditions` → 実行関数）を必ず通す。

## 7. 成果物チェックリスト

- [ ] `assets/gfx/sprites/bullet_____.png`
- [ ] `assets/gfx/sprites/icon_magic_____.png`
- [ ] `resources/data/attackcore_____.tres`
- [ ] `resources/data/default_player_save.json` に `inventory.attack_core` エントリ追加（`uid` はユニークに）
- [ ] （ドロップさせる場合）`resources/itemdrop/` のドロップテーブル／`enchantmentrule_*.tres` の `pool`
- [ ] `tests/unit/` にテスト追加
- [ ] スクリプト変更がある場合はテスト更新

## 8. テスト観点

- [ ] `.tres` がエラーなくロードできる（`ExtResource` 参照になっているか。パス文字列直書きは失敗する）
- [ ] インベントリに表示され装備できる
- [ ] 発射・クールダウンが仕様どおり
- [ ] エンチャント適用後の値（3章・4章の数値）が一致
- [ ] 弾の見た目・初期回転が正しい（1フレーム目の向き崩れなし）
- [ ] 画面端／敵密集／敵ゼロの状況で破綻しない
- [ ] 加護のCT倍率（背水「必死」等）と併用して下限 1/60 秒を割らない

## 9. 既知の落とし穴（記入不要・確認用）

- `.tres` のリソース参照は必ず `ExtResource("id")`。`"res://..."` 文字列だとロード失敗する。
- `bullet_movement_config` を指定すると `UniversalBullet.apply_movement_config()` が `speed = movement_config.initial_speed` で上書きする。**`pattern.bullet_speed`（＝`base_modifiers.bullet_speed`）は効かなくなる**ので、両方に同じ値を書くこと。
- 逆に `bullet_movement_config` 未指定なら `universal_bullet.tscn` のデフォルト movement_config はコア側でクリアされる（初期回転バグ対策）。
- `bullet_lifetime = 0` は「無限」。この場合エンチャント「残留」は無効（ファクトリが 0 のまま返す）。
- `bullet_count` は最低1にクランプ、クールダウンは最低 0.02 秒にクランプされる。
- SHOT_ON_HIT の `on_hit_pattern` は `duplicate()` の浅いコピー経路を通るため、拡散弾数は `base_modifiers.spread_bullet_count` を基準値として持たせる。

## 10. 未決事項

- 
