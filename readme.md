# JavaScript Compiler (C Implementation)

如果您想自己手动构建项目     解压bin.rar   后放入项目根目录下   然后按照教程操作即可

项目结构如下示例

```
js_compiler_by_c
	\bin
	\其他
```

Use the expanders below to view the README in your preferred language.

<details open>
<summary>English Version</summary>

## Overview

C-based JavaScript front-end that ingests ES5.1 plus most ES2015/ES2017 syntax, performs lexical and syntactic analysis, applies ECMAScript-compliant ASI, and emits a fully walkable AST for bulk dataset validation.

## Build and Test Quickstart

### Windows (PowerShell via `make.cmd`)

```powershell
# Build (re2c + Bison + GCC run automatically)
.\make

# Regenerate parser + AST entry points explicitly
.\make parser

# Run tests on any folder or file
.\make test                     # entire test/ tree
.\make test test\es6_stage4     # relative path
.\make test D:\path\to\files  # absolute path

# Remove generated artifacts
.\make clean
```

- `make.cmd` ships a portable `bin/` toolchain (gcc, re2c, bison, m4). It injects that directory into `PATH`, sets `BISON_PKGDATADIR`, and runs inside stock PowerShell/CMD.
- After editing `src/lexer.re` or `src/parser.y`, rerun `.\make parser` (add `-B` if you need a forced rebuild) so `build/generated/` and the root mirrors stay aligned.

### MSYS2 / Linux / macOS

```bash
make           # js_lexer.exe
make parser    # js_parser.exe + AST support
make test      # identical to Windows target
make clean
```

### Common Targets

| Target            | Description                                               |
| ----------------- | --------------------------------------------------------- |
| `make`            | Build lexer (`js_lexer.exe`)                              |
| `make parser`     | Re-run re2c/Bison, emit parser + AST binary               |
| `make test`       | Parse every file under the supplied path(s)               |
| `make test-parse` | Syntax-only regression shortcut                          |
| `make regen`      | Force-regenerate lexer/parser sources                     |
| `make clean`      | Remove `build/` artifacts                                 |

- `build/parser_error_locations.log` resets before each `make test` and lists failures as `path:line:column:message` so you can jump directly from VS Code (`Ctrl+G`).
- `build/test_failures.log` stores the full stdout/stderr transcript; add `JS_PARSER_TRACE=1` when you need detailed GLR traces.

## Project Overview

`js_compiler_by_c` combines a `re2c` lexer, a GLR-capable GNU Bison grammar, an ASI-aware adapter, and a rich AST layer to:

1. Validate compressed JavaScript corpora such as `test/JavaScript_Datasets/goodjs`.
2. Diagnose syntax/ASI failures with deterministic logs.
3. Provide a structured AST for downstream tooling or analysis.

Executables produced in `build/`:

- `js_lexer.exe` prints tokens with line/column, newline state, and previous-token context (useful for regex vs division decisions).
- `js_parser.exe` performs parsing + ASI + AST generation, exits `0` on success and `2` on syntax error, and supports `--dump-ast` for human-readable trees.

### Architecture

```text
┌───────────────┐        ┌──────────────────┐        ┌────────────────────┐
│  JS Source    │  ──▶  │  Lexer (re2c)    │  ──▶  │  token.h stream     │
└───────────────┘        └──────────────────┘        └────────────────────┘
                                                                        │
                                                                        ▼
                                                ┌──────────────────────────────────┐
                                                │ parser_lex_adapter.c             │
                                                │  • ASI + newline suppression     │
                                                │  • Control/brace/ternary stacks  │
                                                │  • Token queue + virtual ';'     │
                                                └──────────────────────────────────┘
                                                                        │
                                                                        ▼
┌───────────────┐        ┌──────────────────┐        ┌────────────────────┐
│  AST builder  │  ◀──  │  Parser (Bison)  │  ◀──  │  parser.y grammar   │
│  ast.c / .h   │        └──────────────────┘        └────────────────────┘
```

