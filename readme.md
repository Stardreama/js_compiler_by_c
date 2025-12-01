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

`js_compiler_by_c` 是一个面向 ES5 子集的语法前端，使用 C 语言实现。它利用 `re2c` 进行词法分析，`Bison` 进行语法分析，并实现了自动分号插入 (ASI) 和抽象语法树 (AST) 生成。

> ⚠️ **ES6 限制**：`test/JavaScript_Datasets` 中部分样例包含箭头函数解构、默认参数、模板字符串等 ES2015+ 语法，当前解析器会给出语法错误。详见 `docs/es6_limitations.md` 获取具体说明与定位思路。

### 核心特性

- **词法分析**：识别 ES5 关键字、运算符、字面量（含科学计数法、十六进制）、注释等。
- **语法分析**：支持变量声明、函数、控制流（if/for/while/switch）、异常处理（try/catch）、表达式等。
- **自动分号插入 (ASI)**：严格遵循 ECMA-262 11.9 规范，支持换行、EOF 和受限产生式触发。
- **AST 生成**：生成结构化的抽象语法树，支持 `--dump-ast` 打印。
- **双模式运行**：
  - `js_lexer.exe`: 仅输出 Token 流，用于调试词法。
  - `js_parser.exe`: 执行完整语法分析并输出 AST。

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

- `src/`: 源代码 (`lexer.re`, `parser.y`, `ast.c`, etc.)
- `test/`: 测试用例集 (`test_basic.js`, `test_asi_*.js`, etc.)
- `bin/`: 预编译工具链 (Windows)
- `build/`: 构建产物
- `docs/`: 详细技术文档

---

## 技术文档

### 1. 词法分析 (Lexer)

基于 `re2c` 实现。

- **关键字**：支持 `var`, `function`, `if`, `return` 等 27 个关键字。
- **运算符**：支持 `+`, `++`, `===`, `>>>` 等 73+ 种运算符。
- **字面量**：支持整数、浮点、科学计数法、字符串（转义字符）、布尔值。
- **状态追踪**：精确记录行号、列号，维护 `has_newline` 状态供 ASI 使用。

### 2. 语法分析 (Parser)

基于 `GNU Bison` 实现。

- **语句支持**：
  - 声明：`var`, `let`, `const`, `function`
  - 控制流：`if-else`, `for`, `while`, `do-while`, `switch`
  - 跳转：`break`, `continue`, `return`, `throw` (含 Label 支持)
  - 异常：`try-catch-finally`
  - 其他：`with`, 块语句, 空语句
- **表达式支持**：
  - 全套运算符优先级（赋值 < 逻辑 < 位运算 < 比较 < 计算 < 一元 < 后缀）
  - 数组/对象字面量
  - 函数调用与成员访问

### 3. 自动分号插入 (ASI)

在 `parser_lex_adapter.c` 中实现，作为词法与语法之间的中间层。

- **触发条件**：
  1.  **换行**：当前 Token 与前一个 Token 之间有换行，且语法无法继续。
  2.  **EOF**：文件结束。
  3.  **受限产生式**：`return`, `break`, `continue`, `throw` 后紧跟换行。
- **保护机制**：维护控制语句栈，防止在 `if (...)` 或 `for (...)` 头部错误插入分号。

### 4. 抽象语法树 (AST)

定义在 `ast.h`，实现于 `ast.c`。

- **节点类型**：`AST_VAR_DECL`, `AST_FUNCTION`, `AST_BINARY_EXPR` 等。
- **调试**：使用 `./js_parser.exe --dump-ast file.js` 查看树形结构。

---

## 测试报告

项目包含完善的回归测试套件。

### 测试命令

```bash
make test
```

### 测试覆盖

| 类别         | 覆盖内容                                      |
| :----------- | :-------------------------------------------- |
| **基础语法** | 变量声明, 函数, if/for/while, 数组/对象       |
| **ASI 机制** | 换行触发, return 受限产生式, 控制流保护       |
| **复杂结构** | 嵌套函数, 闭包, switch-case, try-catch        |
| **运算符**   | 优先级, 结合性, 复合赋值, 位运算              |
| **错误处理** | 缺少分号, 缺少括号, 非法语法 (验证报错准确性) |
