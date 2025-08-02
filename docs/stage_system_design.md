# ステージ生成システム設計仕様

## 概要

MagicSTGの新しいステージ生成システムは、シード値ベースでウェーブとダイアログを組み合わせたステージを生成する。従来の複雑な多層リソース構造を廃止し、JSONファイルによる統一管理とシンプルなコンポジションパターンを採用。

## 設計方針

- **単一シード値**ですべてのステージ構成を制御
- **JSON統一管理**で非プログラマーも編集可能
- **レイヤー構造**による複雑なウェーブ表現
- **既存DialogueLine完全互換**
- **拡張性と保守性の向上**

## データ構造

### 1. メインデータファイル (data/stage_data.json)

```json
{
  "wave_templates": {
    "basic_swarm": {
      "layers": [
        {
          "enemy": "weak_drone",
          "count": 5,
          "pattern": "random",
          "interval": 0.3,
          "delay": 0.0
        }
      ]
    },
    "mixed_assault": {
      "layers": [
        {
          "enemy": "weak_drone",
          "count": 8,
          "pattern": "line_horizontal",
          "interval": 0.2,
          "delay": 0.0
        },
        {
          "enemy": "medium_fighter", 
          "count": 2,
          "pattern": "corners",
          "interval": 1.0,
          "delay": 2.0
        },
        {
          "enemy": "heavy_tank",
          "count": 1,
          "pattern": "burst_center", 
          "interval": 0.0,
          "delay": 5.0
        }
      ]
    },
    "boss_intro": {
      "layers": [
        {
          "enemy": "escort_drone",
          "count": 4,
          "pattern": "corners",
          "interval": 0.5,
          "delay": 0.0
        },
        {
          "enemy": "stage1_boss",
          "count": 1,
          "pattern": "center",
          "interval": 0.0,
          "delay": 3.0
        }
      ]
    }
  },
  
  "enemies": {
    "weak_drone": {
      "scene_path": "res://scenes/enemies/WeakDrone.tscn",
      "spawn_weight": 1.0
    },
    "medium_fighter": {
      "scene_path": "res://scenes/enemies/MediumFighter.tscn",
      "spawn_weight": 0.7
    },
    "heavy_tank": {
      "scene_path": "res://scenes/enemies/HeavyTank.tscn",
      "spawn_weight": 0.5
    },
    "escort_drone": {
      "scene_path": "res://scenes/enemies/EscortDrone.tscn",
      "spawn_weight": 0.8
    },
    "stage1_boss": {
      "scene_path": "res://scenes/enemies/Stage1Boss.tscn",
      "spawn_weight": 0.1
    }
  },

  "spawn_patterns": {
    "random": { 
      "type": "random_edge" 
    },
    "line_horizontal": { 
      "type": "line", 
      "direction": "horizontal", 
      "spacing": 64,
      "start_position": "top_left"
    },
    "burst_center": { 
      "type": "burst", 
      "center": [400, 300], 
      "radius": 100,
      "angle_offset": 0
    },
    "corners": { 
      "type": "fixed_positions", 
      "positions": [[100,100], [700,100], [100,500], [700,500]]
    },
    "center": { 
      "type": "fixed_positions", 
      "positions": [[400,300]]
    }
  },

  "dialogues": {
    "stage1": {
      "intro": [
        {
          "speaker_name": "フェアリー",
          "face_left": "res://textures/faces/fairy_normal.png",
          "face_right": null,
          "speaker_side": "left",
          "box_direction": "left",
          "text": "新しいステージが始まるよ！"
        },
        {
          "speaker_name": "フェアリー",
          "face_left": "res://textures/faces/fairy_excited.png",
          "face_right": null,
          "speaker_side": "left",
          "box_direction": "left",
          "text": "敵が来るから準備して！"
        }
      ],
      "mid_battle": [
        {
          "speaker_name": "プレイヤー",
          "face_left": null,
          "face_right": "res://textures/faces/player_serious.png",
          "speaker_side": "right",
          "box_direction": "right",
          "text": "この敵、強いな..."
        },
        {
          "speaker_name": "プレイヤー",
          "face_left": null,
          "face_right": "res://textures/faces/player_determined.png",
          "speaker_side": "right",
          "box_direction": "right",
          "text": "でも負けるわけにはいかない！"
        }
      ],
      "victory": [
        {
          "speaker_name": "フェアリー",
          "face_left": "res://textures/faces/fairy_happy.png",
          "face_right": null,
          "speaker_side": "left",
          "box_direction": "left",
          "text": "やったね！"
        },
        {
          "speaker_name": "フェアリー",
          "face_left": "res://textures/faces/fairy_excited.png",
          "face_right": null,
          "speaker_side": "left",
          "box_direction": "left",
          "text": "次のステージに進もう！"
        }
      ]
    },
    "boss_stage": {
      "boss_intro": [
        {
          "speaker_name": "ボス",
          "face_left": "res://textures/faces/boss_menacing.png",
          "face_right": null,
          "speaker_side": "left",
          "box_direction": "left",
          "text": "よくここまで来たな..."
        },
        {
          "speaker_name": "ボス",
          "face_left": "res://textures/faces/boss_angry.png",
          "face_right": null,
          "speaker_side": "left",
          "box_direction": "left",
          "text": "だが、ここで終わりだ！"
        }
      ]
    }
  }
}
```

