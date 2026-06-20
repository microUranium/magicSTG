# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MagicSTG is a bullet-hell shoot-em-up game built in Godot 4.4. The game features a modular attack system, equipment/enchantment mechanics, and stage progression with enemy waves.

## Core Architecture

### Attack System
- **AttackCoreBase** (`scripts/core/AttackCoreBase.gd`): Base class for all attack behaviors with cooldown management
- **UniversalAttackCore** (`scripts/core/UniversalAttackCore.gd`): Configurable attack system supporting multiple pattern types (single shot, rapid fire, spiral, beam, etc.)
- **AttackPattern** (`scripts/core/AttackPattern.gd`): Configuration resources defining attack behaviors
- **AttackPatternFactory** (`scripts/core/AttackPatternFactory.gd`): Factory for creating attack pattern instances

### Entity System
- **BulletBase** (`scripts/core/BulletBase.gd`): Base class for all projectiles
- **UniversalBullet** (`scripts/core/UniversalBullet.gd`): Configurable bullet system with visual and movement configs
- **EnemyBase** (`scripts/core/EnemyBase.gd`): Base class for all enemies
- **EnemyPatternedAIBase** (`scripts/core/EnemyPatternedAIBase.gd`): AI system supporting phase-based attack patterns

### Player System
- **Player** (`scripts/player/Player.gd`): Main player controller
- **Fairy** (`scripts/player/Fairy.gd`): Player companion that manages attack cores
- **AttackCoreSlot** (`scripts/player/AttackCoreSlot.gd`): Equipment system for attack cores
- **BlessingContainer** (`scripts/player/BlessingContainer.gd`): Passive ability system

### Item & Equipment System
- **ItemBase** (`scripts/item/ItemBase.gd`): Base class for all items
- **ItemInstance** (`scripts/item/ItemInstance.gd`): Runtime item instances with enchantments
- **Enchantment** (`scripts/item/Enchantment.gd`): Stat modification system
- **LootSystem** (autoload): Handles item drops and enchantment rolling

### Stage Management
- **StageManager** (`scripts/systems/StageManager.gd`): Controls stage progression, wave spawning, and dialogue
- **EnemySpawner** (`scripts/systems/EnemySpawner.gd`): Handles enemy wave spawning
- **StageSegment** (`scripts/systems/StageSegment.gd`): Stage timeline configuration

### Autoloads (Global Systems)
- **GameFlow**: Core game state management
- **PlayArea**: Game boundaries and coordinate utilities
- **StageSignals**: Event bus for stage-related communications
- **InventoryService**: Inventory management and item operations
- **PlayerSaveData**: Persistent player data
- **ItemDB**: Item database and lookup
- **BGMController**: Background music management
- **SFXManager**: Sound effects system

## Development Commands

### Testing

#### Godot Binary Path
This project uses Godot 4.4.1 Mono. The binary path is:
```
E:\Godot_v4.4.1-stable_mono_win64\Godot_v4.4.1-stable_mono_win64.exe
```

#### Running Tests
Run unit tests with gdUnit4:
```bash
# Windows - Using direct binary path (recommended)
addons/gdUnit4/runtest.cmd --godot_bin "E:\Godot_v4.4.1-stable_mono_win64\Godot_v4.4.1-stable_mono_win64.exe" -a tests/unit/

# Run specific test file
addons/gdUnit4/runtest.cmd --godot_bin "E:\Godot_v4.4.1-stable_mono_win64\Godot_v4.4.1-stable_mono_win64.exe" -a tests/unit/ui/PausePanelControllerTest.gd

# Or with environment variable
set GODOT_BIN=E:\Godot_v4.4.1-stable_mono_win64\Godot_v4.4.1-stable_mono_win64.exe
addons/gdUnit4/runtest.cmd -a tests/unit/

# Linux/Mac
addons/gdUnit4/runtest.sh --godot_bin /path/to/godot -a tests/unit/
```

#### Test Structure
Test files are located in:
- `tests/unit/` - Unit tests
- `tests/integration/` - Integration tests
- `tests/stubs/` - Test helper classes

#### gdUnit4 API Notes
When writing tests, be aware of the following:

**Signal Monitoring:**
- ✅ Use `monitor_signals(object)` - Returns a signal emitter for the object
- ✅ Use `await assert_signal(emitter).wait_until(timeout_ms).is_emitted("signal_name", [args])`
- ❌ Do NOT use `monitor_signal()` (singular) - This function does not exist
- ❌ Do NOT use `GdUnitSignalCollector` - This class does not exist in current gdUnit4 version

