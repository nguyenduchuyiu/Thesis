# GammaZero Architecture

## Abstract

GammaZero is a Lean 4 proof search system driven by language model samples. The
system does not treat the model as a trusted prover. The model proposes proof
fragments, Lean checks them, and the search graph records the exact logical
dependency between generated fragments.

The main representation is an AND/OR proof graph. A proof state is an OR node:
one successful action is enough to solve it. A skeleton action is an AND node:
all child proof states created by the skeleton must be solved. This structure
lets GammaZero combine direct tactic search with recursive decomposition.

The system works by combining several concrete mechanisms:

- custom Lean server processes that expose verification, syntax spans, and
  kernel expression trees,
- tactic attempts before decomposition,
- skeletons that expose named child obligations,
- scaffold-aware prompts and verification for subgoals,
- immediate admission of sibling obligations when a child is isolated,
- policy checks before Lean verification,
- AST-guided repair of failed Lean code into useful partial structure,
- dependency analysis over Lean expression trees,
- dense rewards for partial survival and dependency quality,
- commitment to one active skeleton with fallback to reserved skeletons,
- priority scores that favor states likely to finish an active proof,
- search with a limited number of generated actions and a limited depth.

This document describes the system at the level of data structures and control
flow. It is intended to be readable without the source code.

## 1. Objects

Lean 4 is the proof checker. A proof is accepted only when Lean accepts the
complete theorem without unresolved placeholders.

A `ProofState` contains:

- local hypotheses,
- the current goal,
- optional scaffold code,
- the index of the target `sorry` inside that scaffold,
- metadata describing the target kind.

An `Action` is one generated attempt attached to a proof state. GammaZero uses
two action types:

- `tactic`: a proof body intended to close the current target.
- `skeleton`: a proof body that introduces named `sorry` leaves as child goals.

A skeleton is not allowed to leave a naked final `sorry`. Every new unresolved
obligation must be a named local declaration such as:

```lean4
have h_step : proposition := sorry
```

This rule is important because the search tree needs stable child obligations.
The names let the system display, track, and later stitch those obligations.

## 2. AND/OR Graph

The graph is stored in `gammazero/search/graph/and_or_graph.py`.

A proof state is an OR node. It is solved if at least one attached action is
solved.

A tactic action has no children. It is solved if Lean verifies that the tactic
closes the target.

A skeleton action has child proof states. It is solved only if all required
children are solved. This is the AND part of the graph.

The graph records:

- parent state for each action,
- children of each skeleton action,
- status of every state and action,
- `r_env`, the environment reward,
- `r_dep`, the dependency reward,
- target labels for subgoal display,
- depth of each proof state.

State identity is not only the pair `(context, goal)`. For scaffolded subgoals,
the key also includes the scaffold hash, target kind, and target index. This
prevents two equal-looking goals from being merged when they belong to different
positions in different proof scaffolds.

Statuses propagate upward. When a child state is solved, its parent skeleton may
become solved. When a skeleton is solved, its parent state becomes solved. This
propagation is repeated after each batch of verified actions.

## 3. Scaffold-Aware Subgoals

GammaZero does not solve child goals as isolated theorems when the child comes
from a skeleton. Instead, it keeps a parent theorem scaffold.

Inside the scaffold:

- the current child target is represented by one `sorry`,
- sibling obligations are represented by `admit`,
- surrounding local declarations are preserved.

This design keeps Lean elaboration close to the original proof context. It also
prevents the model from accidentally solving a sibling obligation or changing
the shape of the parent proof.

When a skeleton creates children, each child receives its own scaffold. The
target child keeps the unique `sorry`. All sibling children at that level are
immediately turned into `admit`. This invariant is inherited through deeper
levels of the search tree.

The result is a simple local contract:

```text
solve exactly this sorry;
keep every admit unchanged.
```

The same contract is used for subgoal tactics and subgoal mini-skeletons.

