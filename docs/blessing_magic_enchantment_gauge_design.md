# 加護・魔法・エンチャント・汎用ゲージ 設計仕様

MagicSTG の装備系4システム（加護 / 魔法[攻撃コア] / エンチャント / 汎用ゲージ）の基本設計とパラメータ設計をまとめる。

## 全体像

```
ItemBase (Resource)
 ├─ BlessingItem      ─ blessing_scene + base_modifiers   → 加護
 └─ AttackCoreItem    ─ core_scene/attack_pattern + base_modifiers → 魔法（攻撃コア）

ItemInstance (RefCounted)   ← ランタイムの1個体。prototype + enchantments{Enchantment:level}
 └─ Enchantment (Resource) ─ tiers[] ─ EnchantmentTier ─ modifiers{key:value}

GaugeProvider (Node)        ← HUDゲージを出せる全ノードの基底
 ├─ BlessingBase            → 各加護
 └─ AttackCoreBase          → 各攻撃コア
GenericGauge / GaugeManager ← HUD描画側
```

- **データ（Resource/JSON）** と **挙動（Scene+Script）** を分離。`ItemBase` が静的定義、`ItemInstance` が「プロトタイプ＋付与エンチャント」のランタイム個体。
- 加護・攻撃コアはどちらも `GaugeProvider` を継承し、HUD ゲージ表示の口を持つ。
- エンチャントは `modifiers` 辞書（キー→数値）を提供し、装備側がキーを集計して自分のパラメータに反映する。

---

## 1. 加護システム（Blessing）

### 1.1 構成クラス

| クラス | 種別 | 役割 |
|---|---|---|
| `ItemBase` → `BlessingItem` | Resource | 加護の静的定義（`blessing_scene`, `base_modifiers`, 表示名/説明/アイコン） |
| `GaugeProvider` → `BlessingBase` | Node | 全加護の基底。エンチャント集計・ポーズ管理・ゲージ口 |
| `BlessingBase` → `ActiveBlessingBase` | Node | キー発動型（アクティブ）加護の基底。使用回数＋クールダウン |
| `BlessingContainer` | Node | Player 直下。最大3スロットの装備管理と被/与ダメージ・CT介入のハブ |

### 1.2 ライフサイクル

1. `BlessingContainer._ready()` が `PlayerSaveData.get_blessings()` から装備中加護を読み、`equip_instance()` で1つずつ展開。
2. `equip_instance()`：`BlessingItem.blessing_scene` を instantiate → `blessing.item_inst = inst`（setter で `_recalc_stats()` 発火）→ `add_child` → `on_equip(player)`。
3. `item_inst` setter（`BlessingBase`）：`gauge_icon`/`_proto` をセットして `_recalc_stats()` を呼ぶ。
4. 解除は `on_unequip()` → `_managed_timers` クリア → `_on_unequip_impl()`。

### 1.3 BlessingBase が提供する基盤

| 機能 | API | 備考 |
|---|---|---|
| エンチャント集計（％） | `_sum_pct(key)` | 装備中エンチャントの `key` modifier を**加算**（割合合成のベース） |
| エンチャント集計（加算） | `_sum_add(key)` | 同上、整数加算系 |
| 統計再計算 | `_recalc_stats()`（override） | base_modifiers＋エンチャントから自パラメータを決定 |
| ポーズ管理 | `set_paused(bool)` / `register_timer(timer)` | 登録 Timer を一括 paused。`_on_paused_changed()` で拡張 |
| 被ダメージ介入 | `process_damage(player, dmg) -> int` | デフォルトは素通し |
| 与ダメージ介入 | `get_damage_bonus_pct(player, enemy, ctx) -> float` | 自弾→敵ヒット時のボーナス率 |
| 魔法CT介入 | `get_attack_cooldown_mult(player) -> float` | 1.0=等倍 |

### 1.4 BlessingContainer の合成ルール

