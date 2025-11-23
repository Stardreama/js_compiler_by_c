# JavaScript 语法解析器项目说明书

> 最后更新：2025-11-10
>
> 本文档用于支撑答辩材料与 PPT 编制，涵盖项目背景、架构设计、关键技术、测试体系与后续规划等信息。

---

## 1. 项目概述

- **项目名称**：`js_compiler_by_c`
- **定位**：面向 ECMAScript 5.1 子集的轻量级 JavaScript 前端，提供词法分析、语法分析、AST 生成与自动分号插入（ASI）支持。
- **开发目标**：
  1. 判断 JS 源文件是否符合语法规范；
  2. 实现 ASI 机制，正确处理省略分号场景；
  3. 输出抽象语法树，便于后续静态分析或代码生成。
- **工具链**：
  - 词法生成：`re2c`
  - 语法生成：`bison`
  - 编程语言：`C (C99)`
  - 构建环境：Windows（`build.bat`）、MSYS2/Linux（`Makefile`）

---

## 2. 需求与规范对齐

| 需求项       | 当前实现 | 说明                                                               |
| ------------ | -------- | ------------------------------------------------------------------ |
| 语法合规判定 | ✅       | `js_parser.exe` 返回成功/错误并输出诊断信息                        |
| 自动分号插入 | ✅       | `parser_lex_adapter.c` 覆盖换行、EOF、受限产生式                   |
| AST 输出     | ✅       | `js_parser.exe --dump-ast <file>` 生成缩进树                       |
| 提交材料     | ✅       | `lexer.re`, `parser.y`, C 源文件、测试用例、`Makefile`/`build.bat` |
| 规范依据     | ✅       | 对照 [ECMA-262 v5.1](https://262.ecma-international.org/5.1/)      |

---

## 3. 目录结构速览

```text
js_compiler_by_c/
├── PROJECT_OVERVIEW.md        # 本说明书
├── ast.c / ast.h              # AST 定义、构造、打印、释放
├── build.bat                  # Windows 构建脚本
├── lexer.re                   # re2c 词法规则
├── main.c                     # js_lexer.exe 入口
├── Makefile                   # MSYS2 / Linux 构建脚本
├── parser.y                   # Bison 语法规则与语义动作
├── parser.c / parser.h        # 由 bison 生成（版本控制）
├── parser_lex_adapter.c       # 词法-语法桥接 + ASI 实现
├── parser_main.c              # js_parser.exe 入口
├── token.h                    # Token 结构及枚举
├── docs/                      # 文档中心
│   ├── readme.md
│   ├── BUILD.md
│   ├── TEST_REPORT.md
│   ├── asi_implementation.md
│   ├── lex.md / parser.md
│   └── todo.md
└── test/                     # 正/负向测试用例
    ├── test_basic.js
    ├── test_functions.js
    ├── test_for_loops.js
    ├── test_literals.js
    ├── test_asi_*.js
    ├── test_switch.js
    ├── test_try.js
    ├── test_operators.js
    ├── test_error_*.js
    └── ...
```

---

## 4. 系统架构

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
└───────────────┘
```

- **词法阶段**：`lexer.re` 负责关键字、运算符、字面量识别，维护 `line`/`column`、`has_newline` 等状态。
- **适配层**：`parser_lex_adapter.c` 中的 `yylex()` 封装 token 队列、ASI 插入逻辑及控制结构上下文。
- **语法阶段**：`parser.y` 定义 LL(1) 样式 Bison 语法，创建 AST，处理语句/表达式优先级与歧义。
- **AST 管理**：`ast.c` 提供 `ast_make_*` 构造器、`ast_print`、`ast_free`，确保诊断与内存安全。

---

## 5. 核心模块详解

### 5.1 词法分析 (`lexer.re`)

- **关键职责**：
  - 匹配 27 个 ES5 关键字、73+ 运算符/分隔符；
  - 支持整数/浮点/科学计数法/十六进制数字；
  - 处理单行、块注释并维护位置状态；
  - 记录 `has_newline` 供 ASI 参考；
  - Token 通过 `token.h` 封装并分配堆内存。
- **注意事项**：
  - `comment_start` 变量为后续注释定位预留；
  - 生成代码 `lexer.c` 需纳入版本控制，避免工具缺失影响构建。

### 5.2 语法分析 (`parser.y`)

- **语句支持**：`if/else`, `for`, `while`, `do-while`, `switch`, `try-catch-finally`, `with`, `label`, `break/continue/throw`（含标签）。
- **表达式支持**：算术、逻辑、条件 `?:`、按位、位移、复合赋值、逗号运算符、对象/数组字面量、成员访问、函数调用、一元关键字 `typeof/delete/void`。
- **优先级控制**：通过 `%left` / `%right` 指令从赋值向下排列，确保结合性正确。
- **AST 生成**：每条产生式都构造对应 AST 节点（见 `ast_make_program`、`ast_make_binary` 等）。

### 5.3 自动分号插入 (`parser_lex_adapter.c`)

- **核心逻辑**：`should_insert_semicolon()` 根据以下条件注入 `';'`：
  1. `has_newline` 为真，且当前 token 无法紧跟前 token；
  2. 到达 EOF；
  3. 受限产生式：`return`, `break`, `continue`, `throw` 后出现换行/EOF/`}`。
- **全局状态**：
  - `g_paren_depth`：跟踪括号与控制语句头的完整性；
  - `g_last_token`：缓存最后一个真实 token；
  - `g_control_stack`：防止 `if/for/while` 头部提前插入分号；
  - `g_pending`：队列缓存因 ASI 插入的虚拟 token。

### 5.4 AST 框架 (`ast.c` / `ast.h`)

- 定义 `ASTNodeType` 枚举、`ASTNode` 结构。
- 支持列表节点 `ASTList`，用于语句块、参数、元素等集合。
- `ast_print` 以缩进形式输出，便于审查树结构。
- `ast_free` 递归回收，避免内存泄漏。

### 5.5 可执行程序

- `js_lexer.exe`（入口：`main.c`）：输出 token 序列（调试词法）。
- `js_parser.exe`（入口：`parser_main.c`）：
  - 默认模式：语法校验并给出结果；
  - `--dump-ast`：输出 AST。

---

## 6. 构建与运行

### 6.1 Windows (PowerShell)

```powershell
cd d:\project\js_compiler_by_c
.\build.bat             # 构建 js_lexer.exe
.uild.bat parser      # 构建 js_parser.exe
.uild.bat test-parse  # 构建 + 批量语法测试
.uild.bat clean       # 清理产物
```

### 6.2 MSYS2 / Linux (bash)

```bash
cd /path/to/js_compiler_by_c
make            # 构建 js_lexer.exe
make parser     # 构建 js_parser.exe
make test-parse # 批量语法测试
make clean      # 清理
```

- **依赖**：`gcc`、`re2c`、`bison`、`make`
- `build.bat` 默认读取 `D:\mingw64\bin\gcc.exe`，必要时可调整变量。

---

## 7. 测试体系

### 7.1 正向测试概览

| 测试文件                    | 覆盖点                                     |
| --------------------------- | ------------------------------------------ |
| `test/test_basic.js`       | 基础声明、控制流、数组/对象                |
| `test/test_simple.js`      | 函数定义与调用                             |
| `test/test_functions.js`   | 函数嵌套、循环调用、别名                   |
| `test/test_for_loops.js`   | 初始化/无初始化 for、嵌套、无限循环        |
| `test/test_literals.js`    | 多层对象/数组、条件表达式                  |
| `test/test_asi_basic.js`   | ASI 基础场景、`a\n++b`                     |
| `test/test_asi_return.js`  | `return` 受限产生式                        |
| `test/test_asi_control.js` | ASI 与 `if/else` 协同                      |
| `test/test_while.js`       | while/do-while、标签                       |
| `test/test_switch.js`      | switch/default、fall-through               |
| `test/test_try.js`         | try/catch/finally、with                    |
| `test/test_operators.js`   | 复合赋值、按位、逗号、`typeof/delete/void` |

### 7.2 负向测试概览

| 测试文件                                | 预期错误         |
| --------------------------------------- | ---------------- |
| `test/test_error_missing_semicolon.js` | 缺少分号         |
| `test/test_error_object.js`            | 对象属性缺冒号   |
| `test/test_error_unclosed_block.js`    | 缺少 `}`         |
| `test/test_error_invalid_for.js`       | `for` 头部缺 `)` |

### 7.3 执行方式

- 批量测试：`.uild.bat test-parse` 或 `make test-parse`
- 单文件调试：`.uild.bat parser` 后运行 `.\\js_parser.exe <file>`? wait wrong

---

## 8. 关键技术亮点

1. **ASI 全面实现**：结合换行、受限产生式和控制结构栈，覆盖常见分号省略场景。
2. **AST 架构**：统一节点构造、打印、释放，为扩展语义分析奠定基础。
3. **语法覆盖广**：包含标签语句、with、try/catch/finally、switch 等 ES5 关键结构。
4. **可移植构建**：同一代码库支持 Windows 与 MSYS2/Linux 构建流程。
5. **测试驱动**：正向 + 负向测试矩阵确保语法和 ASI 行为稳定。

---

## 9. 质量保障

- **静态检查**：编译阶段保持 `-Wall -g -std=c99`，及时暴露潜在问题。
- **告警情况**：
  - `re2c` sentinel 警告（属优化建议）；
  - `bison` 三项 shift/reduce 冲突（已评估，对 if-else 等结构无影响，可通过 `%expect` 抑制）；
  - `comment_start` 未使用（保留后续增强空间）。
- **内存安全**：AST 析构函数覆盖所有节点类型，避免泄漏；Token 生命周期在解析完成后统一释放。

---

## 10. 答辩要点建议

1. **项目价值**：强调自研 JS 前端的实践意义，展示 ASI 与 AST 的完整链路。
2. **技术难点**：
   - 自动分号插入的触发条件组合；
   - 语法歧义（块 vs 对象、if-else、逗号表达式）；
   - 复合赋值与条件运算符的优先级处理。
3. **演示路线**：
   1. `.uild.bat parser` 构建；
   2. `js_parser.exe tests\test_functions.js` 成功消息；
   3. `js_parser.exe tests\test_error_invalid_for.js` 输出错误；
   4. `js_parser.exe --dump-ast tests\test_basic.js` 展示 AST。
4. **成果展示**：列出测试覆盖、文档体系、代码量与模块职责。
5. **扩展展望**：引出 P5（正则、模板字符串、箭头函数）、CI、静态分析等计划。

---

## 11. 后续规划（P5 方向）

- **语法扩展**：正则字面量、模板字符串、箭头函数、类、async/await、解构赋值等。
- **工具链**：
  - 集成 GitHub Actions 自动构建与测试；
  - 引入模糊测试（AFL/libFuzzer）查找崩溃；
  - 静态分析（Cppcheck、Clang SA）与代码覆盖率统计。
- **文档建设**：补充架构设计文档、贡献指南、开发者指南、API 文档。

---

## 12. 附录：可用参考资料

- ECMAScript 5.1 规范：<https://262.ecma-international.org/5.1/>
- re2c 官方手册：<https://re2c.org/manual/manual_c.html>
- GNU Bison Manual：<https://www.gnu.org/software/bison/manual/>
- 相关示例仓库：<https://github.com/sunxfancy/flex-bison-examples>

---

如需进一步补充或定制答辩材料，请根据本说明书的章节结构扩展 PPT 内容。祝答辩顺利！