The scaffold utilities also infer target labels from local declarations. If the
target `sorry` appears inside `have h_step : ... := ...`, the target label is
`h_step`. These labels are used in prompts, JSON logs, and the graph viewer.

## 4. Model Interface

The policy model is sampled in two modes.

In tactic mode, the model receives a proof state and returns a Lean proof for
the current target.

In skeleton mode, the model receives a proof state and returns a Lean proof
outline with named child obligations. The skeleton must close its final assembly
from those named obligations.

For subgoals, the model receives the full parent theorem scaffold rather than an
isolated theorem. The prompt explicitly names the target subgoal:

```text
[TARGET SUBGOAL]
name: h_name
child_index: i
goal: ...
```

The final output instructions are placed at the end of the user message, after
the problem statement and any previous Lean feedback. This makes the required
format the closest instruction to the model's first generated token.

The prompt builder also uses assistant prefill with `<think>\n`. Depending on
the sampler, the returned text may include only the continuation after that
prefix or may include a fresh `<think>` tag. The parser therefore treats the
final Lean code block as the source of truth.

The sampling backend is intentionally not part of the proof logic. Any sampler
can be used if it returns candidate text for tactic and skeleton requests. The
architecture is defined by what happens after sampling: parsing, policy checks,
Lean verification, repair, scoring, and graph search.

## 5. Output Parsing and Policy Checks

Model output is parsed before any Lean call. The parser extracts exactly one
final Lean code block. It does not recover code from malformed text by guessing.

For tactic actions, the extracted replacement must not contain `sorry` or
`admit` outside comments.

For skeleton actions, `admit` is forbidden inside the replacement. A `sorry` is
allowed only when it is a named leaf obligation. A naked final `sorry` fails the
policy check before Lean is called.

If no Lean code is extracted, the system records a failed action for logging and
graph analysis. It does not turn unclear extraction failures into retry feedback
for the model. Retry feedback is reserved for code-related failures where the
system has a checked Lean fragment or a clear policy violation.

This separation matters. It prevents a formatting failure or a truncated model
response from teaching the next sample the wrong proof behavior.

When sampling metadata reports a length or maximum-token finish reason, the
parser records a truncation explanation: the model should think shorter and
finish with one final Lean block. If a final Lean block exists but the target
replacement cannot be matched inside a subgoal scaffold, the failure is recorded
as a subgoal extraction failure.

For subgoal extraction, the parser compares the returned full scaffold with the
expected parent scaffold and extracts only the replacement for the target
`sorry`. Sibling `admit` placeholders are not part of the extracted action.

## 6. Lean Kernel Interface

Lean verification is the ground truth. GammaZero also uses Lean as a structured
analysis engine, not only as a pass/fail checker.

The codebase contains custom Lean-side server programs under `repl/`:

- `repl`, the interactive Lean REPL used for verification,
- `dump_ast_server`, which parses Lean files and returns syntax node spans,
- `dump_expr_server`, which elaborates Lean files and returns kernel expression
  trees for declarations.

Each server is driven as a persistent subprocess. The Python side sends file
paths or commands through standard input and reads JSON records from standard
output.

The verifier stores the Mathlib environment produced by an initial warmup
command. Later verification requests reuse that environment instead of importing
Mathlib from scratch. The AST and expression-tree daemons use the same idea:
they keep a live Lean process and reload imports only when the file header
changes. This makes repeated verification and analysis fast enough to sit inside
the search loop.

Each verification result contains:

- whether Lean accepted the candidate,
- whether the theorem is complete,
- remaining `sorry` placeholders,
- warnings,
- errors.

If the verifier process becomes stuck or times out, the system treats the event
as a system failure, records the failed action, and continues the search.

The process manager is defensive. Workers are killed and respawned after a
timeout or after a fixed number of requests, which avoids one stuck Lean command
or long-running process from blocking the whole rollout.

## 7. Repair Through Sorrification

Many generated Lean proofs are not correct but still contain useful structure.
GammaZero uses the `Sorrifier` to turn such code into a Lean-checkable partial
proof.