| 介入 | メソッド | 合成方式 |
|---|---|---|
| 被ダメージ | `process_damage()` | 各加護を**直列**に通す（前段の結果を次段へ） |
| 与ダメージ | `process_outgoing_damage(enemy, base, ctx)` | 各加護の `get_damage_bonus_pct` を**加算**し、基底値へ一括適用：`base * (1 + Σbonus)` |
| 魔法CT | `get_attack_cooldown_mult()` | 各加護の倍率を**乗算** |
| アクティブ発動 | `_unhandled_input()` | `blessing_slot_1/2/3` 入力で対応スロットの `ActiveBlessingBase.activate()` |

- スロット上限 `MAX_SLOTS = 3`（`PlayerSaveData.MAX_BLESSINGS` と一致させる）。

### 1.5 加護の3類型と実装済み一覧

**A. 常時型（装備中ずっと効果。ゲージは装備表示のみ＝満タン固定）**

| 加護 | スクリプト | 効果 | 主要 base_modifiers / 参照エンチャントキー |
|---|---|---|---|
| 体力増強 | `HpBoostBlessing` | 最大HP増加（割合＋加算、増えた枠は満タン開始） | `hp_add` / enchant: `hp_pct`,`hp_add` |
| 背水 | `LastStandBlessing` | 残HP割合が低いほど与ダメ増。「必死」装着でCTも短縮 | `laststand_max_pct`,`laststand_floor_ratio` / enchant: `laststand_max_pct_pct`,`laststand_cdr_pct` |
| 近接 | `ProximityBlessing` | 敵との距離が近いほど与ダメ増（線形） | `proximity_max_pct`,`proximity_range` / enchant: `proximity_max_pct_pct`,`proximity_range_add` |

**B. 介入型（被ダメージを肩代わり。ゲージで状態可視化）**

| 加護 | スクリプト | 効果 | 主要パラメータ |
|---|---|---|---|
| 障壁 | `DefensiveBlessing` | シールドが被ダメージを完全吸収。破壊後は時間で復活 | 下記 1.6 参照 |

**C. アクティブ型（`ActiveBlessingBase`。キー発動・使用回数制・短CT）**

| 加護 | スクリプト | 効果 | 参照キー |
|---|---|---|---|
| 打消 | `NullifyBlessing` | 発動で場の敵弾を全消去（HUDフラッシュ）。「強奪」で撃破時に確率回数回復 | `max_uses`,`blessing_cooldown_sec` / enchant: `blessing_uses_add`,`nullify_steal_chance_pct` |

`ActiveBlessingBase` パラメータ設計：

| 変数 | 既定 | 意味 |
|---|---|---|
| `max_uses` | 3 | 1ステージの使用回数（`base_modifiers.max_uses + Σblessing_uses_add`） |
| `cooldown_sec` | 1.0 | 連打防止の短いCT（`base_modifiers.blessing_cooldown_sec`） |
| `_uses_remaining` | = max_uses | 残回数。`on_equip` でリセット、ゲージに表示（`durability` 流用） |

発動フロー：`activate()` → `can_activate()`（非ポーズ・非CT・残回数>0）→ `_do_activate()`（子の実効果、失敗時は回数消費せず）→ 回数-1・CT開始・`activated` 発火。

### 1.6 障壁の加護（DefensiveBlessing）詳細

| パラメータ | 既定 | 由来 | 意味 |
|---|---|---|---|
| `shield_max` | 50 | `shield_hp + Σshield_hp_add`、`×(1+Σshield_hp_pct)` | シールド耐久 |
| `recover_delay` | 5.0 | `shield_recover_delay × (1+Σshield_recover_delay_pct)` | 破壊→復活までの秒数 |
| `regen_delay` | 10.0 | `base_modifiers.shield_regen_delay` | 無被弾から自然回復開始までの秒数 |
| `regen_rate` | 2.0 | `base_modifiers.shield_regen_rate` | 自然回復速度（HP/秒） |

挙動：
- **吸収**：`process_damage` で未破壊なら全吸収しシールドを削る（被ダメージ0を返す）。0以下で `is_broken=true`。
- **自然回復**：未破壊かつ最後の被弾から `regen_delay` 経過後、`_process` で `regen_rate`×delta を積算し `shield_max` まで回復。被弾で待機リセット。
- **復活ゲージ**：破壊中は `_update_recover_gauge(delta)` が delta 積算で 0→max を**毎フレーム滑らかに**充填（時間連動）。
- **ゲージ画像切替**：破壊時 `set_gauge_style("durability_recovering")`（無効化画像）、復活時 `set_gauge_style("durability")`（通常画像）。
- ポーズ中（`_paused`）は回復・ゲージ更新・復活Timerを停止。

