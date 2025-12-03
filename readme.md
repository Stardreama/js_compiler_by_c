# JavaScript Compiler (C Implementation)

## 快速开始 (Build & Run)

本项目提供统一的构建脚本，支持 Windows (PowerShell) 和 Linux/macOS。

### 1. 构建项目

在项目根目录下运行：

```powershell
# Windows (PowerShell)
.\make           # 构建项目
```

### 2. 运行测试

运行所有回归测试用例：

```powershell
# Windows (PowerShell)
.\make test                                                  # 测试本项目 test/ 目录下的所有文件,也可以是相对路径
.\make test D:\EduLibrary\OurEDA\JavaScript_Datasets\badjs   # 测试指定绝对路径下的文件或文件夹
```

```bash
# Linux / macOS / MSYS2
make test
```

### 3. 清理构建

清理所有生成的文件：

```powershell
# Windows (PowerShell)
.\make clean
```

---

## 项目介绍

`js_compiler_by_c` 是一个覆盖 ECMAScript 5.1 与大部分 ES2015/ES2017 语法的解析前端，使用 C 语言实现。核心组件基于 `re2c`（词法）与 `GNU Bison`（语法），配套自动分号插入 (ASI) 与抽象语法树 (AST) 产物，可直接在命令行完成 Token Dump、语法校验与 AST 打印。工程内置便携式工具链，无需额外安装 MSYS2 即可在 Windows PowerShell 中构建。

> ⚠️ **高级特性仍有限制**：ES2020+（可选链、空值合并、模块顶层 await 等）尚未实现，部分压缩数据集中仍会报语法错。具体缺口与已实现的 ES6 阶段能力可在 `docs/es6_limitations.md` 中查阅。

### 核心特性

- **词法分析**：`lexer.re` 能识别 `let/const`, `class`, `async/await`, 模板字符串、BigInt/二进制数字、正则字面量与私有标识符；精确维护 `has_newline`、行列号和前一 Token，供 ASI 与正则/除法判定使用。
- **语法分析**：`parser.y` 覆盖 Script/Module 双模式、`import`/`export`、类与增强对象字面量、解构绑定、默认参数+`...rest`、生成器 (`function*`/`yield*`)、`for-of`、箭头函数、模板字符串、`async function` 与 `await`、标签与异常体系等，配合 `_no_obj`/`_no_in` 变体解决块/对象与 `for-in` 歧义。
- **自动分号插入 (ASI)**：`parser_lex_adapter.c` 复刻 ECMA-262 §11.9 规则，额外处理 IIFE、`catch` 头、`new` 调用链、`?:` 接对象字面量等真实案例，避免在多行箭头函数/三元表达式中误插分号。
- **AST 生成**：`ast.c/ast.h` 为所有语法节点（含箭头、类、模块、解构、模板、spread/rest、for-of、yield、tagged template 等）提供构造/打印/释放，`js_parser.exe --dump-ast` 可输出调试结构。
- **双模式运行**：
  - `js_lexer.exe`：输出 Token 流（含 `PrevTokenState`），便于定位正则与 ASI 根因。
  - `js_parser.exe`：执行解析/ASI/AST，一致返回 `0/2` 退出码用于批量测试。

---

## 系统架构

```text
┌───────────────┐        ┌──────────────────┐        ┌────────────────────┐
│  JS 源代码    │  ──▶  │  词法分析 (re2c) │  ──▶  │  Token 流 (token.h) │
└───────────────┘        └──────────────────┘        └────────────────────┘
                                                        │
                                                        ▼
                                    ┌──────────────────────────────────┐
                                    │  适配层 parser_lex_adapter.c     │
                                    │  • ASI 决策                     │
                                    │  • 控制栈与括号深度             │
                                    │  • re2c 与 bison 接口            │
                                    └──────────────────────────────────┘
                                                        │
                                                        ▼
┌───────────────┐        ┌──────────────────┐        ┌────────────────────┐
│  AST 构造器   │  ◀──  │  语法分析 (bison) │  ◀──  │  语法规则 parser.y  │
│  ast.c / ast.h│        └──────────────────┘        └────────────────────┘
```

### 目录结构

- `src/`: 规范源（lexer/parser/AST/适配层）；根目录的 `lexer.re` / `parser.y` 仅作编辑镜像，修改后需运行 `.uild.bat parser` 或 `.uild.bat regen` 以同步到 `build/generated/`。
- `test/`: 测试用例集（基础用例 + `es6_stage{1..5}` + `JavaScript_Datasets` 子集）。
- `bin/`: 便携式 `gcc/re2c/bison/m4`，`make.cmd` 会自动将其加入 `PATH`。
- `build/`: 生成的 `generated/`、`obj/`、`parser_error_locations.log` 等产物。
- `docs/`: 详细技术文档与变更记录。

---

## 技术文档

### 1. 词法分析 (Lexer)

基于 `re2c` + 自定义 helper 实现。

