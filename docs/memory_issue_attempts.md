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
