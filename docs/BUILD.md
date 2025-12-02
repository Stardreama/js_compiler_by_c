# JavaScript 编译器 - 构建与调试指南

本文档介绍如何在当前项目中构建词法分析器与语法分析器，并重点记录抽象语法树（AST）的生成与调试流程。所有示例命令默认在仓库根目录执行，如未特殊说明均适用于 MinGW 环境。

## 构建产物概览

- `js_lexer.exe`：输出 Token 流的词法分析工具，便于定位词法规则问题。
- `js_parser.exe`：完成语法分析并生成 AST，支持 `--dump-ast` 选项输出树形结构。

> 提示：`src/` 下的 `lexer.re`/`parser.y`/`ast.*` 才是权威源文件，根目录的副本仅供编辑器提示使用。修改语法或词法后，务必执行 `./make parser`（或 `build.bat parser`）以重新生成 `build/generated/parser.{c,h}` 并保持镜像一致。

## 环境要求

- GCC（MinGW64，脚本默认路径为 `D:\mingw64\bin\gcc.exe`）。
- re2c ≥ 3.0 与 Bison ≥ 3.0（通过脚本自动调用）。
- 可选：MSYS2 或类 Unix 环境以使用 `make`。

## 便携式工具链（Windows）

- 仓库自带的 `bin/` 目录打包了 `gcc`、`re2c`、`bison`、`m4` 等可执行文件，针对未安装 MSYS2 的机器准备。
- 直接在 PowerShell/CMD 中运行 `.\\make` 会调用 `make.cmd`：脚本会把 `bin/` 写入 `PATH`，并用 MSYS 风格路径填充 `BISON_PKGDATADIR` 与 `M4`，确保 Bison 能找到 `bin/share/bison/m4sugar/m4sugar.m4`。
- 由于生成物会被缓存，跨设备测试前建议执行 `.\\make clean`，再运行 `.\\make` 或 `.\\make parser`/`test` 等目标以避免旧的 `build/generated` 干扰。
- 如果仍需进入 MSYS2/mingw64 终端，可继续使用系统 `make`；脚本只是在纯 Windows Shell 下提供一键式环境。

## Windows 构建流程（build.bat）

```bash
# 构建词法分析器 (js_lexer.exe)
.\build.bat

# 构建语法分析器（同时触发 AST 相关代码编译）
.\build.bat parser

# 构建词法分析器并运行测试
.\build.bat test

# 构建语法分析器并运行测试
.\build.bat test-parse

# 清理所有生成文件
.\build.bat clean

# 显示帮助信息
.\build.bat help
```

脚本内部会按顺序运行 re2c、Bison 与 GCC。修改 `lexer.re` 或 `parser.y` 后无需手动调用 re2c/Bison，直接执行 `build.bat parser` 即可重新生成 `lexer.c`、`parser.c`、`parser.h` 以及链接 AST 支持代码。

## MSYS2 / Linux 构建流程（Makefile）

```bash
# 构建词法分析器 (js_lexer.exe)
make

# 构建 js_parser.exe（含 AST）
make parser

# 运行语法与 AST 正向测试
make test-parse

# 清理输出
make clean

# 显示帮助信息
make help
```

## 运行程序

### 词法分析器 (js_lexer.exe)

输出 Token 流，用于调试词法分析过程。

```bash
# 分析 JavaScript 文件
.\js_lexer.exe test\test_basic.js

# 或使用任何 JS 文件
.\js_lexer.exe your_script.js
```

**示例输出：**

```text
=== Lexical Analysis of 'test\test_basic.js' ===

[  1] Line   2, Col   1: VAR             = 'var'
[  2] Line   2, Col   5: IDENTIFIER      = 'x'
[  3] Line   2, Col   7: =
[  4] Line   2, Col   9: NUMBER          = '10'
[  5] Line   2, Col  11: ;
[  6] Line   3, Col   1: LET             = 'let'
...

=== Analysis Complete ===
Total tokens: 106
```

### 语法分析器 (js_parser.exe)

验证 JavaScript 语法，报告成功或详细错误信息；使用 `--dump-ast` 选项可输出抽象语法树。

