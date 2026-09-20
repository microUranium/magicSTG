# 攻撃コア（魔法）追加 仕様テンプレート

新しいプレイヤー攻撃コアを追加するときに埋めるフォーム。
`docs/blessing_magic_enchantment_gauge_design.md`（システム設計）と `CLAUDE.md`「Adding New Attack Patterns」（新パターン型の実装手順）の前段に位置する。

**使い方**：本ファイルをコピーして `docs/specs/attackcore_<id>.md` として埋める → 設計レビュー → 実装。
未確定は「TBD」と書く（空欄にしない）。`※` は記入時のガイド。

---

## 0. メタ情報

| 項目 | 値 | ※ |
|---|---|---|
| コアID | `attackcore_boomerang` | `resources/data/attackcore_<name>.tres` のファイル名＋`id` と一致させる |
| 表示名 | ブーメラン | `display_name`。既存はカタカナ短名（エネルギーショット / ファイアボール / バリアオーブ …） |
| 説明文 | ブーメランのように戻ってくる弾を発射します。 | `description`。インベントリ表示用。1〜2文 |
| アイコン | `assets/gfx/sprites/icon_magic_boomerang.png` | |
| 弾スプライト | `assets/gfx/sprites/bullet_boomerang.png` | ビームなら beam 用アセット |
| 発射SE | なし| `BulletVisualConfig.spawn_sound`。無しなら「なし」 |

## 1. コンセプト

- **一言で**：プレイヤーの位置で弾の軌道をコントロールできる
- **プレイヤー体験の役割**：敵の配置に応じて弾の軌道を変えたり、2度ヒットさせることができるが、強みを活かすにはプレイヤーの操作が必要。
- **既存コアとの差別化**：弾が戻ってくる挙動は唯一性があるが、新規実装が必要

| 既存コア | 型 | damage_base | cooldown | 特徴 |
|---|---|---|---|---|
| エネルギーショット | SINGLE_SHOT | 1.0 | 0.2 | 高速直進・高連射 |
| ファイアボール | SINGLE_SHOT | 5.0 | 1.0 | 低速・単発重火力 |
| バブルショット | RAPID_FIRE | 2.0 | 1.0 | 低速カーブ弾を連射 |
| バリアオーブ | BARRIER_BULLETS | 2.0 | 5.0 | 自機周回→直進、貫通1 |
| ビーム | BEAM | 1.0 | 2.0 | 持続ダメージ |
| トリプルバースト | BURST_WITH_TRACKING | 3.0 | 0.1 | 弾が消えるまで撃てない高速3連 |
| エレキショック | SHOT_ON_HIT | 5.0 | 0.3 | 着弾時に拡散弾 |

- **想定される組み合わせ**：貫通でヒット数を増やしたり、増輪で弾数を増やすと単純DPSが上がる。

## 2. 挙動仕様

| 項目 | 値 | 選択肢（`.tres` に書く整数） |
|---|---|---|
| `pattern_type` | 0| 0 SINGLE_SHOT / 1 RAPID_FIRE / 2 BARRIER_BULLETS / 3 SPIRAL / 4 BEAM / 5 CUSTOM / 6 BURST_WITH_TRACKING / 7 SHOT_ON_HIT |
| `direction_type` | 0（FIXED）| 0 FIXED / 1 TO_PLAYER / 2 RANDOM / 3 CIRCLE / 4 CUSTOM / 5 TO_OWNER |
| `base_direction` | `Vector2(0, -1)`| プレイヤーは基本 `Vector2(0, -1)` |
| `angle_spread` / `angle_offset` | 30 / 0| 扇状の広がり（度）。`bullet_count>1` のとき効く |
| `spawn_position_mode` | 0| 0 OWNER / 1 FIXED_ABSOLUTE / 2 RELATIVE_TO_OWNER / 3 RELATIVE_TO_TARGET / 4 CUSTOM |
| `bullet_movement_config.movement_type` | 7（BOOMERANG・**新設**）| 0 STRAIGHT / 1 DECELERATE / 2 ACCELERATE / 3 SINE_WAVE / 4 HOMING / 5 GRAVITY / 6 SPIRAL |
| `bullet_lifetime` | 0| 0 は無限。エンチャント「残留」は **0 だと効かない** |
| `penetration_count` | 3| 0 なし / n 回 / -1 無限 |
| `target_group` | `enemies` | プレイヤー弾は固定。HOMING の索敵グループも兼ねる |