**Assertions:**
- Use `assert_that(value)` for most assertions
- Use `assert_int(value)`, `assert_bool(value)`, `assert_object(value)` for type-specific assertions
- Use `await await_idle_frame()` to wait for node initialization
- Use `await await_millis(ms)` to wait for animations/tweens

**Example Signal Test:**
```gdscript
func test_signal_emission() -> void:
    var emitter := monitor_signals(_controller)

    _controller.do_something()

    await assert_signal(emitter).wait_until(50).is_emitted("something_happened", [expected_arg])
```

**Example State Test (Preferred for simple cases):**
```gdscript
func test_state_change() -> void:
    _controller.do_something()

    assert_that(_controller.some_state).is_true()
    assert_that(_controller.visible).is_false()
```

For comprehensive unit tests, prefer testing internal state changes over signal emissions when possible, as this is simpler and more reliable.

### Project Structure
- `scripts/core/` - Core game systems and base classes
- `scripts/player/` - Player-related components
- `scripts/enemy/` - Enemy AI and behaviors
- `scripts/item/` - Item and equipment system
- `scripts/systems/` - High-level game systems
- `scripts/ui/` - User interface components
- `scripts/autoload/` - Global singleton scripts
- `scenes/` - Scene files organized by category
- `resources/` - Game data resources (attack patterns, items, etc.)

## Adding New Attack Patterns

This section documents the complete process for adding a new attack pattern to the game, based on the Triple Burst implementation.

### Step-by-Step Implementation Guide

#### 1. Define Pattern Type (`scripts/core/AttackPattern.gd`)

Add a new pattern type to the `PatternType` enum:
```gdscript
enum PatternType {
    SINGLE_SHOT,
    RAPID_FIRE,
    BARRIER_BULLETS,
    SPIRAL,
    BEAM,
    CUSTOM,
    BURST_WITH_TRACKING  # New pattern type
}
```

Add any pattern-specific properties:
```gdscript
@export var burst_count: int = 3
@export var burst_interval: float = 0.05
@export var min_cooldown: float = 0.0833
```

**Key Concepts:**
- `cooldown_sec`: Standard cooldown between attacks (can be modified by distance/enchantments)
- `min_cooldown`: Absolute minimum time between attacks (enforced even if other conditions are met)
- `burst_delay`: Cooldown between bursts (used as base cooldown for burst patterns)

#### 2. Implement Pattern Logic (`scripts/core/UniversalAttackCore.gd`)

##### a. Add State Variables
```gdscript
var _tracked_bullets: Array[Node] = []  # For tracking active bullets
var _last_burst_time: float = 0.0      # For min_cooldown enforcement
```

##### b. Add Firing Condition Validation
In `_validate_firing_conditions()`:
```gdscript
if attack_pattern.pattern_type == AttackPattern.PatternType.BURST_WITH_TRACKING:
    _clean_tracked_bullets()
    if _tracked_bullets.size() > 0:
        return false
    var time_since_last_burst = Time.get_ticks_msec() / 1000.0 - _last_burst_time
    if time_since_last_burst < attack_pattern.min_cooldown:
        return false
```

##### c. Implement Execution Function
```gdscript
func _execute_burst_with_tracking(pattern: AttackPattern) -> bool:
    _last_burst_time = Time.get_ticks_msec() / 1000.0

    for i in range(pattern.burst_count):
        if i > 0:
            await get_tree().create_timer(pattern.burst_interval).timeout

        var direction = pattern.calculate_direction(...)
        var spawn_pos = pattern.calculate_spawn_position(...)
        _spawn_bullet(pattern, direction, spawn_pos)

    return true
```

##### d. Add Bullet Tracking
```gdscript
func _on_bullet_spawned(bullet: Node) -> void:
    if attack_pattern.pattern_type == AttackPattern.PatternType.BURST_WITH_TRACKING:
        _tracked_bullets.append(bullet)
        bullet.tree_exiting.connect(_remove_from_tracked.bind(bullet))
```

##### e. Handle Bullet Destruction
```gdscript
func _on_projectile_destroyed(projectile: Node) -> void:
    _spawned_projectiles.erase(projectile)
    _tracked_bullets.erase(projectile)

    if attack_pattern.pattern_type == AttackPattern.PatternType.BURST_WITH_TRACKING:
        if _tracked_bullets.size() == 0 and is_inside_tree():
            # Wait for min_cooldown before retriggering
            var time_since_last_burst = Time.get_ticks_msec() / 1000.0 - _last_burst_time
            if time_since_last_burst < attack_pattern.min_cooldown:
                var wait_time = attack_pattern.min_cooldown - time_since_last_burst
                await get_tree().create_timer(wait_time).timeout

            await get_tree().process_frame
            trigger()
```