### Directory Map

- `src/` – Authoritative sources (`lexer.re`, `parser.y`, AST, adapters). Always regenerate via `make parser` after edits.
- `build/` – Generated sources, objects, binaries, plus `parser_error_locations.log`, `test_failures.log`, trace dumps.
- `bin/` – Portable mingw64 toolchain consumed by `make.cmd`.
- `test/` – Hand-written suites (`test_*.js`), ES6 staged suites, dataset harness glue.
- `tmp/` – Minimal repro scripts and trace utilities (for example `trace_compare.py`).

## Core Systems

### Lexical Analysis (`src/lexer.re`)

- Accepts UTF-8 (Unicode identifiers, whitespace, line terminators) and tracks `has_newline`, brace depth, template states, previous token class.
- Tokenizes ES5 + ES2015 keywords (`class`, `extends`, `import`, `export`, `async`, `await`, `yield`, etc.), private identifiers (`#field`), `...`, `=>`, template fragments, BigInt, binary/octal/hex literals, regex literals, and contextual sentinel tokens (`FUNCTION_DECL`, `ARROW_HEAD`).
- Skips whitespace/comments while preserving exact `(line, column)` info for diagnostics and ASI decisions.

### Parser (`src/parser.y`)

- GLR grammar with `%define parse.error verbose` and `%expect` guards. Covers Script + Module constructs (imports/exports, classes, async/generator functions, `for-of`, destructuring, templates, spread/rest, labelled statements, try/catch/finally with destructured bindings, `with`).
- `_no_obj`, `_no_in`, `_no_arr` families avoid block/object ambiguity and control `for-in` lookahead. ECMAScript-style `member_expr`/`call_expr`/`left_hand_side_expr` layering removes `new Foo()` call-chain ambiguity.
- Binding patterns are shared across var declarations, function params (default/rest), `catch` clauses, and `for-in/of` headers.

### Automatic Semicolon Insertion (ASI)

- Implements ECMA-262 §11.9 (newline triggers, EOF, restricted productions like `return`, `break`, `continue`, `throw`, `yield`).
- Adds safety rails for `catch` heads, `new` + IIFE, multi-line conditionals returning object literals, chained `new` calls, template literals, `=>`, control headers ending with `)`, `await`/`yield`, `? :` blocks, and `)` inside multi-line calls.
- `g_conditional_depth` marks `{` after `:` in ternaries as object literals; `g_pending` replays real tokens after injecting `';'`.

### AST (`ast.c/.h`)

- 90+ node kinds (programs, modules, import/export forms, class declarations/expressions with static/get/set/computed/async/generator methods, binding patterns, spread/rest, `AST_FOR_OF_STMT`, `AST_YIELD_EXPR`, `AST_TEMPLATE_LITERAL`, `AST_ARROW_FUNCTION`, `AST_METHOD_DEF`, `AST_BINDING_PROPERTY`, and more).
- `js_parser.exe --dump-ast file.js` prints readable trees; `ast_traverse` drives custom visitors; `ast_free` prevents leaks when parsing large corpora.

### Diagnostics and Tooling

- `build/parser_error_locations.log` – Canonical failure list (`path:line:column:message`).
- `build/test_failures.log` – Full stdout/stderr per `make test`; useful against Node/V8 baselines.
- `tmp/trace_compare.py` – Compares GLR traces (peak stack counts, split histograms) for repro files.
- `JS_PARSER_TRACE=1 js_parser.exe file.js` – Enables Bison `%debug`; pair with the trace compare script to quantify grammar tweaks.

## Testing and Coverage

