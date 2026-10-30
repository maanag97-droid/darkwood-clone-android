# DarkwoodClone — Godot 4.6 Migration Guide

## What changed from the Godot 3 version

### API Replacements (all scripts updated)

| Old (Godot 3) | New (Godot 4.6) |
|---|---|
| `KinematicBody2D` | `CharacterBody2D` |
| `move_and_slide(velocity)` | `velocity = ...; move_and_slide()` |
| `onready var x = $N` | `@onready var x: Type = $N` |
| `yield(timer, "timeout")` | `await timer.timeout` |
| `connect("sig", self, "fn")` | `signal_name.connect(fn)` |
| `emit_signal("name", ...)` | `name.emit(...)` |
| `ImageTexture.new()` + `create_from_image()` | `ImageTexture.create_from_image(img)` |
| `Image.new()` + `img.load(path)` | `Image.load_from_file(path)` |
| `img.lock()` / `img.unlock()` | Removed — use `set_pixel()` directly |
| `Sprite` | `Sprite2D` |
| `Light2D` | `PointLight2D` |
| `Tween` node | `create_tween()` method-based |
| `rand_range()` | `randf_range()` |
| `BUTTON_LEFT` | `MOUSE_BUTTON_LEFT` |
| `event.scancode` | `event.keycode` |
| `Color.green` | `Color.GREEN` |
| `linear_interpolate()` | `lerp()` |
| `.empty()` | `.is_empty()` |
| `instance()` | `instantiate()` |
| `rect_size` (Control) | `size` |
| `rect_position` (Control) | `position` |

### New Features Added

#### Android Touch Controls (`scripts/TouchControls.gd`)
- Virtual left-side joystick (appears where finger touches)
- Right-side buttons: SHOOT, MELEE, RELOAD, FLASHLIGHT
- Auto-hides on non-touchscreen devices (keyboard/mouse still work)
- Joystick also sets player aim direction

#### Mobile Renderer
- `project.godot` now uses `renderer/rendering_method="mobile"`
- Better performance on Android devices

---

## Scene Setup Instructions

You need to set up these scenes manually in the Godot 4.6 editor since .tscn format changed.

### Player.tscn
```
CharacterBody2D  [script: Player.gd]
├── Sprite2D
├── CollisionShape2D  (CapsuleShape2D, radius=12, height=24)
├── Flashlight  (PointLight2D, energy=1.0, color=white)
├── MeleeArea  (Area2D)
│   └── CollisionShape2D  (CircleShape2D, radius=45)
├── HurtFlash  (ColorRect, size=full screen, color=red 0.4 alpha, z_index=10)
├── SFXShoot  (AudioStreamPlayer2D)
└── SFXFootstep  (AudioStreamPlayer2D, stream=sfx_movement_footsteps1b.wav)
```

### Enemy.tscn
```
CharacterBody2D  [script: Enemy.gd]
├── Sprite2D
├── CollisionShape2D  (CapsuleShape2D, radius=12, height=24)
├── DetectionArea  (Area2D)
│   └── CollisionShape2D  (CircleShape2D, radius=250)
├── HealthBar  (ProgressBar, size=(60,8), position=(-30,-30))
└── SFXDeath  (AudioStreamPlayer2D, stream=sfx_deathscream_alien5.wav)
```

### TouchControls.tscn  ← NEW
```
CanvasLayer  [script: TouchControls.gd, layer=15]
├── JoystickBase  (Control, position=(80,800), size=(160,160), visible=false)
│   └── Knob  (Control, size=(60,60), pivot_offset=(30,30))
├── BtnShoot  (Button, position=(1720,900), size=(140,80), text="🔫 SHOOT")
├── BtnMelee  (Button, position=(1560,900), size=(140,80), text="👊 MELEE")
├── BtnReload  (Button, position=(1720,800), size=(140,70), text="🔄 RELOAD")
└── BtnFlashlight  (Button, position=(1560,800), size=(140,70), text="🔦 LIGHT")
```

### Main.tscn
```
Node2D  [script: Main.gd]
├── World  (Node2D, script: WorldGenerator.gd)
│   ├── Ground  (Node2D)
│   ├── Trees  (Node2D)
│   ├── Props  (Node2D)
│   └── Enemies  (Node2D)
├── Player  (instance: Player.tscn)
├── DarknessOverlay  (ColorRect, anchors full rect, z_index=5, color=transparent, mouse_filter=IGNORE)
├── DayNightCycle  (Node, script: DayNightCycle.gd)
├── HUD  (CanvasLayer, script: HUD.gd, layer=10)
│   ├── (same structure as Godot 3 version)
├── TouchControls  (instance: TouchControls.tscn)  ← ADD THIS
└── GameOverScreen  (CanvasLayer, layer=20, visible=false)
    └── (same structure as Godot 3 version)
```

---

## Android Export Steps

1. In Godot 4.6: **Project → Export → Add → Android**
2. Set Package Name to match `project.godot` (e.g. `com.yourname.darkwoodclone`)
3. Set minimum SDK to **21** (Android 5.0)
4. Under Architectures, enable **arm64-v8a** (for Samsung A17 5G)
5. Enable **Internet** permission if needed
6. Click **Export Project** → choose `.apk`
7. Install via `adb install` or transfer to phone

## Performance Tips for Low-End Android

- Keep enemy count ≤ 10 at once (already done in `WorldGenerator`)
- The `Mobile` renderer is already set — avoids heavy shader overhead
- Disable shadows on `PointLight2D` nodes if FPS is low (uncheck `shadow_enabled`)
- Reduce `world_size` in `WorldGenerator.gd` from 3000 → 2000 if ground tiles lag