```bash
# 分析 JavaScript 文件
.\js_parser.exe test\test_basic.js

# 测试语法正确的文件
.\js_parser.exe test\test_simple.js

# 测试语法错误的文件
.\js_parser.exe test\test_error_object.js

# 输出 AST 结构
.\js_parser.exe --dump-ast test\test_basic.js
```

**成功示例：**

```text
Parsing successful! Input file: test\test_basic.js
```

### 自动分号插入（ASI）

解析器已实现 ECMAScript 5.1 规范中的自动分号插入逻辑，核心特性如下：

- **触发条件**：
  1. Token 之间存在换行且继续解析会产生语法错误。
  2. 输入流结束（EOF）。
  3. 受限产生式（`return` / `break` / `continue` / `throw`）后遇到换行或文件结束。
- **关键实现**：`parser_lex_adapter.c` 通过 `lexer->has_newline` 标志、上一 Token 记录以及控制语句括号栈在必要时注入虚拟分号。
- **典型场景**：
  - `a\n++b` 会被拆分为 `a; ++b`
  - `return\nvalue` 会被解析为 `return; value`
  - `if (flag)\nreturn value` 在 `if` 结构内不会多插分号
- **错误示例：**

运行 `build.bat test-parse` 或 `make test-parse` 可一次性验证基础语法与 ASI 相关用例。

```text
Parsing failed. Input file: test\test_error_object.js
Syntax error: syntax error, unexpected STRING, expecting ':'
```

## 回归套件与日志

- **基础回归**：`./make test`（或 `.uild.bat test`）会串行运行 `test/` 根目录下的所有样例，等价于依次执行 `test_*` 与 `test_error_*`。
- **ES6 分阶段**：`make test test/es6_stage1` ~ `stage5` 可验证解构、箭头函数、模板、类、`for-of`/生成器/spread 等增量能力。
- **真实数据集**：`make test test/JavaScript_Datasets/goodjs`（预期成功）与 `.../badjs`（预期失败集合）覆盖压缩脚本；路径同样适用于 `.uild.bat test <path>`。
- **错误日志**：每次测试前会清空 `build/parser_error_locations.log`，失败用例会以 `文件:行:列:错误` 形式追加。`build/test_failures.log` 保存完整 stdout/stderr，便于和 Node/V8 行为对照。

> 如只想验证单个 repro，可将其放在 `tmp/` 后执行 `make test tmp/repro_cond_simple.js`；日志同样会落在 `build/parser_error_locations.log`。

## 已实现的功能

### ✅ 词法分析 (Lexer)

**关键字识别：**

- 变量声明: `var`, `let`, `const`
- 函数: `function`, `return`
- 控制流: `if`, `else`, `for`, `while`, `do`, `switch`, `case`, `default`
- 异常处理: `try`, `catch`, `finally`, `throw`
- 其他: `break`, `continue`, `new`, `this`, `typeof`, `delete`, `in`, `instanceof`, `void`, `with`, `debugger`

**字面量识别：**

- 数字: 整数、浮点数、科学计数法、十六进制
- 字符串: 单引号和双引号字符串，支持转义字符
- 布尔值: `true`, `false`
- 特殊值: `null`, `undefined`

**运算符：**

- 算术: `+`, `-`, `*`, `/`, `%`, `++`, `--`
- 比较: `==`, `!=`, `===`, `!==`, `<`, `>`, `<=`, `>=`
- 逻辑: `&&`, `||`, `!`
- 位运算: `&`, `|`, `^`, `~`, `<<`, `>>`, `>>>`
- 赋值: `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`, `>>>=`
- 三元: `?`, `:`

**分隔符：**

- 括号: `(`, `)`, `{`, `}`, `[`, `]`
- 其他: `;`, `,`, `.`

**其他功能：**

- 单行注释 (`//`) 和多行注释 (`/* */`)
- 行号和列号精确跟踪（用于错误报告）
- 换行标记 `has_newline`（为 ASI 机制预留）

### ✅ 语法分析 (Parser)

**支持的语句：**

