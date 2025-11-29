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