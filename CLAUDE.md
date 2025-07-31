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
Run unit tests with gdUnit4:
```bash
# Windows
addons/gdUnit4/runtest.cmd --godot_bin "path/to/godot.exe"
# Or with environment variable
set GODOT_BIN=path/to/godot.exe
addons/gdUnit4/runtest.cmd

# Linux/Mac
addons/gdUnit4/runtest.sh --godot_bin /path/to/godot
# Or with environment variable
export GODOT_BIN=/path/to/godot
addons/gdUnit4/runtest.sh
```

Test files are located in:
- `tests/unit/` - Unit tests
- `tests/integration/` - Integration tests
- `tests/stubs/` - Test helper classes

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