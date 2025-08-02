# ステージ管理システム ユニットテスト計画

## 概要

今回のComponent Registryリファクタリングで追加・変更されたステージ管理システムのコンポーネントに対する包括的なテスト計画。

## テスト戦略

### 1. テストレベル構成
- **Unit Tests**: 各コンポーネントクラスの単体テスト
- **Integration Tests**: コンポーネント間の連携テスト  
- **System Tests**: StageManager全体の動作テスト

### 2. テストツール
- **フレームワーク**: GdUnit4
- **モック**: 依存関係のモック化でテストを独立化
- **Stub**: テスト用の軽量スタブクラス

## 既存テストの変更が必要な箇所

### ❌ 変更不要
現在の既存テストは主にアイテム・攻撃システム関連で、今回のステージ管理システムリファクタリングとは独立しているため、**既存テストの変更は不要**。

## 新規テスト計画

### 1. Unit Tests

#### 1.1 StageComponentRegistryTest.gd
```gdscript
# tests/unit/StageComponentRegistryTest.gd
extends GdUnitTestSuite
class_name StageComponentRegistryTest

# テスト対象: Component Registry の基本機能
func test_component_registration()
func test_dependency_management()
func test_initialization_order_calculation()
func test_circular_dependency_detection()
func test_component_retrieval()
func test_error_handling()
func test_type_validation()
```

**テストケース詳細:**
- ✅ コンポーネント登録の成功/失敗
- ✅ 依存関係設定と解決順序の正確性
- ✅ 循環依存検出機能
- ✅ 型チェック（GDScript class_name対応）
- ✅ 初期化エラー時のフォールバック
- ✅ コンポーネント取得のnullハンドリング

#### 1.2 StageAudioControllerTest.gd
```gdscript
# tests/unit/StageAudioControllerTest.gd  
extends GdUnitTestSuite
class_name StageAudioControllerTest

# テスト対象: 音響制御コンポーネント
func test_stage_start_bgm()
func test_stage_cleared_audio()
func test_game_over_audio_sequence()
func test_bgm_stop_functionality()
func test_initialization()
```

**テストケース詳細:**
- ✅ BGM開始/停止の正確性
- ✅ ステージクリア時の音響処理
- ✅ ゲームオーバー時の2段階音響処理（即座停止→SFX再生）
- ✅ BGMControllerとの連携
- ✅ Component Registry初期化対応

#### 1.3 StageUIControllerTest.gd
```gdscript
# tests/unit/StageUIControllerTest.gd
extends GdUnitTestSuite
class_name StageUIControllerTest

# テスト対象: UI制御コンポーネント
func test_ready_prompt_display()
func test_clear_prompt_display()
func test_game_over_prompt_display()
func test_prompt_completion_signals()
func test_scene_resource_loading()
func test_has_ready_prompt_check()
```

**テストケース詳細:**
- ✅ Ready/Clear/GameOverプロンプト表示
- ✅ プロンプト完了シグナルの発火
- ✅ シーンリソースの読み込み処理
- ✅ プロンプト存在チェック機能
- ✅ UI要素のライフサイクル管理

#### 1.4 StageEnvironmentSetupTest.gd
```gdscript
# tests/unit/StageEnvironmentSetupTest.gd
extends GdUnitTestSuite
class_name StageEnvironmentSetupTest

# テスト対象: ステージ環境設定コンポーネント
func test_bullet_layer_setup()
func test_target_service_initialization()
func test_environment_validation()
func test_cleanup_functionality()
func test_additional_services_extension()
```

**テストケース詳細:**
- ✅ BulletLayer検出と設定
- ✅ TargetService連携
- ✅ 環境設定の検証機能
- ✅ クリーンアップ処理
- ✅ 将来の拡張点テスト

#### 1.5 StageLifecycleControllerTest.gd
```gdscript
# tests/unit/StageLifecycleControllerTest.gd
extends GdUnitTestSuite
class_name StageLifecycleControllerTest

# テスト対象: ライフサイクル管理コンポーネント
func test_state_transitions()
func test_initialization_states()
func test_stage_completion_handling()
func test_stage_failure_handling()
func test_invalid_state_transitions()
```

**テストケース詳細:**
- ✅ ステージ状態遷移（UNINITIALIZED→INITIALIZING→RUNNING等）
- ✅ 初期化開始/完了の状態管理
- ✅ ステージクリア時の状態変更
- ✅ ステージ失敗時の状態変更  
- ✅ 不正な状態遷移の検出

#### 1.6 StageControllerTest.gd (更新)
```gdscript
# tests/unit/StageControllerTest.gd
extends GdUnitTestSuite
class_name StageControllerTest

# テスト対象: ステージ進行制御（依存注入対応版）
func test_dependency_injection()
func test_seed_parsing()
func test_wave_event_execution()
func test_dialogue_event_execution()
func test_attack_core_pause_integration()
func test_signal_connection_safety()
```

**テストケース詳細:**
- ✅ WaveExecutor/DialogueRunnerの依存注入
- ✅ シグナル接続の重複チェック
- ✅ StageSignals経由の攻撃コア制御
- ✅ 依存関係設定のタイミング
- ✅ 外部からの依存関係上書き