| Suite                        | Purpose                                                                 |
| ---------------------------- | ----------------------------------------------------------------------- |
| `test/test_basic.js`        | General syntax sanity                                                   |
| `test/test_simple.js`       | Lightweight smoke tests                                                 |
| `test/test_functions.js`    | Function declarations/expressions                                      |
| `test/test_for_*`           | Traditional `for`, `for-in`, control flow + labels                      |
| `test/test_literals.js`     | Array/object/number/string literal coverage                             |
| `test/test_asi_*`           | ASI baseline / return / control-flow edge cases                         |
| `test/test_try.js`          | Exception handling, `with`, nested blocks                               |
| `test/test_switch.js`       | Switch/case/default/fallthrough                                         |
| `test/test_error_*.js`      | Curated negative cases (missing `:`, `)`, `}`, `;`, etc.)               |
| `test/es6_stage1`           | Destructuring + default/rest bindings                                   |
| `test/es6_stage2`           | Arrow functions + parameter system                                     |
| `test/es6_stage3`           | Template literals + tagged templates                                    |
| `test/es6_stage4`           | Classes + enhanced object literals                                      |
| `test/es6_stage5`           | `for-of`, generators, spread/rest, `yield`                              |
| `test/JavaScript_Datasets`  | Real-world corpora (`goodjs` expected pass, `badjs` expected fail log)   |

Tips:

- After grammar/ASI edits, run `make clean && make parser && make test test/JavaScript_Datasets/goodjs`.
- Use `make test tmp/repro_xyz.js` for single repros; logs still land in `build/parser_error_locations.log`.

## Memory Exhaustion Tracking

Large compressed files previously hit GLR "memory exhausted" even with modest concurrent stack counts. Mitigations:

1. **Instrumentation** – `%debug` + `JS_PARSER_TRACE=1` + `tmp/trace_compare.py` report split counts (rule attribution, token positions) for failing vs passing repros.
2. **Stack Budget** – Raised `YYMAXDEPTH` to 1,000,000 in `parser.y`, preventing crashes (still ~15 concurrent stacks but many more GLR items now allowed).
3. **Planned Grammar Refactors** – Introduce shared postfix chains or explicit assignment-target nonterminals to reduce `_no_obj/_no_arr/_no_in` duplication; success metric is a 30%+ drop in `.`-triggered splits.
4. **Regression Discipline** – Any grammar change reruns repro scripts, staged ES6 suites, and `goodjs`, with updated trace deltas attached.

## ES2015+ Coverage and Gaps

| Status  | Highlights                                                                                                                       |
| ------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Done    | Binding patterns (decl/params/catch/for-in-of), default/rest params, arrow functions (LineTerminator checks), template literals & tagged templates, classes (extends, static/get/set, computed props), enhanced object literals, `function*`/`yield*`, `for-of`, spread/rest in arrays/calls, `yield` ASI rules, destructuring assignments, `new` call-chain fixes, ternary + object literal protection, `in` operator in expression statements. |
| Planned | Object literal spread (`{ ...obj }`), module syntax (`import`/`export` variants), async/await + async generators + `for-await-of`, `new.target`, `super.prop = expr` semantics, optional chaining / nullish coalescing / other ES2020+ constructs, richer diagnostics (multi-error recovery). |

Re-run `make test test/es6_stageX` (X = 1…5) after every relevant change and log unimplemented syntax with file paths to keep the roadmap accurate.

## Roadmap and Next Steps

1. **M0 – Foundation Hardening**: Keep `lexer.re`/`parser.y` warnings clean, add diagnostics, stabilize staged test entry points.
2. **M1 – Binding Patterns** *(shipped)*: AST + parser support for destructuring/default/rest across all contexts.
3. **M2 – Parameters and Arrows** *(shipped)*: Unified parameter parsing, `ARROW_HEAD`, newline restrictions.
4. **M3 – Template Literals** *(shipped)*: Template state machine, tagged invocation support.
5. **M4 – Classes and Enhanced Objects** *(shipped)*: Class declarations/expressions, method forms, `super`, computed props.
6. **M5 – Iteration Protocol** *(shipped)*: `for-of`, generators, spread/rest, `yield` restrictions.
7. **M6 – Modules and Async** *(planned)*: `import`/`export` graph, async/await, module-mode CLI switches.

