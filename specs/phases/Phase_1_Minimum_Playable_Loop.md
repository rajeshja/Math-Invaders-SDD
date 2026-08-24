# Phase 1 --- Minimum Playable Loop

**Goal:** the first fully playable slice --- one background, one player,
one enemy, one hardcoded question --- already built on real (or
correctly-sized placeholder) art rather than colored rectangles.

**Source docs:** Build Plan §Phase 1, Spec §1 (design priority), §3
(screen layout), §4 (core loop, steps 1--4 simplified), §7 (asset
table), Tech Stack §2 (scene structure), §7 (sprite wiring).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR1.1 --- `Main.tscn` exists with the top-level structure from Tech
    Stack §2 (`Background`, `GameWorld` with
    `Player`/`Enemies`/`Bullets`, `HUD`, `QuestionPanel`), even though
    most sub-parts are minimal in this phase.
-   FR1.2 --- `background_space.png` (or its placeholder) renders
    full-screen behind everything, static --- no scroll/parallax yet.
-   FR1.3 --- The `Player` node uses the real `player_ship.png` sprite
    (or placeholder), fixed near the bottom above the question panel,
    per Spec §3 layout.
-   FR1.4 --- Exactly **one** enemy is on screen, using
    `enemy_ship_addition.png` (or placeholder), positioned near the top
    of the play area.
-   FR1.5 --- Exactly **one hardcoded addition question** (e.g., "What
    is 7 + 5?") is displayed in the question panel with 4 answer
    buttons, styled with `question_panel_bg.png` and
    `answer_button_normal.png` (not default Godot theme buttons).
-   FR1.6 --- Tapping the correct answer button removes the enemy
    (`queue_free()` or `visible = false`, no bullet/animation yet) and
    increments a plain-text score display by 1.
-   FR1.7 --- Tapping any incorrect answer button leaves the enemy and
    question unchanged in this phase --- no score change, question
    remains displayed and answerable again. The lives/damage consequence
    is explicitly deferred to Phase 2/4 and must not be mistaken for the
    final gameplay behavior.
-   FR1.8 --- The game is playable end-to-end on both touch (or mouse,
    for desktop testing) input.

### Non-Functional Requirements

-   NFR1.1 --- No `question_generator.gd`/strategy pattern yet --- the
    question is a hardcoded literal in this phase (Strategy Pattern
    lands in Phase 2).
-   NFR1.2 --- No bullet sprite/animation, no wave logic, and no lives
    consequence are implemented in this phase; these are introduced in
    later phases. The final game does not use a health pool.
-   NFR1.3 --- All visible elements must use real or placeholder art at
    final dimensions (Spec §1, "Art priority") --- no `ColorRect`
    stand-ins for player/enemy/UI.

### Out of Scope

-   Question generation logic, multiple categories, bullets, wave
    formations, health/lives --- all later phases.

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **Build `Main.tscn` skeleton** matching Tech Stack §2:
    -   `Background` (`Node2D`) → child `Sprite2D`/`TextureRect` using
        `background_space.png`, anchored/stretched full-screen.
    -   `GameWorld` (`Node2D`) → children `Player`, `Enemies` (empty
        `Node2D` container for now), `Bullets` (empty `Node2D`
        container, unused this phase).
    -   `HUD` (`CanvasLayer`) → a single `ScoreLabel` (plain `Label`,
        default theme is fine here --- HUD art polish is a later phase).
    -   `QuestionPanel` (`CanvasLayer`/`Control`) → `QuestionLabel` +
        `AnswerButtons` (`GridContainer` of 4 `Button` nodes).
2.  **Player node**: create `player.tscn` with a `Sprite2D` referencing
    `player_ship.png`; instance it under `GameWorld/Player`; position
    fixed near bottom per Spec §3 ASCII layout. `player.gd` can be a
    near-empty stub for now (no firing logic yet --- that's Phase 2's
    bullet work).
3.  **Enemy node**: create `enemy.tscn` with a `Sprite2D` referencing
    `enemy_ship_addition.png`; instance one copy under
    `GameWorld/Enemies`, positioned near the top. `enemy.gd` stub with
    just a reference the Main scene can call to remove it.
4.  **Question panel art**: apply `question_panel_bg.png` as the panel's
    background (`NinePatchRect`/`TextureRect`), and set each
    `AnswerButtons` child `Button`'s theme/texture to
    `answer_button_normal.png` (normal state only --- pressed-state art
    is Phase 8 polish, but if trivial to wire now, no harm).
5.  **Hardcode the question**: in `Main.gd` (or a small `main.gd`
    controller script), set `QuestionLabel.text = "What is 7 + 5?"`, and
    set the 4 `Button` labels to one correct value (`12`) and three
    plausible wrong values (e.g., `11`, `13`, `10`) in a randomized
    button position.
6.  **Wire answer handling**: connect each `Button.pressed` signal to a
    single handler in `Main.gd` that checks whether the tapped button's
    value equals the correct answer:
    -   Correct → remove the enemy node, increment and redraw
        `ScoreLabel` (plain text, e.g., `"Score: 1"`).
    -   Incorrect → no-op (question stays as-is, remains tappable).
7.  **Manual playtest pass**: run on desktop with mouse, and ideally on
    a touch device/emulator, confirming the full loop (see question →
    tap correct → enemy disappears + score updates; tap wrong → nothing
    happens).

------------------------------------------------------------------------

## 3. Testing Plan

No new pure-logic classes are introduced this phase (the question is
hardcoded, not generated), so **no GUT unit tests are required yet** per
the Tech Stack's testing strategy --- Phase 2 is where
`question_strategy`/`question_generator` first become unit-testable.
This phase is verified manually.

### Manual Test Checklist

  -----------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -----------------------
  1                       Launch game             Background, player
                                                  ship, one enemy, and
                                                  the question panel with
                                                  4 buttons all render
                                                  using real/placeholder
                                                  art (no colored
                                                  rectangles)

  2                       Read question panel     Shows "What is 7 + 5?"
                                                  and 4 distinct answer
                                                  buttons

  3                       Tap the correct answer  Enemy disappears from
                          (12)                    screen; score label
                                                  updates from 0 → 1

  4                       Tap an incorrect answer Nothing visibly
                                                  changes; enemy remains;
                                                  score remains
                                                  unchanged; question
                                                  still shown

  5                       Tap correct answer      Same correct-path
                          after a prior wrong tap behavior as #3 ---
                                                  wrong taps don't break
                                                  subsequent correct taps

  6                       Resize/run on a         Layout holds up
                          different aspect device reasonably in portrait;
                          or emulator             no gross stretching of
                                                  art assets
  -----------------------------------------------------------------------

**Definition of Done:** a person can open the game, see real art (not
placeholders-as-rectangles) for background/player/enemy/question-UI,
answer the single hardcoded question, and observe the enemy-removal +
score-increment on a correct tap, with wrong taps being safe no-ops. All
items in the manual checklist pass.


## 4. Later Wrong-Answer Contract

Phase 1 remains a minimal slice, but its wrong-answer behavior must not be
used as the contract for later phases. From Phase 2 onward, an incorrect
answer produces the configured life consequence and red button feedback; the
formation never descends because of a wrong answer. The default question
attempt count is one.
