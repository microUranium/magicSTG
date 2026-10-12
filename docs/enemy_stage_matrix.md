# 雑魚敵 × ステージ出現マトリクス

雑魚ウェーブ拡充に向けた、敵の出現ステージ検討用シート。
現状値は `resources/data/stage_data.json` の `wave_templates` から集計（2026-10-12 時点）。

## 凡例

| 記号 | 意味 |
|:-:|---|
| ● | 既存：プール所属テンプレートで出現（ランダムステージで抽選される） |
| ○ | 既存：固定シード専用テンプレートのみで出現 |
| ★ | **追加提案**：このステージにも出現させたい |
| ✕ | **削除提案**：このステージから外したい |
| — | 出現なし |

数字は使用テンプレート数（`プール所属数+固定シード専用数`）。提案時は `—` を `★` に書き換え、必要なら備考欄に意図（強化版にする、混成で使う等）を書く。

## マトリクス

| 敵 | stage1<br>森 | stage2<br>海 | stage3<br>遺跡 | stage4<br>沼 | stage5<br>館 | stage6<br>山 | 備考 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|---|
| enemy_bird_a | ● 4+2 | — | — | — | — | — | |
| enemy_bird_a_rush | ● 3+1 | — | — | — | — | — | |
| enemy_b | ● 7+2 | — | — | — | — | — | |
| enemy_flower_a | ● 3+1 | — | — | — | — | — | |
| enemy_starfish_a | — | ● 4+1 | — | — | — | — | |
| enemy_starfish_b | — | ● 5+2 | — | — | — | — | |
| enemy_fugu_a | — | ● 5+3 | — | — | — | — | |
| enemy_sea_bird | — | ● 8+4 | — | — | — | — | |
| enemy_flower_b | — | ● 5+3 | — | — | — | ★ | stage6に登場する方は攻撃手段、HP共に強化 |
| enemy_lantern | — | — | ● 3 | — | ★ | — | stage5に登場する方は攻撃手段、HP据え置き |
| enemy_grimoire | — | — | ● 3 | — | ★ | — | stage5に登場する方は攻撃手段強化、HP据え置き |
| enemy_bat_a | — | — | ● 1 | — | — | — | |
| enemy_swamp_bird | — | — | — | ● 1 | — | ★ | stage6に登場する方は攻撃手段HP共に据え置き |
| enemy_living_wood | — | — | — | ● 1 | — | — | |
| enemy_cedar | — | — | — | — | — | ★ | 新規（stage6 のみ）。HP500、通常攻撃なし。HP が20%減るごと（撃破時含む）に花粉30発をばらまく |
| enemy_spike | — | — | — | ● 1 | — | — | |
| enemy_piranha | — | — | — | ● 1 | — | — | |
| enemy_bat_b | — | — | — | — | ● 1 | — | |
| enemy_ghost | — | — | — | — | ● 1 | — | |
| enemy_lantern_b | — | — | ★ | — | ● 1 | — | stage3に登場する方は攻撃手段、HP共に弱体化 |
| enemy_bird_d | — | — | — | — | — | ● 1 | |
| enemy_flower_c | — | — | — | — | — | ● 1 | |
| **雑魚種類数（現状）** | 4 | 5 | 3 | 4 | 3 | 2 | |

## 参考：ボス・中ボス枠（検討対象外）

| ステージ | ボス／中ボス |
|---|---|
| stage1 | boss_bird（3バリアント。プール所属は skip_dialogue 版のみ）、harpy |
| stage2 | boss_stingray（3バリアント。プール所属は skip_dialogue 版のみ）、boss_snake |
| stage3 | boss_robe、boss_vampire |
| stage4 | boss_spider、enemy_harpy_swamp＋boss_bird_swamp |
| stage5 | boss_bear、boss_doll |
| stage6 | boss_devil、boss_devil_enhanced |

ボスの召喚物・分身（`enemy_bat_decoy`、`enemy_fire_ball_decoy`、`enemy_living_wood_shield`、`enemy_boss_*_clone/body/firerush/starrush`）は stage_data.json 未登録のため除外。

## メモ・追加の要望

<!-- 新規敵の追加案、ステージごとの方針などがあればここに記入 -->
複数ステージに跨る敵は、ステージごとに強化版・弱体版を用意してほしい