Supporting work: integrate gcov coverage, run cppcheck/clang static analysis, create performance and memory baselines.

## Debugging Tips

- `js_lexer.exe path\file.js` prints token streams with coordinates.
- `js_parser.exe --dump-ast file.js` inspects AST output.
- Enable adapter logging in `parser_lex_adapter.c` when analyzing ASI decisions.
- `JS_PARSER_TRACE=1 js_parser.exe tmp/repro_mem10.js > tmp/trace_mem10.log` followed by `python tmp/trace_compare.py ...` compares GLR traces.
- `node --check file.js` confirms whether a source file is valid before blaming the parser.

## References

- [ECMAScript 5.1 Language Specification](https://262.ecma-international.org/5.1/)
- [re2c Manual](https://re2c.org/manual/manual_c.html)
- [GNU Bison Manual](https://www.gnu.org/software/bison/manual/)
- [Esprima](https://esprima.org/) and [Acorn](https://github.com/acornjs/acorn)

---

MIT Licensed - Maintained by Stardreama and contributors - Last consolidated: 2025-12-05

</details>

<details>
<summary>中文版本</summary>

## 概述

`js_compiler_by_c` 是一个用 C 语言实现的 JavaScript 前端，覆盖 ES5.1 以及多数 ES2015/ES2017 语法。它包含 re2c 词法分析器、支持 GLR 的 GNU Bison 语法分析器、符合 ECMAScript 规范的自动分号插入 (ASI) 适配层，以及可遍历的 AST，用于批量校验数据集脚本。

## 构建与测试速览

### Windows（PowerShell，使用 `make.cmd`）

```powershell
# 构建（自动运行 re2c、Bison、GCC）
.\make

# 显式重新生成语法分析器与 AST 入口
.\make parser

# 运行测试（可传文件或目录）
.\make test                     # 整个 test/ 目录
.\make test test\es6_stage4     # 相对路径
.\make test D:\path\to\files  # 绝对路径

# 清理由构建产生的文件
.\make clean
```

- 仓库自带的 `make.cmd` 会把 `bin/` 内的 gcc、re2c、bison、m4 加入 `PATH`，并设置 `BISON_PKGDATADIR`，无需另装 MSYS2 即可在 PowerShell/CMD 下构建。
- 修改 `src/lexer.re` 或 `src/parser.y` 后请执行 `.\make parser`（必要时加 `-B`），以保持根目录镜像文件与 `build/generated/` 一致。

### MSYS2 / Linux / macOS

```bash
make           # 生成 js_lexer.exe
make parser    # 生成 js_parser.exe（含 AST）
make test      # 与 Windows 目标一致
make clean
```

### 常用目标

| 目标              | 说明                                   |
| ----------------- | -------------------------------------- |
| `make`            | 构建词法分析器 `js_lexer.exe`          |
| `make parser`     | 重新运行 re2c/Bison 并生成解析器产物   |
| `make test`       | 解析指定路径下的全部文件               |
| `make test-parse` | 仅运行语法回归                         |
| `make regen`      | 强制重新生成 lexer/parser 源文件       |
| `make clean`      | 清理 `build/` 目录                     |

- `build/parser_error_locations.log` 会在 `make test` 前清空，失败项以 `路径:行:列:错误` 形式记录，VS Code 中可直接跳转。
- `build/test_failures.log` 保存完整输出；设置 `JS_PARSER_TRACE=1` 可附带 GLR 轨迹。

## 项目组成

1. **词法层**：`re2c` 负责切分 Token，支持 Unicode 标识符、模板片段、BigInt、正则字面量与上下文 Token（如 `FUNCTION_DECL`、`ARROW_HEAD`）。
2. **语法层**：GNU Bison 的 GLR 模式覆盖 Script/Module 语法，含 `import/export`、类、生成器、解构、模板、`for-of`、标签语句、`try/catch/finally` 等。
3. **ASI 适配层**：`parser_lex_adapter.c` 把 lexer Token 投递给 Bison，并在行终止、EOF 或受限产生式处插入虚拟分号，额外处理 `catch`、IIFE、三元表达式对象字面量等场景。
4. **AST 框架**：`ast.c/.h` 定义 90+ 种节点，`--dump-ast` 可输出可读结构，`ast_traverse` 与 `ast_free` 便于遍历与释放。

### 目录速查

- `src/`：权威源文件（lexer/parser/AST/适配层）。
- `build/`：生成的源码、二进制、`parser_error_locations.log`、`test_failures.log`、调试轨迹。
- `bin/`：随仓库提供的便携式 mingw64 工具链。
- `test/`：基础用例、ES6 分阶段用例、数据集脚本。
- `tmp/`：最小复现脚本与 `trace_compare.py` 等工具。

## 核心子系统

### 词法分析

- 输入 UTF-8，记录 `has_newline`、花括号深度、模板状态与上一个 Token，便于 ASI 与正则判定。
- 识别 ES5/ES6 关键字、私有标识符、`...`、`=>`、模板片段、BigInt、二/八/十六进制数字、正则字面量等。

### 语法分析

- 使用 GLR 与 `%expect` 控制冲突，涵盖 `import/export`、class、async/generator、`for-of`、解构、模板、spread/rest、标签、`try/catch/finally`、`with` 等语法。
- `_no_obj`、`_no_in`、`_no_arr` 变体避免语句块与对象字面量冲突，同时控制 `for-in`/`for-of` 的 lookahead。

### 自动分号插入（ASI）

- 严格遵循 ECMA-262 §11.9（换行、EOF、受限产生式），并针对 `catch`、`new`+IIFE、多行三元表达式、模板、`=>`、`await/yield`、`? :` 等场景增加保护。
- 使用 `g_pending` 缓存真实 Token，`g_conditional_depth` 标记三元表达式中的对象字面量。

### AST

- 覆盖 Program/Module、Import/Export、Class/Method、Binding Pattern、Spread/Rest、`for-of`、`yield`、模板、箭头函数等节点。
- `js_parser.exe --dump-ast file.js` 可直接打印 AST；`ast_traverse` 支持自定义遍历；`ast_free` 确保大规模解析无内存泄漏。

### 调试与日志

- `build/parser_error_locations.log`：失败列表。
- `build/test_failures.log`：完整日志，可与 Node/V8 对比。
- `tmp/trace_compare.py`：比较 GLR 轨迹峰值与分裂情况。
- `JS_PARSER_TRACE=1 js_parser.exe file.js`：启用 Bison `%debug`，便于定位语法问题。

## 测试覆盖

| 测试目录/文件             | 覆盖内容                               |
| ------------------------- | -------------------------------------- |
| `test/test_basic.js`      | 综合语法                               |
| `test/test_simple.js`     | 轻量级冒烟测试                         |
| `test/test_functions.js`  | 函数声明/表达式                        |
| `test/test_for_*`         | 传统 for、for-in、标签控制             |
| `test/test_literals.js`   | 各类字面量                             |
| `test/test_asi_*`         | ASI 基础、return、控制流               |
| `test/test_try.js`        | try/catch/finally、with                |
| `test/test_switch.js`     | switch/case/default                    |
| `test/test_error_*.js`    | 常见语法错误（缺冒号/括号/分号等）     |
| `test/es6_stage1`         | 解构与默认/rest 参数                   |
| `test/es6_stage2`         | 箭头函数与参数系统                     |
| `test/es6_stage3`         | 模板字符串与 tagged template           |
| `test/es6_stage4`         | 类与增强对象字面量                     |
| `test/es6_stage5`         | `for-of`、生成器、spread/rest、`yield`  |
| `test/JavaScript_Datasets`| 真实数据集（`goodjs` 预期通过，`badjs` 记录错误） |

建议在语法或 ASI 变更后执行 `make clean && make parser && make test test/JavaScript_Datasets/goodjs`，并针对单个复现脚本运行 `make test tmp/repro_xxx.js`。

## 内存耗尽问题

- 通过 `%debug` + `JS_PARSER_TRACE=1` + `tmp/trace_compare.py` 观察 GLR 分裂热点（如 `tmp/repro_mem10.js` 与 `tmp/repro_mem16.js`）。
- 在 `parser.y` 中将 `YYMAXDEPTH` 提升到 1,000,000，避免在 GLR 项数较大时提前崩溃。
- 规划通过共享前缀/后缀或拆分赋值左值非终结符来降低 `_no_obj/_no_arr/_no_in` 的组合爆炸，目标是将 `.` 引发的分裂降低 30%以上。
- 每次语法调整都需要重新跑复现脚本、ES6 分阶段用例与 `goodjs`，并记录新的轨迹统计。

## ES2015+ 支持现状

| 状态 | 说明 |
| ---- | ---- |
| 已完成 | 解构绑定（声明/参数/catch/for-in-of）、默认/rest 参数、箭头函数（LineTerminator 校验）、模板字符串与 tagged template、类（继承、静态/访问器/计算属性）、增强对象字面量、生成器 (`function*`/`yield*`)、`for-of`、数组/调用中的 spread/rest、`yield` ASI 规则、解构赋值、`new` 调用链修复、三元表达式对象字面量护栏、表达式语句中的 `in`。 |
| 计划中 | 对象字面量 spread (`{ ...obj }`)、模块语法与模式切换（`import`/`export` 系列）、`async/await` 与 async generator／`for-await-of`、`new.target`、`super.prop = expr` 等语义限制、可选链/空值合并/ES2020+ 语法、更丰富的多错误诊断。 |

每次更新相关语法后，请运行 `make test test/es6_stageX`（X = 1~5），并把未支持语法及其文件路径记录到路线图中。

## 路线图

1. **M0 基础加固**：清理 re2c/Bison 警告，完善诊断与测试切分。
2. **M1 Binding Pattern**（已完成）：解构/默认/rest 的 AST 与语法支持。
3. **M2 参数与箭头函数**（已完成）：统一参数解析、`ARROW_HEAD` 预读、换行限制。
4. **M3 模板字符串**（已完成）：模板状态机与 tagged template。
5. **M4 类与增强对象**（已完成）：类声明/表达式、`super`、计算属性。
6. **M5 迭代协议**（已完成）：`for-of`、生成器、spread/rest、`yield` 受限。
7. **M6 模块与 Async**（规划中）：`import/export`、async/await、模块模式入口。

配套任务：接入 gcov 覆盖率、运行 cppcheck/clang 静态分析、建立性能与内存基线。

## 调试提示

- `js_lexer.exe path\file.js` 查看 Token 流。
- `js_parser.exe --dump-ast file.js` 输出 AST。
- 在 `parser_lex_adapter.c` 中加入日志方便分析 ASI 结果。
- `JS_PARSER_TRACE=1 js_parser.exe tmp/repro_mem10.js > tmp/trace_mem10.log` 后结合 `python tmp/trace_compare.py ...` 比较 GLR 轨迹。
- `node --check file.js` 可先确认源码自身是否合法。

## 参考资料

- [ECMAScript 5.1 规范](https://262.ecma-international.org/5.1/)
- [re2c 手册](https://re2c.org/manual/manual_c.html)
- [GNU Bison 手册](https://www.gnu.org/software/bison/manual/)
- [Esprima](https://esprima.org/) / [Acorn](https://github.com/acornjs/acorn)

---

许可证：MIT License；维护者：Stardreama 及社区贡献者；最后更新时间：2025-12-05

</details>