- 变量声明（`var`, `let`, `const`）
- 表达式语句
- 块语句 `{ ... }`
- if-else 条件语句
- for 循环（经典三段式）
- while / do-while 循环
- switch-case 语句（含 default、fallthrough、break/continue）
- try-catch-finally 异常处理与 throw 语句
- with 语句
- 标签语句与带标签的 break/continue
- 函数声明
- return 语句
- 空语句 `;`

**支持的表达式：**

- 字面量（数字、字符串、布尔值、`null`、`undefined`）
- 标识符、成员访问与函数调用
- 一元运算（`+`, `-`, `!`, `~`, `typeof`, `delete`, `void`）
- 二元运算（算术、比较、逻辑、按位、位移）
- 条件运算符 `cond ? expr : expr`
- 复合赋值（`+=`, `-=`, `*=`, `/=`, `%=`、`&=`, `|=`, `^=`, `<<=`, `>>=`, `>>>=`）
- 逗号表达式与序列表达式
- 数组、对象字面量与属性构造
- 括号分组 `(expr)`

**错误检测能力：**

- 详细的语法错误信息（包含期待的 token 和实际遇到的 token）
- 准确的错误位置报告
- Bison 详细错误输出（`%define parse.error verbose`）

**歧义消解：**

- 正确区分块 `{...}` 和对象字面量 `{...}`
- 使用 `expr_no_obj` 变体避免表达式语句歧义

### ✅ 抽象语法树 (AST)

- `ast.h` / `ast.c` 定义统一的 AST 节点类型与构造函数。
- `parser.y` 的语义动作会为程序、语句与表达式创建节点，并串联成完整的树结构。
- `ast_print` 支持缩进输出，配合 `js_parser.exe --dump-ast` 可快速检查语义结构。
- `ast_traverse` 提供深度优先遍历回调，便于后续实现代码生成或静态分析。
- `ast_free` 负责递归释放所有节点，避免内存泄漏。

## 编译警告说明

构建过程中会出现以下警告，这些警告**不影响功能**：

### 1. re2c sentinel 警告

```text
lexer.re:82:20: warning: sentinel symbol 0 occurs in the middle of the rule
```

- **影响：** 无影响，仅是 re2c 的优化建议
- **原因：** re2c 检测到字符串结束符在规则中间
- **可忽略**

### 2. Bison 冲突警告

```text
parser.y: 警告: 3 项偏移/归约冲突 [-Wconflicts-sr]
```

- **影响：** 无影响，Bison 使用默认规则解决冲突
- **原因：** 表达式语法的自然歧义（如 if-else 的悬挂 else）
- **可忽略**（或使用 `%expect 2` 指令消除警告）

### 3. 未使用变量警告

```text
lexer.re:89:25: warning: unused variable 'comment_start'
```

- **影响：** 无影响
- **建议：** 可以删除未使用的变量

## 下一步开发计划

### ✅ 优先级 P2 - AST 构建

- AST 节点体系与打印、遍历、释放流程已落地，详见 `ast.h` / `ast.c`，并可通过 `js_parser.exe --dump-ast` 体验树形输出。

### ✅ 优先级 P3 - 扩展语句覆盖

- [x] while 循环
- [x] do-while 循环
- [x] switch-case 语句
- [x] try-catch-finally 异常处理、throw、with、标签语句

### ✅ 优先级 P4 - 完整运算符支持

- [x] 三元运算符 `? :`
- [x] 完整的位运算与位移层级
- [x] 复合赋值运算符与逗号表达式

### 优先级 P5 - 高级特性

- [ ] 正则表达式字面量（需要上下文感知）
- [ ] ES6+ 特性（箭头函数、模板字符串等）

## 测试文件

项目包含以下测试用例：

