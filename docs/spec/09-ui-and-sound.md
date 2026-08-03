# User interface and sound — §30–31

Implemented by `ui/hud.gd`, `ui/ink_ui.gd` (the shared builder), `ui/instructions.gd`,
`ui/profile_select.gd`, `ui/result_screen.gd`, `ui/debug_overlay.gd`, and
`autoload/sound_bank.gd`.

**Screens are built in code, not authored scenes.** One builder keeps five screens
consistent, and they will churn while control profiles are compared.

**Partially implemented.** The top regions have been live since milestone 1. The
bottom regions were reserved as empty containers so a later milestone could drop in
without moving a layout testers had already learned — and milestone 2 is now doing
exactly that, uncommitted: `ui/defender_portrait.gd`, `ui/spell_button.gd` and
`ui/mana_bar.gd` exist, alongside 232 changed lines in `ui/hud.gd`. The §30.6 world
feedback layer is still untouched. The full interface arrives with milestone 6.

Before adding a `Control`, read the `set_anchors_preset()` trap in
[`../engine-notes.md`](../engine-notes.md). It has already blanked one screen and
silently broken another.

## 30. User interface

### 30.1 Top-left area — implemented

The top-left area shows cargo health.

The area also shows cargo speed and terrain factor.

### 30.2 Top-center area — implemented

The top-center area shows distance to the final portal.

The area also shows the threat value and run timer.

### 30.3 Bottom-left area — reserved, empty

The bottom-left area shows four defender portraits.

Each portrait shows health, state, and selection.

A downed portrait shows the remaining downed time.

### 30.4 Bottom-center area — reserved, empty

The bottom-center area shows defender order controls.

The control labels change for the active defender method.

### 30.5 Bottom-right area — reserved, empty

The bottom-right area shows three spell controls.

Each control shows mana cost and cooldown.

A mana bar appears above the spell controls.

### 30.6 World feedback — not implemented

A line connects a defender to its direct target.

The line appears only for a direct target order.

A dashed circle shows the active defender leash radius after an order.

A short arrow shows a defender return action.

Damage values do not appear as floating numbers.

Health bars appear only after damage.

## 31. Sound design

The MVP can use simple placeholder sounds.

Each player action must have one clear sound.

| Action | Sound |
|---|---|
| Cargo speed change | one short click |
| Defender order | one paper tap |
| Spell cast | one ink stroke |
| Cargo damage | one paper tear |
| Portal cast | continuous low tone |

The MVP does not require music.

`SoundBank` plays real placeholder WAVs from `assets/audio/`, not stubs.
