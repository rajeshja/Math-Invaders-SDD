# Math Invaders (Godot Edition): Game Specification

## 1. Game Overview

**Math Invaders** is a portrait-mode mobile math game built in Godot. Players defend against waves of enemy ships by answering multiple-choice math questions. Answering correctly fires a bullet that destroys the targeted enemy; answering wrong (or running out of time) lets an enemy advance or attack the player.

**Target audience:** Primary-school children (ages 6–12), starting with simple 1–2 digit addition/subtraction/multiplication/division, scaling up to larger numbers and new concepts (primes, factors, etc.) as players progress.

**Design priority:** Something playable exists from the very first build — a ship, one enemy, one question, and a working shoot-on-correct-answer loop — before waves-of-10, levels, and other systems are layered on.

**Art priority:** The player's own image assets (ships, background, question/answer UI, etc.) are used starting in the first playable build — not swapped in at the end as "polish." See Section 7 for the full sprite list and Section 8 for how integration is staged across phases.

---

## 2. Wave & Level Structure

Rather than enemies spawning continuously and indefinitely, gameplay is broken into **fixed screens ("waves")** of exactly **10 enemies each**, and waves are grouped into **levels**:

- **Wave:** one screen of gameplay = **all 10 enemies appear on screen at once** when the wave begins, all drawn from a **single math category**. For example, "Wave 1: Addition" starts with 10 enemy ships visible, each tied to an addition question.
- **Visible depletion:** the player answers one question at a time (tied to the currently-targeted enemy), and that enemy is destroyed/removed on a correct answer. The remaining enemies stay visible on screen, so the player can see the formation shrink from 10 down to 0 as they answer correctly — this visible reduction is the core feedback loop for a wave.
- **Level:** a set of waves. A level cycles through the core categories in sequence, e.g.:
  - Level 1 → Wave 1: Addition (10 enemies) → Wave 2: Subtraction (10 enemies) → Wave 3: Multiplication (10 enemies) → Wave 4: Division (10 enemies)
  - When a wave's 10 enemies are all eliminated, a **new set of 10 enemies appears** for the next wave/category.
  - Completing all waves in a level advances the player to the **next level**.
- **Progression across levels:** each new level keeps the same category sequence but raises difficulty (larger numbers, tighter time pressure), and later levels introduce new categories as additional waves (e.g., a "Prime Numbers" wave added once players reach an advanced level).
- At the end of a wave, a brief transition ("Wave Complete!") shows before the next wave's fresh set of 10 enemies appears. At the end of a level, a "Level Complete!" transition shows before the next level begins.

This replaces the original "continuous descending waves" concept with a **structured, per-category mini-level format** where the full 10-enemy formation is visible at once and visibly shrinks as the player answers correctly — making progress legible to a young player ("I'm on Level 2, Subtraction, 4 enemies left") and making it straightforward to control exactly which math skill is being practiced at any moment.

---

## 3. Screen Layout (Portrait, e.g. 720×1280 base resolution)

```
┌─────────────────────────────┐
│ Score:120  Lvl 2  ♥♥♥  🚀x2  │  ← HUD (top)
│         Subtraction  6/10    │  ← Wave/category + remaining count
│   *  E  E  E  *  E  E  ·     │
│  ·    E     E    ·   E  *    │  ← Full formation of remaining
│     E    *      E    ·       │     enemies, shrinks as answered
│      ·        *        ·     │     Deep space bg (near-black/
│                  ↑            │     dark navy, sparse stars)
│                bullet         │
│                               │
│           🚀 (player)         │  ← Player ship, fixed near bottom
├──────────────────────────────┤
│      What is 15 − 8?          │  ← Question panel
│  [ 7 ]  [ 8 ]  [ 6 ]  [ 9 ]  │  ← Answer buttons
└──────────────────────────────┘
```

- **Background:** Near-black / dark navy scene with a sparse, slowly-parallaxing starfield.
- **Player ship:** Fixed horizontal position near the bottom, above the question panel; visually fires when a correct answer is chosen.
- **Enemies:** All 10 enemies for the current wave spawn together in a formation at the start of the wave, and move downward together (or hold position and only advance on misses — see Gameplay Loop). One enemy at a time is the "active" target tied to the current question; as questions are answered correctly, that enemy is destroyed and removed, visibly shrinking the formation. If the formation (or any enemy) reaches the bottom, it costs health.
- **Question panel:** Anchored to the bottom of the screen, always visible, holding the question text and 4 tappable answer buttons.
- **HUD (top of screen):**
  - Score
  - **Level** (new)
  - Health / lives
  - **Current wave category + enemies remaining in the wave** (e.g., "Subtraction 6/10 remaining") (new)

---

## 4. Core Gameplay Loop

1. When a wave begins, its category (e.g., Addition) is set, and **all 10 enemies spawn together** in a formation at the top of the screen. A question is generated for the current difficulty and linked to one "active" enemy (e.g., the frontmost/lowest one).
2. The question and its 4 choices are shown in the question panel, tied to the active enemy.
3. Player taps an answer button.
4. **Correct:** player ship fires a bullet at the active enemy; the enemy is destroyed and removed from the formation — the player visibly sees the remaining count drop (e.g., 10 → 9); score increases; wave progress updates (e.g., "6/10 remaining"); a new question loads, linked to the next active enemy.
5. **Incorrect:** ship "misses"; the active enemy survives and the whole formation advances one step closer to the player (or just the active enemy, depending on tuning); on a subsequent wrong answer or an enemy reaching the bottom, the player loses health.
6. **Time pressure (later phase):** a timer/formation-descent creates urgency — if the question isn't answered before the enemy formation reaches the player, it counts as a miss.
7. Health reaches 0 → lose a life → remaining formation resets to a safe distance, or game over if no lives remain.
8. When all 10 enemies in the current wave are eliminated → "Wave Complete" → a **fresh set of 10 enemies** spawns for the next wave (next category).
9. When all waves in the level are cleared → "Level Complete" → next level begins with increased difficulty (and, at later levels, additional categories), again starting with a full set of 10 enemies.
10. Game over → compare score to stored high score, update if beaten, show result screen with "Play Again."

