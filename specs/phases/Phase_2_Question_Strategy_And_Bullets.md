# Phase 2 --- Question Strategy Pattern & Bullets

**Goal:** replace the hardcoded question with procedurally generated
addition/subtraction questions via the Strategy Pattern, add real bullet
visuals on correct answers, and establish the wrong-answer event that
will consume lives. Wrong answers do **not** move the enemy or
formation. The tapped wrong answer flashes red; the default one-attempt rule
then advances to a new question.

**Source docs:** Build Plan §Phase 2, Tech Stack §3 (Strategy Pattern
architecture in full), §7 (bullet sprite wiring, enemy texture-swap), §8
(testing strategy for strategies/generator), Spec §5 (Stage A content
rules, distractor rules), §7 (`player_bullet.png`, enemy sprite table).

------------------------------------------------------------------------

## 1. Requirements

### Functional Requirements

-   FR2.1 --- `question_strategy.gd` exists as a base class defining the
    contract: `generate(difficulty: int) -> Dictionary` returning
    `{ question_text, correct_answer, choices: [] }` (Tech Stack §3).
-   FR2.2 --- `addition_strategy.gd` and `subtraction_strategy.gd` exist
    under `scripts/questions/strategies/`, each extending
    `question_strategy.gd` and implementing `generate(difficulty)` per
    Spec §5 Stage A rules: 1--2 digit operands, 4 choices (1 correct + 3
    plausible, non-duplicate distractors).
-   FR2.3 --- `question_generator.gd` exists as the dispatcher: holds a
    category-name → strategy-instance map, exposes
    `generate_question(category: String, difficulty: int) -> Dictionary`,
    and is the **only** class `Main`/gameplay code talks to for
    questions.
-   FR2.4 --- `Main.gd` (or equivalent) calls
    `QuestionGenerator.generate_question("addition", difficulty)` (or
    `"subtraction"`) instead of using a hardcoded literal. **Until
    `LevelManager.gd` is introduced in Phase 5, `difficulty` is a
    hardcoded default of `1` owned by the Phase 2 caller (`Main.gd` or
    equivalent).**
-   FR2.5 --- On a correct answer, a real `player_bullet.png` sprite
    instance visibly travels from the player position toward the active
    enemy's position (replacing Phase 1's instant disappear). Per the
    later parallel-resolution contract (Phase 4 FR4.13), gameplay ---
    scoring and the next question --- resolves at the moment the
    bullet launches, but the target enemy's destruction waits until the bullet arrives.
-   FR2.6 --- On a wrong answer, the active enemy survives and remains
    in place. The tapped answer button flashes red. The wrong-answer event
    is emitted/handled as the gameplay damage trigger; it must not move the
    enemy. With the default `tries_per_question = 1`, the question is retired
    and a new question is loaded after the feedback. If the effective attempt
    count is greater than 1, the same question remains active until its
    attempt limit is exhausted.
-   FR2.7 --- The enemy's `Sprite2D` texture is set **per-instance** at
    spawn/category-switch time --- `enemy_ship_addition.png`
    vs. `enemy_ship_subtraction.png` --- confirming the single-scene,
    texture-swap approach from Tech Stack §7, rather than separate enemy
    scenes per category.
-   FR2.8 --- The player can experience both categories in the same
    session (e.g., toggle or sequential for manual testing purposes ---
    full wave sequencing is Phase 3, so a simple manual/dev-triggered
    category switch is sufficient here).
-   FR2.9 --- Wrong-answer question advancement follows the effective
    `tries_per_question` value. The default value is `1`, so a wrong answer
    advances to a new question after red feedback. A level may override this
    with a higher value, in which case the same question remains active until
    the attempt limit is exhausted.

### Non-Functional Requirements

-   NFR2.1 --- Strategies must have **no dependency on the scene tree**
    --- `generate(difficulty)` is pure logic, callable and testable in
    isolation (Tech Stack §8).
-   NFR2.2 --- Adding a new category strategy later must require no
    changes to `addition_strategy.gd`/`subtraction_strategy.gd` or to
    code that calls `question_generator.gd` --- only a new file + one
    registration line.
-   NFR2.3 --- Distractor generation must never produce duplicate values
    or a duplicate of the correct answer (Spec §5).
-   NFR2.4 --- Wrong-answer handling is separated from movement: a wrong
    answer produces a single damage event, but movement is not a side
    effect of that event.

### Out of Scope

-   Multiplication/division strategies (Phase 3).
-   Wave/formation logic, 10-enemy spawns (Phase 3).
-   The full Game Over/lives HUD implementation (formalized in Phase 4).
    Phase 2 defines the wrong-answer event contract; the final
    consequence is one life lost per wrong answer, with no descent
    mechanic.

------------------------------------------------------------------------

## 2. Detailed Implementation Plan

1.  **`question_strategy.gd`**: define as a
    `class_name QuestionStrategy extends RefCounted` (or `Node`, per
    team preference) with a virtual
    `generate(difficulty: int) -> Dictionary` that either raises
    `push_error` if unimplemented or is left as a documented contract
    for subclasses to override. Optionally add shared
    distractor-building helpers here or in a small `distractor_utils.gd`
    (Tech Stack §3).
2.  **`addition_strategy.gd`**:
    -   `generate(difficulty)`: pick two operands sized by `difficulty`
        (Stage A: 1--2 digit), compute `correct_answer = a + b`.
    -   Build 3 distractors using plausible-mistake patterns
        (off-by-one, transposed digits, wrong-operation result),
        ensuring no duplicates among distractors or against the correct
        answer.
    -   Shuffle the 4 choices before returning; return
        `{ question_text: "What is %d + %d?" % [a, b], correct_answer: a+b, choices: [...] }`.