- **关键字**：除 ES5 关键字外，支持 `class/extends/super`、`import/export`、`async/await`、`yield` 等 ES2015+ 词汇；`FUNCTION_DECL`/`ARROW_HEAD` 等虚拟 Token 在适配层生成。
- **字面量**：十进制/二进制/八进制/十六进制/科学计数法数字、BigInt、字符串（含 Unicode 转义）、模板字符串片段（`TEMPLATE_HEAD/MIDDLE/TAIL`）、正则字面量、布尔与 `null`。
- **状态追踪**：保留前一 Token、`has_newline`、`paren_depth`、模板状态等上下文，供 ASI 与正则判定使用。

### 2. 语法分析 (Parser)

基于 `GNU Bison` + GLR 模式实现。

- **语句/模块**：`var/let/const`、标签、`if/for/while/do-while/switch/with/try`、`for-in`、`for-of`、`function`/`function*`、`async function`、`class`、`import`/`export`、`return`/`break`/`continue`/`throw` 等完整 Script/Module 集合。
- **表达式**：包括 `new` 调用链、链式成员访问、所有复合赋值与位运算、`?:`、`yield`/`yield*`、`await`、模板字符串、解构赋值/绑定、`...spread/rest`、标签表达式等；`primary_no_obj`/`assignment_expr_no_obj` 保证表达式语句不会与对象字面量冲突。
- **生成器/解构**：`binding_pattern`/`assignment_pattern` 统一对象 & 数组语义，`AST_BINDING_PATTERN`/`AST_SPREAD_ELEMENT` 在 AST 层保持一致结构。
- **前瞻技巧**：`ARROW_HEAD`、`FUNCTION_DECL`、`member_call_expr`、`arrow_head_marker` 等产生式降低 GLR 歧义，确保压缩代码也可解析。

### 3. 自动分号插入 (ASI)

`parser_lex_adapter.c` 负责把 `lexer` Token 投递给 Bison，并在必要位置插入虚拟 `';'`。

- **触发条件**：遵循 ECMA-262 §11.9（三元换行、EOF、`return/break/continue/throw/yield` 受限产生式）。
- **额外规则**：针对 `catch` 头、`new Foo()` 后换行的 IIFE、`? : { ... }` 属性值、`ARROW_HEAD`、模板字符串、`)` 调用链、`await`/`yield` 等场景做前瞻抑制，避免误插。
- **调试手段**：`js_lexer.exe` 可配合 `--dump-asi`（参见 `docs/asi_implementation.md`）输出判定过程；所有失败会记录到 `build/parser_error_locations.log`。

### 4. 抽象语法树 (AST)

- **节点覆盖**：`AST_PROGRAM`, `AST_MODULE`, `AST_IMPORT/EXPORT`、`AST_CLASS_DECL/EXPR`、`AST_ARROW_FUNCTION`, `AST_GENERATOR`, `AST_FOR_OF_STMT`, `AST_TEMPLATE_LITERAL`, `AST_BINDING_PATTERN`, `AST_SPREAD_ELEMENT` 等 90+ 节点，保证 `--dump-ast` 可完整重建结构。
- **调试方式**：`js_parser.exe --dump-ast file.js` 结合 VS Code Compare 追踪差异；`ast_print` 输出缩进树，`ast_free` 确保批量跑数据集不泄漏。

### 5. 调试与排错

- `build/parser_error_locations.log`：`make test`/`make test-parse` 自动刷新，包含所有失败的 `文件:行:列:错误信息`；配合 `build/test_failures.log` 能快速定位。
- `tmp/`：用于存放最小复现脚本，`make test tmp/repro*.js` 可单独验证。
- `docs/error_diagnostics.md`：总结日志与排查策略；`docs/parser.md`/`docs/asi_implementation.md` 记录语法/ASI 结构细节。

---

## 测试报告

项目包含完善的回归测试套件。

### 测试命令

```bash
make test
```

### 测试覆盖

| 类别             | 覆盖内容                                                                                                                    |
| :--------------- | :-------------------------------------------------------------------------------------------------------------------------- |
| **基础语法**     | `test/test_basic.js`, `test/test_simple.js`, `test/test_functions.js`                                                       |
| **ASI / 控制流** | `test/test_asi_*`, `test/test_try.js`, `test/test_switch.js`, `test/test_while.js`                                          |
| **ES6 阶段**     | `test/es6_stage1`（解构）、`stage2`（箭头/默认参数）、`stage3`（模板）、`stage4`（class）、`stage5`（for-of/生成器/spread） |
| **数据集回归**   | `test/JavaScript_Datasets/goodjs`（预期成功）、`badjs`（预期失败集合）                                                      |
| **错误处理**     | `test/test_error_*.js`（缺冒号/括号/分号等）、`test/test_error_cases.js`                                                    |

> 建议在修改语法/ASI 后执行 `.uild.bat clean && .uild.bat parser && .uild.bat test` 或 `make clean && make parser && make test ./test/JavaScript_Datasets/goodjs`，确保生成代码同步并通过完整回归。