#### 1.7 WaveExecutorTest.gd (更新)
```gdscript
# tests/unit/WaveExecutorTest.gd
extends GdUnitTestSuite
class_name WaveExecutorTest

# テスト対象: ウェーブ実行（依存注入対応版）
func test_enemy_spawner_injection()
func test_layer_execution()
func test_signal_connection_management()
func test_wave_template_processing()
func test_concurrent_layer_handling()
```

**テストケース詳細:**
- ✅ EnemySpawnerの外部設定機能
- ✅ シグナル接続の安全性（重複回避）
- ✅ レイヤー並列実行の管理
- ✅ 依存注入後の正常動作
- ✅ レイヤー完了イベント処理

### 2. Integration Tests

#### 2.1 StageComponentIntegrationTest.gd
```gdscript
# tests/integration/StageComponentIntegrationTest.gd
extends GdUnitTestSuite
class_name StageComponentIntegrationTest

# テスト対象: Component Registry + 各コンポーネントの統合
func test_full_component_initialization()
func test_dependency_resolution_flow()
func test_component_communication()
func test_stage_lifecycle_integration()
func test_error_propagation()
```

**テストシナリオ:**
- ✅ Component Registry初期化→全コンポーネント準備完了
- ✅ 依存関係順序での初期化実行
- ✅ コンポーネント間シグナル通信
- ✅ ステージ全体のライフサイクル実行
- ✅ 1つのコンポーネント失敗時の影響範囲

#### 2.2 StageManagerIntegrationTest.gd
```gdscript
# tests/integration/StageManagerIntegrationTest.gd
extends GdUnitTestSuite
class_name StageManagerIntegrationTest

# テスト対象: StageManager + StageController + WaveExecutor
func test_complete_stage_execution()
func test_ready_prompt_to_stage_start()
func test_game_over_flow()
func test_stage_clear_flow()
func test_dialogue_integration()
```

**テストシナリオ:**
- ✅ Ready Prompt → 環境設定 → ステージ開始
- ✅ シード値解析 → ウェーブ/ダイアログ実行
- ✅ ゲームオーバー → 2秒待機 → UI/音響処理
- ✅ ステージクリア → 音響/UI → 7秒待機 → 結果画面
- ✅ ダイアログ要求 → 攻撃コア停止 → ダイアログ実行

### 3. System Tests

#### 3.1 StageSystemEndToEndTest.gd
```gdscript
# tests/integration/StageSystemEndToEndTest.gd
extends GdUnitTestSuite
class_name StageSystemEndToEndTest

# テスト対象: ステージシステム全体のEnd-to-End
func test_full_stage_playthrough()
func test_multiple_stage_transitions()
func test_error_recovery_scenarios()
func test_performance_requirements()
```

## テスト実行環境

### 必要なStubクラス

#### ComponentRegistryStub.gd
```gdscript
# tests/stubs/ComponentRegistryStub.gd
class_name ComponentRegistryStub
extends RefCounted

# Component Registryのテスト用スタブ
var _mock_components: Dictionary = {}

func get_component(name: String) -> Node:
    return _mock_components.get(name)

func set_mock_component(name: String, component: Node):
    _mock_components[name] = component
```

#### StageSignalsStub.gd
```gdscript
# tests/stubs/StageSignalsStub.gd  
class_name StageSignalsStub

# StageSignalsのテスト用モック
static var signal_history: Array[Dictionary] = []

static func emit_signal(signal_name: String, value = null):
    signal_history.append({"signal": signal_name, "value": value})

static func clear_history():
    signal_history.clear()
```

## テスト実行計画

### Phase 1: Unit Tests実装 (Week 1)
- Component Registry単体テスト
- 各コンポーネントの単体テスト
- 依存注入機能のテスト

### Phase 2: Integration Tests実装 (Week 2)  
- コンポーネント間の連携テスト
- StageManager統合テスト
- シグナル通信テスト

### Phase 3: System Tests実装 (Week 3)
- End-to-Endテスト
- パフォーマンステスト
- エラーシナリオテスト

### Phase 4: テスト自動化 (Week 4)
- CI/CD統合
- カバレッジ測定
- レグレッションテスト自動化

## 成功基準

### カバレッジ目標
- **Unit Tests**: 90%以上のコードカバレッジ
- **Integration Tests**: 主要シナリオ100%カバー
- **System Tests**: エラーケース含む全パス検証

### パフォーマンス目標
- Component Registry初期化: 100ms以内
- ステージ開始: 500ms以内  
- ウェーブ切り替え: 50ms以内

### 品質目標
- ❌ **Zero Critical Bugs**: 本番環境でのクラッシュゼロ
- ✅ **High Maintainability**: テストコードの保守性確保
- ✅ **Documentation**: テストケースの包括的ドキュメント

## 既存システムとの競合回避

### 並列実行対応
- 既存のアイテム/攻撃システムテストと並列実行可能
- テスト間での状態共有を避けるためのクリーンアップ徹底
- モック/スタブによる外部依存関係の隔離

### リソース競合回避
- 各テストクラスで独立したシーンインスタンス使用
- グローバル状態（Autoload）のモック化
- テスト完了時の確実なリソースクリーンアップ

この計画により、今回のComponent Registryリファクタリングの信頼性と保守性を確保し、将来的な機能追加時の回帰テストベースを構築します。