- **1発射サイクルの流れ**：発射→直進→0.75秒かけて徐々に減速し、速度が0になったらプレイヤーに追尾を始める→速度はプレイヤーの移動速度を上回る程度まで徐々に上がり、プレイヤーに追いつくと消滅する
- **弾の見た目・回転**：SELF_ROTATION（`angular_velocity = 720.0`）
- **残像**：有効（下記 2.2）
- **画面外・持続**：`persist_offscreen = true` ／ `forced_lifetime = 8.0`
  - 往路の到達距離が450pxあり、プレイヤーが上寄りにいると画面上端を越えうる。`persist_offscreen = false` だと画面外に出た瞬間 `_immediate_removal()` で消えて戻ってこない（`ProjectileBullet._process()`）。`forced_lifetime` はプレイヤー消滅時などの迷子弾の安全弁。

### 2.2 残像

回転しながら往復する弾なので、軌跡が読めるように残像を出す。既存の `AfterImage`（`scenes/effects/after_image.tscn`／弾のスプライトを複製してアルファを tween で落として自壊する Sprite2D）を流用する。

`BulletVisualConfig` に設定を追加したので、他のコアからも `.tres` だけで有効化できる。

| パラメータ | 値 | 意味 |
|---|---|---|
| `enable_afterimage` | true | **既定 false** なので既存の弾は無変更 |
| `afterimage_interval` | 0.04 | 生成間隔（秒）。時間ベースでフレームレートに依存しない |
| `afterimage_lifetime` | 0.25 | 1枚が消えるまでの時間 |
| `afterimage_color` | `Color(1, 1, 1, 0.45)` | 弾本体より薄くする |

実装上の注意点:

- **残像は弾の子にしない**。弾より寿命が長いため `get_tree().current_scene`（テスト環境では `root` にフォールバック）へ直接ぶら下げる
- `lifetime` と `modulate` は `add_child` の**前**に設定する（`AfterImage._ready()` が `lifetime` を読んで tween を張り、`modulate` はその開始値になる）
- `global_position` / `global_rotation` は `add_child` の**後**に設定する（親の変形を考慮して local へ逆算されるため、前に設定すると親に変形があるとズレる）
- 生成は `_process` の末尾（回転確定後）に行う。スプライトの向きをそのまま複製するため
- 1フレームに1枚までとし積み残しは捨てる。装飾なので間隔の1フレーム分のぶれは許容する
- 空中の弾数 × (lifetime ÷ interval) が同時存在数。3スロット・速射なしなら約30枚、速射Lv3（CT 0.25）で約110枚

### 2.1 新設する `BulletMovementConfig` パラメータ

| パラメータ | 値 | 意味 |
|---|---|---|
| `initial_speed` | 1200.0 | 発射速度。`base_modifiers.bullet_speed` と一致させる（9章の落とし穴） |
| `boomerang_outbound_time` | 0.75 | 減速して停止するまでの秒数。往路距離 = 1200×0.75÷2 = **450px** |
| `boomerang_return_accel` | 1800.0 | 帰還時の加速度（px/秒²） |
| `boomerang_return_max_speed` | 1000.0 | 帰還時の最大速度。帰還所要 約0.73秒 |
| `boomerang_catch_radius` | 24.0 | この距離までプレイヤーに近づいたら回収（`queue_free()`）。**復路の1フレーム移動量が `2 × catch_radius` を超えると回収をすり抜ける**（1000px/s で 16.7px < 48px なので余裕あり） |