---

## 2. 魔法システム（攻撃コア / Attack Core）

### 2.1 構成クラス

| クラス | 種別 | 役割 |
|---|---|---|
| `ItemBase` → `AttackCoreItem` | Resource | 攻撃コアの静的定義（`core_scene`/`projectile_scene`/`attack_pattern`/`damage_base`/`cooldown_sec_base`/`base_modifiers`） |
| `AttackPattern` | Resource | 攻撃の挙動定義（パターン型・弾・方向・軌道・発射位置 等の大規模パラメータ集合） |
| `GaugeProvider` → `AttackCoreBase` | Node | 発射・クールダウン管理の基底。`UniversalAttackCore` 等が実装 |
| `PlayerAttackPatternFactory` | RefCounted(static) | `ItemInstance` から `AttackPattern` を生成・エンチャント反映 |

### 2.2 発射・クールダウンの流れ（AttackCoreBase）

1. `_ready()`：`player_mode && item_inst && !attack_pattern` なら `_generate_attack_pattern_from_item()` でパターン生成＋`init_gauge("cooldown",100,0,...)`。`auto_start` なら `_start_cooldown()`。
2. `_on_cooldown_finished()` → `trigger()`：`can_fire()`（非ポーズ・非CT）なら `_do_fire()`（子で実装）→ 成功で `core_fired` 発火＋`_start_cooldown()`。
3. `_effective_cooldown()`：`player_mode` 時のみ `BlessingContainer.get_attack_cooldown_mult()` を乗算し、`MIN_PLAYER_COOLDOWN = 1/60` でクランプ。

### 2.3 パラメータ設計

`AttackCoreItem`：

| パラメータ | 意味 |
|---|---|
| `pattern_type` | `SINGLE_SHOT / BEAM / CUSTOM`（コアの大分類） |
| `damage_base` | 基本ダメージ（→ pattern.damage） |
| `cooldown_sec_base` | 基本CT（→ pattern.burst_delay） |
| `base_modifiers` | `bullet_speed`,`spread_bullet_count` 等の基礎値辞書 |
| `attack_pattern` | 明示パターン（未指定ならファクトリがコア種別から生成） |

`AttackPattern`（抜粋。enum は複数の発射形態を表現）：

| グループ | 主なパラメータ |
|---|---|
| 基本 | `pattern_type`(SINGLE_SHOT/RAPID_FIRE/BARRIER_BULLETS/SPIRAL/BEAM/CUSTOM/BURST_WITH_TRACKING/SHOT_ON_HIT), `bullet_scene`, `target_group`, `damage`, `penetration_count`, `bullet_lifetime` |
| 発射 | `bullet_count`, `rapid_fire_count/interval`, `burst_delay`, `burst_count/burst_interval/min_cooldown` |
| 方向 | `direction_type`(FIXED/TO_PLAYER/RANDOM/CIRCLE/CUSTOM/TO_OWNER), `base_direction`, `angle_spread`, `angle_offset` |
| 軌道 | `movement_type`(STRAIGHT/CURVE/ORBIT_THEN_STRAIGHT/HOMING), `bullet_speed`, `curve_strength`, `orbit_radius` |
| 発射位置 | `spawn_position_mode`(OWNER/FIXED_ABSOLUTE/RELATIVE_TO_OWNER/RELATIVE_TO_TARGET/CUSTOM), `spawn_position_offset`, `spawn_positions_multi` |
| ビーム | `beam_scene`, `beam_duration`, `continuous_damage`, `beam_offset` |
| ヒット時発動 | `on_hit_pattern`, `on_hit_use_hit_position`, `on_hit_trigger_once` |
| 存続 | `persist_offscreen`, `max_offscreen_distance`, `forced_lifetime` |