The repair process is conservative. It does not invent a new mathematical
proof. It removes or replaces invalid blocks so that Lean can expose the
remaining valid structure.

Typical repair operations are:

- replace a failing proof block with `sorry`,
- remove a malformed line,
- close an unfinished block with `sorry`,
- remove a larger block when local repair does not progress.

The important part is how the repair target is chosen. The Sorrifier repeatedly
verifies the candidate and reads the first Lean error or unsolved-goal location.
It then asks the Lean AST daemon for syntax spans and maps byte offsets back to
source lines. For fatal errors, it chooses the smallest enclosing tactic or
sequence node and either removes it, replaces it with `sorry`, or hollows out the
block header. For unsolved goals, it chooses the nearest enclosing declaration,
tactic `have`, `let`, `cases`, or similar scope and inserts a `sorry` at the
right indentation.

If the same broken state repeats, the Sorrifier escalates to a larger enclosing
block and deletes the child lines of that block. This prevents local repair from
cycling forever on the same malformed tactic. If no AST-guided repair is
possible, it falls back to replacing the proof body with one top-level `sorry`.

The repaired candidate is verified again. If it passes with remaining named
obligations, it can still create useful graph structure.

The failure handler separates system failures from checked Lean failures. A
system failure is logged and marked failed without repair. A checked Lean
failure can be repaired, verified again, scored, and inserted into the graph as
a failed but informative action.

## 8. Expression-Tree Dependency Analysis

Skeletons often contain extra local declarations. Some are useful for the final
assembly, and some are not. Lean still rejects a theorem if an unused local
declaration contains `sorry`, even when that declaration is not used by the
final proof term.

GammaZero analyzes dependencies in Lean's kernel expression tree. The
expression-tree daemon emits JSON for Lean `Expr` nodes such as `bvar`, `fvar`,
`app`, `lam`, `forallE`, `letE`, `mdata`, and constants. This is lower level
than source text: it is the elaborated proof object that Lean itself checks.

The dependency traversal is De Bruijn-aware. When it enters a binder such as
`lam`, `forallE`, or `letE`, the target bound-variable index is shifted before
the traversal continues into the body. This lets the analyzer distinguish a
declaration that is actually consumed by the final proof term from one that only
appears near the proof in source text.

The analyzer also detects `sorryAx` in the expression tree. Combining bound
variable use with `sorryAx` detection gives four classes:

- `core_solved`: solved and used,
- `core_failed`: unsolved and used,
- `benign`: solved and unused,
- `malignant`: unsolved and unused.

Unused declarations can be removed during final proof construction. This lets
the system keep useful proof structure while discarding decorative or harmful
lemmas.

Dependency analysis also produces `r_dep`, a reward that prefers skeletons whose
children are actually used.

The same mechanism is used for tactics that introduce local `have` or `let`
declarations. If a tactic creates local facts, GammaZero can score whether those
facts are consumed by the final proof term.

## 9. Search Loop

GammaZero performs best-first search over open proof states. The search uses a
priority queue. Each run has explicit limits, such as:

- maximum number of generated actions,
- maximum depth,
- maximum tactic attempts per state,
- maximum skeleton attempts per state,
- maximum number of open states kept globally,
- maximum number of open states kept per depth.

At each iteration, the search:

1. selects high-priority open states,
2. samples tactic actions for those states,
3. verifies tactic actions,
4. updates graph status and rewards,
5. decides whether a state should request skeletons,
6. samples skeleton actions when needed,
7. verifies or repairs skeleton actions,
8. selects skeletons worth activating,
9. inserts child states of selected skeletons,
10. propagates solved and failed statuses,
11. reinserts still-open states into the priority queue.

The search does not ask for skeletons immediately on every state. It first gives
direct tactics a chance. This matters because many Lean goals are small once the
right local facts are available.

Queue pruning is explicit. After each round, state scores are recomputed. The
queue keeps only the highest-scoring open states globally and only a fixed
number of open states at each depth. A state becomes exhausted when it reaches
the depth limit or consumes its tactic and skeleton limits. If all actions for
an exhausted state have failed, the state is marked failed.