#### 3. Create Resource File (`resources/data/attackcore_*.tres`)

**CRITICAL**: Use proper ExtResource ID references, not file paths:
```tres
[ext_resource type="PackedScene" uid="uid://phoaomysa03n" path="res://scenes/bullets/universal_bullet.tscn" id="1_bullet"]
[ext_resource type="Script" uid="uid://su05ub25qwt5" path="res://scripts/core/AttackPattern.gd" id="1_pattern"]
```

Set pattern parameters:
```tres
[sub_resource type="Resource" id="Resource_pattern"]
script = ExtResource("1_pattern")
pattern_type = 6  # BURST_WITH_TRACKING
bullet_count = 1
burst_count = 3
burst_interval = 0.05
min_cooldown = 0.0833
bullet_speed = 1500.0
bullet_lifetime = 2.0
direction_type = 0  # FIXED
base_direction = Vector2(0, -1)
```

Apply bullet speed via `base_modifiers`:
```tres
[resource]
script = ExtResource("4_item")
damage_base = 10.0
cooldown_sec_base = 0.1
base_modifiers = {
    "bullet_speed": 1500.0
}
```

#### 4. Handle Visual Configuration Issues

**Problem**: `universal_bullet.tscn` has a default `movement_config` that applies unwanted initial rotation.

**Solution**: Clear default `movement_config` when pattern doesn't specify one:
```gdscript
func _spawn_bullet(pattern: AttackPattern, direction: Vector2, spawn_pos: Vector2) -> bool:
    var bullet = pattern.bullet_scene.instantiate()

    # Clear default movement_config if pattern doesn't specify one
    if not pattern.bullet_movement_config and "movement_config" in bullet:
        bullet.movement_config = null

    parent.add_child(bullet)
    # ... rest of initialization
```

#### 5. Add to Player Save Data

Edit `resources/data/default_player_save.json`:
```json
{
    "attack_cores": [
        {
            "id": "attackcore_triple_burst",
            "enchantments": []
        }
    ]
}
```

#### 6. Create Art Assets
- `assets/gfx/sprites/bullet_*.png` - Bullet sprite
- `assets/gfx/sprites/icon_magic_*.png` - UI icon

#### 7. Write Comprehensive Tests

Create `tests/unit/*FeatureTest.gd`:
```gdscript
func test_pattern_type_enum_exists() -> void:
    assert_int(AttackPattern.PatternType.BURST_WITH_TRACKING).is_equal(6)

func test_burst_with_tracking_integration() -> void:
    # Test full firing cycle
    _core.trigger()
    await await_millis(200)

    # Verify bullets were spawned
    assert_int(_spawned_bullets.size()).is_equal(3)

    # Verify cannot fire while bullets exist
    _core.trigger()
    assert_int(_spawned_bullets.size()).is_equal(3)  # No new bullets
```

### Common Pitfalls and Solutions

#### Resource File Format Errors
**Error**: `Failed loading resource: res://resources/data/attackcore_*.tres`

**Cause**: Using file paths instead of ExtResource IDs:
```tres
# ❌ WRONG
bullet_scene = "res://scenes/bullets/universal_bullet.tscn"

# ✅ CORRECT
bullet_scene = ExtResource("1_bullet")
```

#### Continuous Firing Issues
**Problem**: Attack fires once but doesn't continue

**Causes**:
1. Missing `trigger()` call after bullet destruction
2. `min_cooldown` not elapsed when retrying
3. `auto_start` not properly handling pattern state

**Solution**: Ensure `_on_projectile_destroyed()` waits for `min_cooldown` before calling `trigger()`

#### Initial Bullet Rotation
**Problem**: Bullets face wrong direction for 1 frame

**Cause**: Scene's default `movement_config` applied during `_ready()` before pattern configuration

**Solution**: Clear `movement_config` before `add_child()` if pattern doesn't specify one

#### Distance-Based Cooldown vs Min Cooldown
**Behavior**:
- `cooldown_sec` can be reduced by distance modifiers
- `min_cooldown` is an absolute minimum that cannot be bypassed
- Both must be satisfied for firing to succeed

### Testing Checklist
- [ ] Pattern type enum added
- [ ] Execution function implemented
- [ ] Firing conditions validated
- [ ] Bullet tracking working (if applicable)
- [ ] Resource file loads without errors
- [ ] Appears in player inventory
- [ ] Fires correctly in-game
- [ ] Continuous firing works
- [ ] Min cooldown respected
- [ ] Works near enemies/screen edge
- [ ] All unit tests pass
- [ ] Visual appearance correct (no rotation issues)