- 往路：`speed = initial_speed * max(0, 1 - t / boomerang_outbound_time)`
- 復路：毎フレーム `direction` をプレイヤー方向へ更新し、`speed` を上限まで加速
- 回収時は `_immediate_removal()` を使わない（爆発エフェクトが出て「回収」に見えないため）
- プレイヤー不在（`TargetService.get_player()` が null）時は向きを維持して直進し、`forced_lifetime` で消滅
- 総飛翔時間 **約1.48秒**（往路0.75秒＋復路0.73秒）。CT 1.0秒に対し空中の滞留は1〜2発
  - テンポ調整の履歴：初期案は `initial_speed 500 / outbound_time 1.5 / return_accel 900 / return_max_speed 700` で総飛翔 2.42秒だった。往路距離は `initial_speed × outbound_time ÷ 2` なので、初速を2倍・往路時間を半分にすると飛距離375pxを保ったまま往路だけ半減できる。ただし復路0.92秒はこれでは縮まず合計1.67秒で止まるため、`return_accel` と `return_max_speed` も引き上げて 1.40秒（-42%）とした
  - 飛距離調整：その後 `initial_speed` のみ 1000→1200 とし飛距離を 375→**450px**（×1.2）に伸ばした。`outbound_time` を延ばす方法（1000 / 0.9）でも同じ450pxになるが、往路が 0.75→0.90秒に伸びて合計1.63秒になる。初速側で伸ばせば往路時間が変わらず合計は1.48秒（+75ms）で済む
  - 折り返し点は y = 748 - 450 = **298**。敵のスポーン帯（y 0〜480）に十分入る（375pxのときは y=373 で際どかった）

## 3. 数値設計

| パラメータ | 値 | 反映先 |
|---|---|---|
| `damage_base` | 3| → `pattern.damage` |
| `cooldown_sec_base` | 1| → `pattern.burst_delay`（＝実クールダウン） |
| `base_modifiers.bullet_speed` | 1200(発射時)| → `pattern.bullet_speed` |
| その他 `base_modifiers` |不要（ブーメラン固有値は `bullet_movement_config` 側に持たせる）| 例：`spread_bullet_count`（SHOT_ON_HIT用） |

- **理論DPS**：`damage_base ÷ cooldown_sec_base` ＝ **3.0**（1ヒット時）／ 既存比較：エネルギーショット 5.0、ファイアボール 5.0、エレキショック 16.7
- **命中期待込みの実効DPS**：**6.0**（往復2ヒットが設計上の基準線。エネルギーショット5.0・ファイアボール5.0と同水準）。敵密集で貫通3を使い切った場合は最大 12.0
- **速射Lv3（-75%）適用時**：CT **0.25** → DPS **24.0**（2ヒット基準。エネルギーショット同構成の20と同水準）

## 4. エンチャント適合

既存の攻撃コア向け5種が「効く／効かない」を明示する。効かないキーがあるのは可（意図の明記が必要）。

| エンチャント | キー | このコアでの挙動 | 期待する強さ |
|---|---|---|---|
| 速射 | `cooldown_pct` |◯ | 主力。ただし飛翔1.4秒に対しCTが縮むため空中の滞留弾が増える |
| 増輪 | `bullet_count_add` | ◯ | 主力。`angle_spread 30°` で扇状に開き、面の制圧力が上がる |
| 貫通 | `penetration_add` |◯ | 最重要。往復するためヒット数に乗数的に効く（10章のバランス注視項目） |
| 残留 | `bullet_lifetime_pct` | ✕(プレイヤーに衝突するまで消えない) | 対象外（意図的） |
| 炸裂 | `spread_bullet_count_add` | ✕ | 対象外 |

- **新規エンチャントキーが必要か**：不要
  - 必要な場合：キー名 `____`、集計箇所（`PlayerAttackPatternFactory.update_pattern_from_enchantments()` への追記）、tier値 Lv1/2/3
  - `docs/blessing_magic_enchantment_gauge_design.md` 3.5 の追加手順に従う