## シード値仕様

### 基本フォーマット
```
"wave_template1-Dpool.dialogue_id-wave_template2-Dpool.dialogue_id-..."
```

### 具体例

**基本ステージ:**
```
"basic_swarm-Dstage1.intro-mixed_assault-Dstage1.mid_battle-boss_intro-Dstage1.victory"
```

**実行順序:**
1. `basic_swarm` ウェーブ実行
2. `stage1.intro` 会話再生
3. `mixed_assault` ウェーブ実行
4. `stage1.mid_battle` 会話再生
5. `boss_intro` ウェーブ実行
6. `stage1.victory` 会話再生

**固定ステージ例:**
```
"basic_swarm-mixed_assault-boss_intro"  # 会話なしの連続ウェーブ
```

**ランダムステージ例:**
```
プロシージャル生成されたシード値（将来実装）
```

## システム構成

### 1. GameDataRegistry (Autoload)
- JSONデータの読み込みと管理
- 各種データの取得API提供

### 2. StageController
- シード値の解析
- イベントの順次実行
- ウェーブとダイアログの制御

### 3. WaveExecutor
- ウェーブテンプレートの実行
- レイヤー処理とタイミング制御
- 敵の生成とパターン適用

### 4. 既存システムとの統合
- DialogueRunner: 既存のまま使用
- EnemySpawner: パターン処理部分を拡張
- DialogueLine: 完全互換性維持

## レイヤーシステム詳細

### レイヤー実行例
```json
"mixed_assault": {
  "layers": [
    {
      "enemy": "weak_drone",    // 即座に開始
      "count": 8,
      "pattern": "line_horizontal",
      "interval": 0.2,
      "delay": 0.0
    },
    {
      "enemy": "medium_fighter", // 2秒後に開始
      "count": 2,
      "pattern": "corners", 
      "interval": 1.0,
      "delay": 2.0
    },
    {
      "enemy": "heavy_tank",     // 5秒後に開始
      "count": 1,
      "pattern": "burst_center",
      "interval": 0.0,
      "delay": 5.0
    }
  ]
}
```

### 実行タイムライン
```
0.0s: weak_drone #1 (line_horizontal)
0.2s: weak_drone #2
0.4s: weak_drone #3
...
1.6s: weak_drone #8
2.0s: medium_fighter #1 (corners)
3.0s: medium_fighter #2
5.0s: heavy_tank #1 (burst_center)
```

## 利点

### 1. 保守性の向上
- 複雑な多層リソース構造を排除
- JSONファイル1つでステージ定義完結
- 変更時の影響範囲を最小化

### 2. 拡張性の確保
- レイヤー構造により無限の組み合わせ
- パターンとテンプレートの再利用
- 新要素追加時はJSONに追加のみ

### 3. 開発効率の向上
- 非プログラマーでも編集可能
- バージョン管理しやすいテキストファイル
- デバッグとテストの容易さ

### 4. 既存システムとの互換性
- DialogueLineとの完全互換
- 既存敵シーンをそのまま利用
- 段階的な移行が可能

## 移行計画

### Phase 1: 基盤システム実装
- GameDataRegistry実装
- JSON読み込み機能
- StageController基本機能

### Phase 2: ウェーブシステム実装  
- WaveExecutor実装
- レイヤー処理システム
- パターン処理拡張

### Phase 3: ダイアログ統合
- JSON→DialogueLine変換
- 既存DialogueRunnerとの統合
- 完全なシード値処理

### Phase 4: 既存システム移行
- 既存ステージの新形式変換
- テストとデバッグ
- 旧システムの段階的廃止

## 注意事項

- 既存のStageManager、StageSegment、WaveData、SpawnEventは段階的に廃止予定
- DialogueLineクラス自体は継続使用（互換性維持）
- JSONファイルの構造変更時は下位互換性を考慮
- パフォーマンステストを実施し、必要に応じて最適化