## 10. Tactic-First Rule

For each new state, GammaZero first samples tactic attempts. A skeleton is
requested only after enough tactic attempts have been tried.

If a failed tactic receives a strong `r_env` score, the system may keep trying
tactics for longer. A high `r_env` means a large part of the generated proof
survived Lean repair, so the state may be close to a direct solution.

This rule prevents unnecessary decomposition. It also reduces the number of
child states created from goals that could have been solved directly.

Both tactic and skeleton sampling are limited by the same global action counter.
The system never treats a large model batch as free work.

## 11. Skeleton Commitment

Several skeletons can be generated for the same proof state. They often propose
incompatible decompositions. Solving children from many incompatible skeletons
at the same time spreads search effort too thin.

GammaZero therefore commits to one active skeleton for a parent state.

The committed skeleton receives focused search effort. Its children enter the
priority queue. While it remains active, the parent state does not keep asking
for new skeletons.

Other promising skeletons can be stored as reserved skeletons. If the committed
skeleton fails, or if it becomes stale after repeated rounds without progress,
a reserved skeleton can be activated.

This is a controlled fallback mechanism. It gives the search focus without
making the first skeleton choice irreversible.

Reserved skeletons are marked failed while they are inactive. When one is chosen
as the new commitment, it is reopened and its children are activated. This keeps
the graph focused on one active decomposition while preserving fallback
structure.

The search rejects duplicate skeletons. Two skeletons are duplicates when they
have the same parent state key and the same ordered child state keys. The later
duplicate is marked failed before it can consume search effort.

## 12. State Priority Score

The state priority score is implemented in
`gammazero/search/rollout/heuristic.py`.

The score has the following structure:

```text
score(state)
  = incoming_skeleton_weight * incoming_skeleton_score
  + best_tactic_weight * best_tactic_r_env
  + committed_skeleton_progress_bonus
  - depth_penalty * depth
  - tactic_retry_penalty * tactic_tries
  - skeleton_retry_penalty * skeleton_tries
  - bad_skeleton_round_penalty * bad_skeleton_rounds
```

The terms have direct meanings.

`incoming_skeleton_score` transfers some priority from a good skeleton to its
children.

`best_tactic_r_env` keeps a state interesting when a previous tactic almost
worked.

`committed_skeleton_progress_bonus` favors children of the currently committed
skeleton. The bonus is larger for the last open child of that skeleton. This
pushes the search to finish a proof decomposition instead of constantly opening
new branches.

The depth and retry penalties reduce priority for states that are deep or have
already consumed many attempts.

## 13. Skeleton Priority Score

Skeleton actions also receive a score before activation:

```text
score(skeleton)
  = skeleton_r_env_weight * r_env
  + skeleton_parent_score_weight * parent_last_score
  + child_count_score(number_of_children)
  - skeleton_depth_penalty * parent_depth
  - skeleton_sorrified_penalty, if repaired
```

`r_env` measures how much generated structure survived verification or repair.

`parent_last_score` lets a skeleton inherit some priority from the state that
requested it.

`child_count_score` prefers a small number of useful children. Zero children are
penalized. One or two children are often preferred. Large decompositions receive
a penalty because they increase the number of required subproofs.

The repair penalty is mild. A repaired skeleton can still be useful, but a
clean skeleton is preferred when other signals are similar.

Skeletons with no children are not useful decompositions and receive a negative
child-count score unless they are already solved by Lean.

## 14. Dense Rewards

GammaZero does not use only a binary solved/failed signal. It records dense
rewards for each generated action, including actions that do not close the
goal.

`r_env` measures how much of the generated code survived Lean checking and
repair. A candidate whose structure remains mostly intact receives a high
score. A candidate reduced mostly to placeholders receives a low score.

`r_dep` measures whether generated child obligations are used by the final
assembly. The reward is high when solved child lemmas are used. It is lower
when the skeleton creates unused work.