3.  **`subtraction_strategy.gd`**: mirror addition's structure; guard
    against negative results if that's undesired for the target age
    group (e.g., ensure `a >= b` for Stage A).
4.  **`question_generator.gd`**:
    -   Internal dictionary:
        `{"addition": AdditionStrategy.new(), "subtraction": SubtractionStrategy.new()}`.
    -   `generate_question(category, difficulty)`: looks up the
        strategy; if found, delegates and returns its result; if not
        found, fail gracefully (e.g., `push_error` + return a safe
        empty/default `Dictionary` rather than crashing) --- this
        graceful-failure path is explicitly unit-tested.
5.  **Wire `Main.gd`** to call
    `QuestionGenerator.generate_question(current_category, difficulty)`
    after each correct answer (and at game start) instead of the Phase 1
    hardcoded string, populating `QuestionLabel` and the 4 buttons from
    the returned `Dictionary`.
6.  **Bullet visuals**: create `bullet.tscn`/`bullet.gd` using
    `player_bullet.png`; on correct answer, instance a bullet at the
    player's position and move it toward the active enemy's position.
    Destruction and score resolve immediately at launch --- the arrival
    callback is presentation-only cleanup --- replacing the instant
    Phase 1 removal without making the player wait out the flight.
7.  **Wrong-answer event**: report one incorrect-answer event to the
    gameplay state layer, keep the active enemy stationary, and leave
    the same question or the next question according to the effective attempt limit. Do not add any downward movement.
8.  **Texture swap**: in `enemy.tscn`'s spawn/setup code (called from
    `Main.gd` for now, pending `WaveManager` in Phase 3), set the
    `Sprite2D.texture` based on the active category string (`"addition"`
    → `enemy_ship_addition.png`, `"subtraction"` →
    `enemy_ship_subtraction.png`).
9.  **Write GUT tests** (see Testing Plan) alongside each script as it's
    built, not after.

------------------------------------------------------------------------

## 3. Testing Plan

This is the first phase with real GUT coverage, per Tech Stack §8. Tests
live under `test/unit/questions/`, mirroring `scripts/questions/`.

### Automated Tests (GUT)

**`test_addition_strategy.gd`** - `generate(difficulty)` returns a
`correct_answer` equal to the actual sum of the operands used. -
Returned `choices` contains exactly one value equal to
`correct_answer`. - `choices` has exactly 4 entries, all unique (no
duplicate distractors, no distractor equal to the correct answer). -
Operand size scales sensibly with `difficulty` (e.g., higher difficulty
allows/produces larger operands than lower difficulty, per Stage A/B
ranges).

**`test_subtraction_strategy.gd`** - Same shape as addition: correct
result verified, exactly one correct choice among 4 unique choices, no
negative-result questions (if that's the chosen rule), difficulty
scaling sanity.

**`test_question_generator.gd`** -
`generate_question("addition", difficulty)` dispatches to
`AdditionStrategy` and returns a well-formed `Dictionary` (has
`question_text`, `correct_answer`, `choices`). -
`generate_question("subtraction", difficulty)` dispatches correctly. -
`generate_question("not_a_real_category", difficulty)` handles the
unknown category gracefully --- no crash/uncaught error, and either
returns a defined "empty"/error result or emits a clear, catchable error
signal (exact contract confirmed with the team, but the test asserts
*some* safe defined behavior).

### Manual Test Checklist

  -------------------------------------------------------------------------------
  \#                      Scenario                Expected Result
  ----------------------- ----------------------- -------------------------------
  1                       Play an addition        Bullet sprite visibly travels
                           question, answer        from player to enemy; next
                           correctly               question is ready while the
                                                   bullet is still in flight;
                                                   enemy destroyed on hit;
                                                   score +1

  2                       Play an addition        Enemy and formation remain
                          question, answer        stationary; the same question
                          incorrectly             remains displayed for retry;
                                                  exactly one wrong-answer event
                                                  is emitted

  3                       Switch to a subtraction Enemy sprite swaps to
                          question                `enemy_ship_subtraction.png`;
                          (dev-triggered)         question text/choices are
                                                  subtraction-appropriate

  4                       Answer several          No duplicate-looking answer
                          questions in a row      choices ever appear; correct
                                                  answer position varies (not
                                                  always the same button slot)

  5                       Run full GUT suite      `test_addition_strategy`,
                                                  `test_subtraction_strategy`,
                                                  `test_question_generator` all
                                                  pass, 0 failures
  -------------------------------------------------------------------------------

**Definition of Done:** questions are procedurally generated (not
hardcoded) for addition and subtraction, correct answers produce visible
bullet-travel-then-destroy feedback, wrong answers leave the active
question/enemy in place and emit exactly one damage event, enemy art
correctly reflects the active category, and all three new GUT test files
pass under both the editor GUT panel and CLI.


## 4. Question Attempt & Feedback Details

- Add `tries_per_question` to the question-flow state, defaulting to the
  global Project Setting value resolved through `GameConfig`.
- Track attempts used for the currently displayed question and reset that
  counter only when a new question is generated.
- On incorrect tap: immediately flash the tapped `Button` red, consume one
  life, increment the question's attempt counter, and then either load the
  next question (attempt limit reached) or leave the same question active
  for another attempt.
- The default configuration is exactly one attempt, so the normal gameplay
  path is: wrong tap → red flash → life lost → next question.
- On correct tap, clear the attempt counter as part of loading the next
  question.
- If the wrong answer causes Game Over, do not load another question.
- The red flash is feedback, not a new gameplay state and must not introduce
  a second life loss or duplicate answer event.

Testing must cover both the default one-attempt path and a multi-attempt
configuration supplied by `GameConfig`.