> 新パターン追加の詳細手順は `CLAUDE.md` の「Adding New Attack Patterns」を参照。

### 2.4 ItemInstance → AttackPattern 生成（PlayerAttackPatternFactory）

- `create_pattern_from_item_instance()`：`attack_pattern` 指定があれば `duplicate()`、無ければコア種別からパターン型を決定。`damage`/`burst_delay`/`bullet_scene`/`bullet_speed` を `AttackCoreItem` から流し込む。
- `update_pattern_from_enchantments()`：エンチャントで `damage`/`bullet_speed`/`bullet_lifetime`/`cooldown`/`penetration`/`bullet_count`/`spread_bullet_count` を更新。最低CT 0.02秒、弾数は最低1。

---

## 3. エンチャントシステム

### 3.1 構成クラス

| クラス | 役割 |
|---|---|
| `Enchantment` (Resource) | `id` / `display_name` / `description` / `tiers[]`。`get_modifiers(level)` でその tier の modifier 辞書を返す |
| `EnchantmentTier` (Resource) | `level`(1〜3) と `modifiers`(キー→数値) |
| `EnchantmentRule` (Resource) | ドロップ時の付与ルール。`pool[]`（候補）/`count_weights`（個数）/`level_weights`（レベル） |
| `ItemInstance.enchantments` | `Dictionary[Enchantment, int]`（個体に付与されたエンチャントとレベル） |

### 3.2 modifier キー命名規約

| 接尾辞 | 合成 | 例 |
|---|---|---|
| `_pct` | **加算**して `×(1+Σ)` で適用（割合） | `shield_hp_pct`, `cooldown_pct`, `shield_recover_delay_pct` |
| `_add` | **加算**で適用（実数/整数） | `hp_add`, `bullet_count_add`, `proximity_range_add` |

- **加護側**は `BlessingBase._sum_pct/_sum_add` でキーを集計。
- **攻撃コア側**は `PlayerAttackPatternFactory._apply_enchantment_modifiers()` が `key_pct`/`key_add` を集計（`base*(1+Σpct)+Σadd`）。

### 3.3 解決とセーブ

- `ItemDB._ready()` が `res://resources/data` 配下の全 `.tres` を走査し、`Enchantment` を `id→Enchantment` で登録。
- セーブ（`default_player_save.json`）はエンチャントを `{"id","level"}` で保持。ロード時に `ItemDb.get_enchantment_by_id(id)` で解決。

### 3.4 実装済みエンチャント一覧

| 表示名 | id (modifierキー) | 効果 | Lv1 / Lv2 / Lv3 | 主な適用先 |
|---|---|---|---|---|
| 堅固 | `shield_hp_pct` | シールド耐久 +% | +50% / +100% / +200% | 障壁 |
| 速復 | `shield_recover_delay_pct` | シールド復活待機 短縮 | -10% / -20% / -50% | 障壁 |
| 増健 | `hp_add` | 最大HP +（加算） | +3 / +6 / +10 | 体力増強 |
| 速治 | `regen_interval_sec_pct` | 回復間隔 短縮 | -20% / -50% / -80% | 再生 |
| 必死 | `laststand_cdr_pct` | 低HP時の魔法CT短縮 | +15% / +30% / +50% | 背水 |
| 無我 | `laststand_max_pct_pct`＋`proximity_max_pct_pct` | 最大ダメージ倍率 +% | +15% / +30% / +50% | 背水・近接 |
| 凝集 | `proximity_range_add` | 最大ダメ到達距離 +px | +50 / +100 / +180 | 近接 |
| 強奪 | `nullify_steal_chance_pct` | 撃破時 使用回数回復確率 | +2% / +5% / +10% | 打消 |
| 保持 | `blessing_uses_add` | 使用回数上限 + | +1 / +2 / +3 | アクティブ加護 |
| 速射 | `cooldown_pct` | 連射CT 短縮 | -20% / -50% / -75% | 攻撃コア |
| 増輪 | `bullet_count_add` | 弾数 + | +1 / +3 / +6 | 攻撃コア |
| 炸裂 | `spread_bullet_count_add` | 拡散弾数 + | (tier値) | 攻撃コア |
| 残留 | `bullet_lifetime_pct` | 弾寿命 +% | +50% / +50% / +200% | 攻撃コア |
| 貫通 | `penetration_add` | 貫通回数 + | +1 / +2 / +4 | 攻撃コア |