The dependency reward has the form:

```text
r_dep = n_core / (n_core + 0.5 * n_benign + 2.0 * n_unused_failed)
```

where:

- `n_core` is the number of solved child declarations used by the final proof,
- `n_benign` is the number of solved but unused declarations,
- `n_unused_failed` is the number of unsolved and unused declarations.

These rewards guide the current search and explain which failed actions still
contained useful proof structure.

The implementation computes `r_env` by comparing the original proof body with
the repaired proof body. It counts surviving non-comment proof lines and
penalizes Lean warnings that indicate unused or ineffective code.

The dense signal is important for proof search. A failed tactic that leaves a
valid chain of useful local facts is different from a failed tactic whose body
collapses into one placeholder. A skeleton whose children are actually used in
the final assembly is different from a skeleton that creates unused work. The
reward functions make these distinctions visible to the priority queue and the
AND/OR value backup.

## 15. Value Backup

After a rollout, GammaZero computes action values on the graph.

A tactic value comes from its direct rewards.

A skeleton value combines its own rewards with child values. Because a skeleton
is an AND node, its child contribution is limited by the weakest required child.
This reflects the proof condition: every required child must be solved.

Failed actions keep their recorded rewards for analysis, but they do not solve
their parent state.

## 16. Final Proof Construction

When children are solved, the proof stitcher inserts their proof bodies back
into the parent skeleton.

The final theorem is checked again in Lean. If dependency analysis shows that
some local declarations are unused, the proof text can be cleaned by removing
them. The final result is accepted only after Lean verifies the cleaned theorem
without unresolved placeholders.

This final verification step is essential. The graph may contain many useful
partial fragments, but only a complete Lean theorem is a proof.

When extracting proof text from the graph, GammaZero tries all solved actions for
a state and prefers the first proof that contains no real `sorry` outside
comments. If no clean proof is available, it can still return the first
stitchable proof as a fallback for inspection. The final Lean verification step
decides whether the extracted text is a complete proof.

The graph logger exports the final graph to JSON. Each action node records the
raw model content, prompt, extracted Lean code, verified code, patched code,
Lean feedback, target label, `r_env`, `r_dep`, and `Q_value`. This is the data
used by the HTML graph viewer.

The JSON also includes search metadata: action budget usage, Lean verification
counts, skeleton repair counts, final state and action statuses, depth
distribution, queue pruning counts, and skeleton commitment statistics.

## 17. Configuration

The main runtime configuration is `configs/api.yaml`.

The configuration sets limits and weights. It does not change the logical
contract of the system. Important groups include:

- action and depth limits,
- tactic sampling counts,
- skeleton sampling counts,
- state queue limits,
- skeleton commitment parameters,
- heuristic weights,
- verifier timeout settings.

The configuration loader validates heuristic keys against the current
`SimpleHeuristicScorer` constructor. This catches stale configuration fields
early.

The rollout entry point accepts either one Lean file or a directory of Lean
files. It skips JSON outputs that already exist, constructs the root
`ProofState` from the original theorem scaffold, warns when the root file does
not contain exactly one `sorry`, and exports one graph JSON file per theorem.

## 18. Design Rationale

GammaZero works because it turns language model samples into checked graph
structure instead of treating samples as final answers.

The model is useful for proposing tactics and decompositions. Lean is used to
accept, reject, or expose partial structure. The graph records dependencies
between the resulting fragments. The search policy then spends effort on states
that are close to closing an active proof path.

The central design choices are:

- use direct tactics before decomposition,
- decompose only into named obligations,
- verify subgoals in their parent scaffold,
- admit sibling obligations when focusing on one child,
- reject invalid placeholder usage before Lean,
- repair failed code only to preserve useful structure,
- remove unused declarations through dependency analysis,
- commit to one skeleton while keeping fallback skeletons,
- prioritize the last open child of a committed skeleton,
- compute action values from the AND/OR proof graph.

Together these choices make the search tree smaller, the model prompt more
local, and the final proof construction more reliable.