---

## 5. Educational Content Progression

### Stage A — Launch content (earliest playable waves)
- **Wave categories, in order:** Addition → Subtraction → Multiplication → Division
- 1–2 digit operands (e.g., 7+5, 23−9, 6×7, 42÷6)
- 4 answer choices per question: 1 correct + 3 plausible distractors (values near the correct answer or results of common mistakes, e.g., off-by-one or wrong operation)

### Stage B — Expanded difficulty (later levels)
- Same four wave categories, but with larger numbers (2–3 digit operands)
- Enemy descent speed / time pressure increases with level

### Stage C — New concepts (advanced levels)
- New wave categories added to the rotation: prime number identification, factors/multiples, simple fractions/percentages (stretch goal)

### Distractor & Difficulty Rules
- Distractors avoid duplicates and nonsensical values.
- Difficulty (number range, operand size, time limit) is parameterized per level, not hardcoded per question — the same category can be asked at many difficulty tiers as levels increase.

---

## 6. HUD Requirements (Updated)

The HUD must always show, during play:
1. **Score** — running total, top of screen
2. **Level** — current level number
3. **Wave category + enemies remaining** — e.g., "Multiplication 7/10 remaining", so the player knows what skill they're practicing and can see, both in the HUD text and in the shrinking enemy formation, how far through the current wave they are
4. **Health** — remaining health (e.g., heart icons or a bar)
5. **Lives** — remaining lives

High scores are tracked and persisted across sessions (see Tech Stack document for storage approach).

---

## 7. Sprite & Image Asset List

All visual elements should be supplied as PNG files with transparency where noted, sized for a **720×1280 portrait base resolution** (Godot will scale for other device sizes). Godot doesn't require power-of-two dimensions, but matching the sizes below keeps things from stretching or blurring when the game scales to different screen sizes.

| Asset | File name (suggested) | Dimensions (px) | Transparency? | Notes |
|---|---|---|---|---|
| Deep space background | `background_space.png` | 720×1280 (or 720×2560 if a taller image is supplied for slow vertical scroll/parallax) | No | Very dark navy/black, sparse stars baked in, or paired with a separate star overlay below |
| Starfield overlay (optional separate layer) | `starfield_overlay.png` | 720×1280, vertically tileable | Yes | Sparse star dots only; layered above the solid background for a subtle parallax scroll effect |
| Player ship | `player_ship.png` | 128×128 | Yes | Faces upward; fixed near the bottom of the screen above the question panel |
| Player bullet/projectile | `player_bullet.png` | 16×48 | Yes | Travels upward from the player ship to the active enemy |
| Enemy ship — Addition | `enemy_ship_addition.png` | 96×96 | Yes | One visual variant per wave category so the player can visually tell categories apart |
| Enemy ship — Subtraction | `enemy_ship_subtraction.png` | 96×96 | Yes | |
| Enemy ship — Multiplication | `enemy_ship_multiplication.png` | 96×96 | Yes | |
| Enemy ship — Division | `enemy_ship_division.png` | 96×96 | Yes | |
| Enemy ship — Advanced/Prime (Stage C) | `enemy_ship_prime.png` | 96×96 | Yes | Added later alongside the Prime strategy; same dimensions as the other enemy sprites |
| Enemy explosion / destruction effect | `enemy_explosion_spritesheet.png` | 512×128 (4 frames @ 128×128) | Yes | Played when an enemy is destroyed on a correct answer |
| Question panel background | `question_panel_bg.png` | 720×360 | Optional | Bottom-anchored panel frame behind the question text and answer buttons |
| Answer button — normal state | `answer_button_normal.png` | 320×100 | Yes | Sized to fit 4 buttons in a grid within the question panel; large enough for a child's tap (44px+ touch target) |
| Answer button — pressed/selected state | `answer_button_pressed.png` | 320×100 | Yes | Shown briefly on tap, before correct/incorrect feedback resolves |
| Health icon (heart) | `heart_icon.png` | 48×48 | Yes | Repeated in the HUD to show remaining health |
| Lives icon (mini ship) | `life_icon.png` | 48×48 | Yes | Repeated in the HUD to show remaining lives |
| Wave Complete banner | `wave_complete_banner.png` | 600×200 | Yes | Shown briefly between waves |
| Level Complete banner | `level_complete_banner.png` | 600×200 | Yes | Shown briefly between levels |
| Game Over background/frame | `game_over_bg.png` | 720×1280 | Optional | Can reuse `background_space.png` with an overlay panel instead, if a dedicated image isn't supplied |

If a listed asset isn't available up front, a same-dimension placeholder (solid color or simple shape saved at the exact target size) should be used so the real asset can be dropped in later without resizing or re-laying-out any scene.

---

## 8. Asset Integration Approach

Image assets are **not** treated as a final-polish step. They're introduced starting in the first playable phase, using whichever real assets are available at that point, with additional assets (category-specific enemy variants, effects, banners) layered in incrementally as later systems (waves, levels, transitions) are built — rather than the whole game running on colored rectangles until a single "art pass" at the end. See the Build Plan document for the phase-by-phase breakdown of exactly when each asset is introduced.
