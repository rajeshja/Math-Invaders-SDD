# Phase 8 --- Effects, Animation & Audio Polish

**Goal:** layer presentation polish --- destruction animation, parallax
starfield, damage feedback, button press states, sound, and music --- on
top of the fully-functional game from Phases 0--7, without touching any
underlying gameplay logic.

**Source docs:** Build Plan §Phase 8, Spec §7
(`enemy_explosion_spritesheet.png`, `starfield_overlay.png`,
`answer_button_pressed.png`, remaining placeholder assets), Tech Stack
§7 (Image Asset Integration --- explicitly documents the
starfield-over-background parallax wiring this phase implements; the
explosion-spritesheet and button-pressed wiring are new implementation
decisions for this phase, not already specified elsewhere), §8 (note
that visual/audio-heavy scripts are primarily verified through manual
playtesting).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR8.1 --- On a correct answer, the destroyed enemy plays the
    `enemy_explosion_spritesheet.png` animation (4 frames @ 128×128) at
    its position before being removed, replacing the instant "disappear"
    behavior used since Phase 1.
-   FR8.2 --- The static background from Phase 1 is replaced by
    `starfield_overlay.png` layered above `background_space.png`,
    animated with a slow scroll/parallax effect, per Tech Stack §7.
-   FR8.3 --- Taking damage from a wrong answer (i.e.,
    `GameManager.take_damage()` firing, per Phase 4) triggers a
    screen-shake and/or flash visual effect.
-   FR8.4 --- Answer buttons swap to `answer_button_pressed.png` on
    tap-down and revert to `answer_button_normal.png` on
    release/resolution, replacing default Godot theme feedback, for both
    correct and incorrect taps.
-   FR8.5 --- Sound effects play for: firing (on correct answer), hit
    (enemy destroyed), miss (wrong answer), wave complete, level
    complete, and game over --- each triggered from the existing
    corresponding signal/event; no new gameplay signals are introduced.
-   FR8.6 --- Background music loops during gameplay and stops (or
    pauses) when `GameManager` enters `GAME_OVER`.
-   FR8.7 --- Any placeholder images remaining from Spec §7's asset
    table that weren't already replaced in an earlier phase are swapped
    for final art in this phase.

### Non-Functional Requirements

-   NFR8.1 --- All additions in this phase are purely presentational: no
    changes to `GameManager`, `WaveManager`, `LevelManager`,
    `HighScoreManager`, or any question strategy's underlying
    state/logic, and every existing GUT test from Phases 2--7 continues
    to pass unmodified.
-   NFR8.2 --- Explosion animation and screen-shake/flash effects must
    not block or delay the underlying game-state transition --- e.g.,
    `enemies_remaining`/HUD updates and the next question loading happen
    immediately on the logic side, decoupled from how long the visual
    animation takes to finish.

### Out of Scope

-   Any new gameplay systems, categories, or scoring rules.
-   Export/build configuration (Phase 9).
-   Playtesting-driven balance changes (Phase 10).

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **Enemy destruction animation**: add an `AnimatedSprite2D` (or
    `Sprite2D` + `AnimationPlayer`) to `enemy.tscn` using
    `enemy_explosion_spritesheet.png`'s 4 frames. On destruction, play
    the explosion animation and defer the node's `queue_free()` until
    the animation finishes (or a short fixed timer), while
    `WaveManager.on_correct_answer()`'s logic-side updates
    (`enemies_remaining` decrement, HUD signal, next question load) fire
    immediately and are not gated on the animation, per NFR8.2.
2.  **Parallax starfield**: add `starfield_overlay.png` as a second
    layer above `background_space.png` in the `Background` node; animate
    a looping vertical offset via `AnimationPlayer` (or a `Sprite2D`
    offset tween) for a slow scroll effect.
3.  **Damage feedback**: implement a small screen-shake utility on the
    main `Camera2D` (randomized offset over a short duration) and/or a
    full-screen `ColorRect` flash overlay; trigger it from the
    wrong-answer/lives event or `lives_changed` signal (Phase 4) via a
    listener in the effects/HUD layer --- `GameManager` itself is not
    modified.