## 5. HUDゲージ

- スタイル：`cooldown`（攻撃コア標準。`AttackCoreBase._ready()` が `init_gauge("cooldown",100,0,...)`）
- 標準から外す必要があるか：不要（理由：発射から回収までの飛翔状態は弾そのものの位置で可視化されるため、ゲージはCT表示のみで足りる）

## 6. 実装コスト判定

| 判定 | 結果 |
|---|---|
| 既存 `PatternType` で表現できるか | **できる**（SINGLE_SHOT。戻る挙動は弾側の責務であり、攻撃コアの「いつ・どこに・何発生成するか」は既存のまま） |
| 既存 `BulletMovementConfig` で表現できるか | できない（`BOOMERANG` を新設する） |
| GDScript の変更が必要か | 必要（弾側のみ） |

**必要な場合の変更点**（ファイル：内容）
- `scripts/core/BulletMovementConfig.gd`：`MovementType` に `BOOMERANG`（値7）を追加＋2.1節の4パラメータを `@export`
- `scripts/core/UniversalBullet.gd`：`_update_advanced_movement()` の `match` に分岐追加＋`_update_boomerang(delta)` 実装（帰還フェーズ管理用に `_boomerang_returning: bool` を追加）
- `scripts/core/AttackPattern.gd`：**変更不要**
- `scripts/core/UniversalAttackCore.gd`：**変更不要**
- `scripts/core/PlayerAttackPatternFactory.gd`：**変更不要**

> プレイヤーとの当たり判定は追加しない。`BulletBase._on_area_entered()` は `target_group` に属する相手へ無条件で `take_damage()` を呼ぶため、プレイヤーを判定対象に含めると自弾で自機がダメージを受ける。回収は `TargetService.get_player()` との**距離判定**で行い、コリジョンレイヤーは一切変更しない。

> 新 `PatternType` を足す場合は `CLAUDE.md`「Adding New Attack Patterns」の手順（enum追加 → `_pattern_executors` 登録 → `_validate_firing_conditions` → 実行関数）を必ず通す。本コアは新 `PatternType` を足さないため、この手順は不要。

## 7. 成果物チェックリスト

- [◯] `assets/gfx/sprites/bullet_boomerang.png`
- [◯] `assets/gfx/sprites/icon_magic_boomerang.png`
- [x] `resources/data/attackcore_boomerang.tres`
- [x] `resources/data/default_player_save.json` に `inventory.attack_core` エントリ追加（`uid` はユニークに）
  - 無エンチャント／増輪Lv2／速射Lv2＋貫通Lv1 の3個体
- [ ] （ドロップさせる場合）`resources/itemdrop/` のドロップテーブル／`enchantmentrule_*.tres` の `pool`
- [x] `tests/unit/BoomerangFeatureTest.gd`（19件）
- [x] スクリプト変更に対するテスト更新

## 8. テスト観点

- [ ] `.tres` がエラーなくロードできる（`ExtResource` 参照になっているか。パス文字列直書きは失敗する）
- [ ] インベントリに表示され装備できる
- [ ] 発射・クールダウンが仕様どおり
- [ ] エンチャント適用後の値（3章・4章の数値）が一致
- [ ] 弾の見た目・初期回転が正しい（1フレーム目の向き崩れなし）
- [ ] 画面端／敵密集／敵ゼロの状況で破綻しない
- [ ] 加護のCT倍率（背水「必死」等）と併用して下限 1/60 秒を割らない

### 8.1 ブーメラン固有

ユニットテスト済み（`tests/unit/BoomerangFeatureTest.gd`）:

- [x] 往路で速度が0まで落ち、復路へ切り替わること（`boomerang_outbound_time` 境界）
- [x] 往路の到達距離が `initial_speed × outbound_time ÷ 2`
- [x] 復路でプレイヤー方向へ向き直り、`boomerang_return_max_speed` で上限クランプされること
- [x] 回収半径の内／外で削除される・されないこと
- [x] 往路では回収判定されないこと（発射直後に自機と重なっていても消えない）
- [x] プレイヤー不在時に向きを維持すること
- [x] 復路の1フレーム移動量が `2 × catch_radius` 未満（回収すり抜け防止）
- [x] プレイヤー移動速度 < `boomerang_return_max_speed`
- [x] STRAIGHT / GRAVITY が影響を受けていないこと（回帰）
- [x] 残像が既定では出ないこと（`enable_afterimage` 既定 false）
- [x] 残像が `afterimage_interval` ごとに1枚生成されること
- [x] 巨大な delta でも1フレームに1枚までであること
- [x] 残像が弾のスプライトの位置・回転・スケール・テクスチャ・色を複製すること
- [x] **弾が消えても残像が残ること**（弾の子になっていないこと）
- [x] `.tres` で残像が有効かつ弾本体より薄いこと

実機で確認が必要:

- [ ] 回収時に爆発エフェクトが出ないこと（見た目）
- [ ] プレイヤーが移動中でも回収されること
- [ ] 残像の見た目（濃さ・間隔・弾との描画順）。残像は `current_scene` に、弾は `_find_bullet_parent()` の返り値にぶら下がるため、前後関係は実機で確認する
- [ ] 折り返し地点で速度0になる間、残像が同じ位置に重なって濃く見えないか
- [ ] 画面上端を越えた弾が戻ってくること（`persist_offscreen = true` の検証）
- [ ] プレイヤー消滅（被弾死亡）時に弾が残留しないこと
- [ ] 折り返し地点に敵を置いたときのヒット回数（10章の既知の制約）
- [ ] 速射Lv3＋増輪Lv3（空中20発以上）での描画・当たり判定の負荷

## 9. 既知の落とし穴（記入不要・確認用）

- `.tres` のリソース参照は必ず `ExtResource("id")`。`"res://..."` 文字列だとロード失敗する。
- `bullet_movement_config` を指定すると `UniversalBullet.apply_movement_config()` が `speed = movement_config.initial_speed` で上書きする。**`pattern.bullet_speed`（＝`base_modifiers.bullet_speed`）は効かなくなる**ので、両方に同じ値を書くこと。
- 逆に `bullet_movement_config` 未指定なら `universal_bullet.tscn` のデフォルト movement_config はコア側でクリアされる（初期回転バグ対策）。
- `bullet_lifetime = 0` は「無限」。この場合エンチャント「残留」は無効（ファクトリが 0 のまま返す）。
- `bullet_count` は最低1にクランプ、クールダウンは最低 0.02 秒にクランプされる。
- SHOT_ON_HIT の `on_hit_pattern` は `duplicate()` の浅いコピー経路を通るため、拡散弾数は `base_modifiers.spread_bullet_count` を基準値として持たせる。

## 10. 未決事項

- ~~**プレイヤー移動速度の実測値**~~：解決。`Player.speed = 200.0`（`scripts/player/Player.gd:10`、sneak時はさらに低下）に対し `boomerang_return_max_speed = 1000.0` は十分上回る。`tests/unit/BoomerangFeatureTest.gd` の `test_return_max_speed_exceeds_player_speed` で固定した。
- **貫通×速射の上振れ**：貫通Lv3（+4 → 計7回貫通＝最大8ヒット）× 速射Lv3 で理論96 DPS。実測後、必要なら `damage_base`（3→2）または基礎 `penetration_count`（3→2）で調整する。
- **折り返し地点に敵がいると2度ヒットしない**：`BulletBase._on_area_entered()` は `area_entered`（進入時のみ）で発火するため、敵の当たり判定内で速度0になって折り返すと退出→再進入が起きずヒットは1回だけ。売りの「2度ヒット」が成立しないケースとして許容するか、`boomerang_outbound_time` を短くして折り返し点を手前に置くかを決める。
