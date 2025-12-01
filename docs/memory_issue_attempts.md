# JS Parser Memory Exhaustion Attempts

This document summarizes all work done so far to diagnose and fix the GLR "memory exhausted" failure (reproduced with `tmp/repro_mem10.js`). It captures what was tried, the observed side effects, and the current status, so we do not repeat past experiments.

## 1. Instrumentation & Repro Setup

- Enabled `%debug` in `src/parser.y` and used the `JS_PARSER_TRACE=1` environment flag to dump GLR traces for failing and passing samples (`tmp/trace_mem10.log`, `tmp/trace_mem16.log`).
- Added the helper script `tmp/trace_compare.py` to compute peak stack counts and token split frequencies. Key observation: failing traces split primarily on `.` (member access) and peak at ~16 concurrent stacks, while passing traces stay below 8.
- Collected a suite of minimal repro files (`tmp/repro_mem10.js`, `tmp/repro_mem16.js`, `tmp/repro_mem18.js`, etc.) to compare behavior after each grammar tweak.

## 2. Grammar Tweaks Attempted

### 2.1 `primary_no_obj` refactor (no behavior change)

- Collapsed `primary_no_obj` to reuse `primary_no_obj_no_arr` and re-add `array_literal` explicitly. Parser rebuilt cleanly, but `tmp/repro_mem10.js` still exhausted memory; trace metrics were identical, so the ambiguity source lies deeper in the expression layers.

### 2.2 Merge `member_expr*` and `call_expr*` suffix handling (REGRESSION)

- Goal: eliminate duplicate dotted/`[]`/template suffix rules by letting `member_expr` directly consume `call_expr` results and removing suffix actions from `call_expr`. Applied across `_no_arr` and `_no_obj` variants.
- Result: `test/es6_stage1/destructuring_params_defaults.js` and several other stage1 tests began failing with "syntax is ambiguous" because GLR now had two equivalent derivations (`member_expr` → `call_expr` vs. `call_expr` → suffix). Reverted change entirely to restore test suite stability.

### 2.3 Optional trailing commas in `import/export` clauses (FIXED regression only)

- While not targeting memory, removing the `import_specifier_list_opt` productions and explicitly supporting `{ … , }` prevented the later ES6 module tests from failing when commas trailed before `}`. This is orthogonal to the memory issue but documented for completeness.

## 3. Current Understanding

- The GLR explosion still originates from the `_no_obj` / `_no_obj_no_arr` expression families: in traces, repeated `this.` chains cause new stacks to split at rules 414/420/434 even before member suffixes are considered.
- Simple refactors (like removing duplicate suffix rules) either do not lower branching or reintroduce ambiguity elsewhere.
- Any future attempt should focus on restructuring those `_no_obj` hierarchies (e.g., introducing a dedicated "assignment LHS" nonterminal or sharing a common postfix-suffix list) while guarding contexts that must forbid object literals.

## 4. Lessons Learned

1. **Trace tooling is essential**: keep `tmp/trace_compare.py` updated; it immediately shows whether a grammar tweak affects stack depth or split distribution.
2. **Avoid mutually recursive equivalence**: letting `member_expr` accept `call_expr` (while `call_expr` still recurses into itself) creates true ambiguities that GLR cannot prune. Any deduplication must factor suffix parsing into a separate helper nonterminal instead.
3. **Test early**: every parser change was validated with `tmp/repro_mem10.js` plus targeted suites (`test/es6_stage1`, `test/es6_stage6`). Keeping this habit prevented ambiguous grammar from shipping.

## 5. Next Steps (not yet attempted)

- Prototype a shared suffix helper, e.g. `postfix_suffix -> ('.' IDENT | '[' expr ']' | template_literal)*`, used by both member/call chains, so we can drop duplicated `_no_arr` variants without creating new GLR derivations.
- Alternatively, separate assignment targets from expression contexts to avoid `_no_obj` duplications entirely, potentially reducing the stack fan-out observed around `this.` chains.
- Once a promising refactor is in place, rerun the `trace_compare` tool to see if `'.'` splits drop below current counts (≈72) before re-running the full ES6 suite.

## 6. Latest Diagnostics (May 2025)

- Regenerated traces for `tmp/repro_mem10.js` (fail) and `tmp/repro_mem16.js` (pass) with the current grammar; peak stack counts were 15 vs. 7 respectively, confirming the explosion remains localized to the failing file.
- Upgraded `tmp/trace_compare.py` to attribute stack splits to grammar rules/line numbers. Failing logs show 76 splits on `.` with rule 443 (`primary_no_obj_no_arr` at line 1743) responsible for 52 of them; passing logs split only 12 times with the same rule contributing 5.
- Rule-level deltas implicate the `_no_obj_no_arr` base case rather than the suffix productions. Branching occurs before the parser decides whether `this`/identifier tokens should become `member_expr` or `call_expr`, so any fix must start there.
- Immediate plan: investigate whether `_no_obj_no_arr` can reuse a single "base expression" nonterminal with context flags (or precedence tweaks) to avoid duplicating `primary` forms across `member_expr`/`call_expr`. This should reduce the number of viable stacks before suffix parsing even begins.

## 7. Stack Capacity Fix (Dec 2025)

- Bison's GLR backend defaults `YYMAXDEPTH` to 10,000 stack items, which proved insufficient even though the failing trace never exceeded 16 concurrent stacks; the repeated member-access reductions simply churned through far more than 10k GLR items before commitments occurred.
- Added an override in `src/parser.y` (inside the `%{ … %}` prologue) to `#define YYMAXDEPTH 200000` before Bison's headers are emitted, then rebuilt via `make parser` so `build/generated/parser.c` picks up the new value.
- Reran `js_parser.exe tmp\repro_mem10.js` and `tmp\repro_mem16.js` (both with and without `JS_PARSER_TRACE=1`). The former now reports `[PASS]` and the trace log no longer contains "memory exhausted"—peak stack id remains 15, but the run finishes cleanly because the GLR stack can continue expanding.
- Validated via `python tmp/trace_compare.py tmp/trace_mem10.log tmp/trace_mem16.log` that split statistics are unchanged (still ~76 `.` splits on the repro), confirming we mitigated the failure by enlarging the stack budget rather than altering the grammar's behavior.
- Locked the change in with `make test tmp\repro_mem10.js` to ensure the harness also records the repro as passing. Longer term we still plan to shrink the `_no_obj` branching factor, but the parser is unblocked for dataset sweeps now that GLR no longer aborts early.