- `test/test_basic.js` - 综合基本语法测试 ✅
- `test/test_simple.js` - 简单功能测试 ✅
- `test/test_asi_basic.js` - ASI 基础场景 ✅
- `test/test_asi_return.js` - `return` 受限产生式 ✅
- `test/test_asi_control.js` - 与控制语句的协同 ✅
- `test/test_while.js` - while/do-while + break/continue + 标签 ✅
- `test/test_switch.js` - switch-case/default 场景 ✅
- `test/test_try.js` - try-catch-finally / with ✅
- `test/test_operators.js` - 复合赋值、按位、三元与逗号组合 ✅
- `test/test_error_missing_semicolon.js` - 缺少分号错误测试 ✅
- `test/test_error_object.js` - 对象字面量错误测试 ✅
- `test/test_error_cases.js` - 错误用例集合（需逐个激活测试）

## 技术细节

- **词法分析器生成器**: re2c 3.0+
- **语法分析器生成器**: Bison 3.x
- **编译器**: GCC (MinGW)
- **C 标准**: C99
- **构建系统**: build.bat (Windows) / Makefile (MSYS2/Linux)

## 项目目录结构

```text
js_compiler_by_c/
├── ast.c / ast.h              # AST 结构定义、构造、打印与释放
├── build.bat                  # Windows 构建脚本
├── docs/                      # 项目文档
│   ├── BUILD.md               # 本文档
│   ├── TEST_REPORT.md         # 测试报告
│   ├── asi_implementation.md  # ASI 实现细节
│   ├── parser.md / lex.md     # 词法与语法说明
│   └── todo.md                # 任务清单
├── lexer.re                   # re2c 词法分析器源文件（首次执行后生成 lexer.c）
├── main.c                     # 词法分析器入口
├── Makefile                   # MSYS2/Linux 构建脚本
├── parser.y                   # Bison 语法分析器源文件（生成 parser.c / parser.h）
├── parser_lex_adapter.c       # 词法-语法适配层（含 ASI 逻辑）
├── parser_main.c              # 语法分析器入口（支持 --dump-ast）
├── test/
│   ├── test_basic.js          # 综合语法
│   ├── test_simple.js         # 小型示例
│   ├── test_asi_basic.js      # ASI 基础
│   ├── test_asi_control.js    # ASI 与控制语句
│   ├── test_asi_return.js     # ASI 受限产生式
│   ├── test_error_cases.js    # 汇总错误场景
│   ├── test_error_missing_semicolon.js
│   ├── test_error_object.js
│   ├── test_operators.js      # 运算符覆盖
│   ├── test_switch.js
│   ├── test_try.js
│   └── test_while.js
└── token.h                    # Token 类型定义及词法状态
```

## 常见问题

### Q: 为什么需要两个可执行程序？

**A:** 双可执行程序设计便于调试：

- `js_lexer.exe` 输出所有 Token，方便查看词法分析结果
- `js_parser.exe` 专注语法验证，提供清晰的成功/失败反馈

### Q: 构建时的警告是否需要修复？

**A:** 不是必须的。这些警告不影响程序功能：

- re2c 和 Bison 的警告是优化建议
- 未使用变量警告可以修复但不影响运行

### Q: 如何添加新的测试用例？

**A:** 在 `test/` 目录创建新的 `.js` 文件，然后运行：

```bash
.\js_parser.exe test\your_test.js
```

### Q: 为什么使用 re2c 而不是 Flex？

**A:** JavaScript 标识符基于 Unicode 定义（ECMAScript 规范），re2c 原生支持 Unicode 字符类，而 Flex 不支持。

### Q: 当前是否支持 ES6+ 语法？

**A:** 已支持 ES2015 ~ ES2017 的主流语法（类、模块、解构、模板字符串、箭头函数、`function*`/`yield*`、`for-of`、`async`/`await`、spread/rest 等）。ES2020+（可选链、空值合并、顶层 `await`、装饰器等）仍在规划中，详见 `docs/es6_limitations.md`。

## 参考资源

- [ECMAScript 5.1 规范](https://262.ecma-international.org/5.1/)
- [ASI 规则详解（11.9 节）](https://262.ecma-international.org/5.1/#sec-11.9)
- [re2c 手册](https://re2c.org/manual/manual_c.html)
- [Bison 手册](https://www.gnu.org/software/bison/manual/)
- [参考项目：flex-bison-examples](https://github.com/sunxfancy/flex-bison-examples)

---

**最后更新**: 2025 年 11 月 10 日