4.  **Answer button press feedback**: in `question_panel.gd`, swap each
    `Button`'s texture to `answer_button_pressed.png` on `button_down`,
    and back to `answer_button_normal.png` once the correct/incorrect
    result resolves.
5.  **Sound effects**: add `AudioStreamPlayer` nodes (or a small
    `AudioManager.gd` autoload) for each cue --- fire, hit, miss, wave
    complete, level complete, game over --- each connected to its
    existing corresponding signal (bullet-fired, enemy-destroyed,
    wrong-answer, `wave_complete`, `level_changed`/level-complete,
    `game_over`).
6.  **Background music**: add a looping `AudioStreamPlayer` for music,
    started at game start; connect to `GameManager`'s `game_over`
    handling to pause/stop it on Game Over.
7.  **Placeholder audit**: cross-check Spec §7's asset table against
    what's actually been integrated across Phases 0--7 and swap in any
    remaining placeholder-dimension images for final art.
8.  **No new automated tests are expected for this phase** --- per Tech
    Stack §8, scene-heavy visual/audio behavior is lower priority for
    unit testing and is primarily verified manually. Instead, this
    phase's testing bar is a full regression pass of the existing GUT
    suite to confirm the new signal-driven effects didn't disturb any
    underlying logic (NFR8.1).

------------------------------------------------------------------------

## 3. Testing Plan

### Automated Tests (GUT)

-   No new dedicated test file for this phase (consistent with Build
    Plan Phase 8 and Tech Stack §8's guidance that visual/audio polish
    is manually verified).
-   **Regression check:** re-run the full existing GUT suite (all
    strategy tests, `question_generator`, `WaveManager`, `LevelManager`,
    `GameManager`, `HighScoreManager`) to confirm 0 failures and no
    behavioral drift introduced by wiring new signal listeners for
    effects/audio, per NFR8.1.

### Manual Test Checklist

  --------------------------------------------------------------------------------------------------------------
  \#                      Scenario                                               Expected Result
  ----------------------- ------------------------------------------------------ -------------------------------
  1                       Answer a question correctly                            Explosion animation plays at
                                                                                 the destroyed enemy's position;
                                                                                 wave-remaining count and HUD
                                                                                 update immediately, without
                                                                                 waiting on the animation to
                                                                                 finish

  2                       Observe the background during play                     Starfield visibly
                                                                                 scrolls/parallaxes above the
                                                                                 static deep-space background

  3                       Take damage (wrong answer)                             Visible screen shake and/or
                                                                                 flash effect plays

  4                       Tap any answer button                                  Button shows the pressed-state
                                                                                 art
                                                                                 (`answer_button_pressed.png`)
                                                                                 immediately on tap-down

  5                       Play through                                           Each has its correct, distinct
                          fire/hit/miss/wave-complete/level-complete/game-over   sound cue at the right moment
                          moments                                                

  6                       Play a full session start to Game Over                 Background music loops
                                                                                 continuously during play and
                                                                                 stops/pauses at Game Over

  7                       Spot-check assets against Spec §7's table              No remaining
                                                                                 placeholder-dimension
                                                                                 solid-color images; all listed
                                                                                 assets present as final art

  8                       Run full GUT suite                                     All prior phases' tests still
                                                                                 pass, 0 failures, 0 regressions
  --------------------------------------------------------------------------------------------------------------

**Definition of Done:** the game looks and sounds like a finished mobile
game --- destruction animation, parallax background, damage feedback,
button press states, full sound effects, and looping music --- with zero
changes to underlying gameplay logic and the full existing GUT suite
still passing.


## 4. Wrong-Answer Feedback Timing

The red flash on the tapped answer button is required gameplay feedback, not
optional polish. It should be brief (roughly 150–300 ms) and should occur
immediately on the wrong tap. The next question is loaded after the feedback
when the effective attempt count has been exhausted; for the default one
attempt configuration, that means every wrong answer produces a red flash and
then a new question.

If a level allows multiple attempts, the same question remains active after
the flash until the configured number of attempts is exhausted.

The feedback must not double-consume a life or block the Game Over transition.