### 3.5 新規エンチャント追加手順

1. 装備側が対象キー（`xxx_pct`/`xxx_add`）を集計しているか確認。無ければ `_recalc_stats()` 等に `_sum_pct/_sum_add` を追加。
2. `resources/data/tiers/tier_<key>_1..3.tres` を作成（`level` と `modifiers`）。
3. `resources/data/enchantment_<key>.tres` を作成（`id`/`display_name`/`description`/`tiers`）。
4. 付与対象の `EnchantmentRule`（`resources/itemdrop/enchantmentrule_*.tres`）の `pool` に追加。
5. （任意）`default_player_save.json` に付与済み個体を追加。

> 例：「速復」(`shield_recover_delay_pct`) は `DefensiveBlessing._recalc_stats()` が既にキーを集計済みのため、リソース作成と pool 追加のみで実装できた。

---

## 4. 汎用ゲージシステム

### 4.1 構成クラス

| クラス | 種別 | 役割 |
|---|---|---|
| `GaugeProvider` | Node | ゲージを出すノードの基底。状態を持ちシグナルで通知 |
| `GenericGauge` | Control | HUDの1ゲージ部品（アイコン/ラベル/バー）。Provider値を描画 |
| `GaugeManager` | Control | Provider を自動検出して GenericGauge を生成・橋渡し |

### 4.2 GaugeProvider（データ側）

| 項目 | 内容 |
|---|---|
| エクスポート | `gauge_style`("cooldown"/"durability"/...), `gauge_icon`, `gauge_max`, `gauge_label`, `show_on_hud` |
| 状態 | `gauge_current` |
| シグナル | `gauge_registered/unregistered`, `gauge_changed(cur,max)`, `gauge_style_changed(style)` |
| API | `init_gauge(style,max,cur,label)`, `set_gauge(value)`(clamp＋通知), `set_gauge_style(style)`(変更＋通知) |
| 登録 | `_ready` で `gauge_providers` グループに参加し、`show_on_hud` なら `gauge_registered` を発火 |

### 4.3 GaugeManager（橋渡し）

- `_ready` で既存 Provider を走査＋`node_added` を監視し、`gauge_providers` グループのノードを `_register_provider()`。
- Provider ごとに `GenericGauge` を生成して `init_from_provider()`、`_provider_map[provider]=gauge` で対応付け。
- Provider の `gauge_changed`→`update_value`、`gauge_style_changed`→`update_style`、`gauge_unregistered`→破棄、を中継（疎結合）。

### 4.4 GenericGauge（描画側）

- `init_from_provider(p)`：アイコン/ラベル/バー初期化。`_bar.step = 0.0`（**値スナップ無効＝フレーム単位で滑らか**）。
- `update_value(cur,max)`：`_bar.value/max_value` 更新。
- `update_style(style)`：スタイルごとに `fill_mode` / `texture_progress` / `fg_color` を切替。

| style | バー画像 | 色 | 用途 |
|---|---|---|---|
| `cooldown` | `generic_gauge_progress` | CYAN | 攻撃コアのCT |
| `durability` | `generic_gauge_progress` | GREEN | 加護の耐久/使用回数/装備表示 |
| `durability_recovering` | `ganeric_gauge_disabled` | GREEN | 障壁破壊中の復活ゲージ |
| その他 | `generic_gauge_progress` | WHITE | フォールバック |

### 4.5 利用パターン

- **攻撃コア**：`init_gauge("cooldown",100,0,...)` → `_process` で残CTを 0→100 表示。
- **常時型加護**：`init_gauge("durability",100,100,...)`（満タン固定＝装備中の可視化）。
- **障壁**：`durability`（耐久値）↔ `durability_recovering`（復活進捗）をスタイル切替で切り分け。
- **アクティブ加護**：`durability` を流用し残使用回数を表示。
