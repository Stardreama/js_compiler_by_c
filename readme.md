# JavaScript 语法解析器（C 实现）

## 概要

`js_compiler_by_c` 是一个面向 ES5 子集的语法前端，使用 re2c + Bison 在 C 语言环境下实现：

- **词法分析器**：`lexer.re` 生成的扫描器负责 token 切分以及行列跟踪；
- **语法分析器**：`parser.y` 生成的 LR 语法，集成自动分号插入（ASI）和 AST 构建；
- **AST 能力**：`ast.c/ast.h` 提供节点构造、打印（`--dump-ast`）与释放；
- **双执行程序**：`js_lexer.exe` 用于 token dump，`js_parser.exe` 进行语法校验与 AST 输出。

项目已覆盖 while/try/switch/with 等语句、复合赋值与按位/三元/逗号等表达式，并配备回归测试与中文技术文档。

## 核心特性

- **自动分号插入**：依照 ECMA-262 11.9 实现换行、EOF、受限产生式三类触发；
- **运算符层级完善**：支持位运算、位移、`?:`、复合赋值、`typeof/delete/void` 与逗号序列；
- **语句覆盖**：含标签语句、with、try-catch-finally、switch、do-while 等 ES5 常见结构；
- **AST 工具**：`js_parser.exe --dump-ast file.js` 可打印缩进树，便于调试和后续静态分析；
- **测试脚本**：`build.bat test-parse` / `make test-parse` 一次性跑通 9 个正向用例及错误用例集。

## 构建与运行

### Windows（PowerShell）

```powershell
cd d:\project\js_compiler_by_c
build.bat parser      # 生成 js_parser.exe
build.bat test-parse  # 重建并运行全部语法测试
```

### MSYS2 / Linux

```bash
cd /path/to/js_compiler_by_c
make parser       # 构建语法分析器
make test-parse   # 执行回归测试
```

### 常用命令

```powershell
build.bat          # 构建 js_lexer.exe
build.bat clean    # 清理生成文件
build.bat test     # 构建词法分析器并跑基础 token 测试
build.bat help     # 查看脚本说明
```

语法分析器支持 AST 输出：

```powershell
build.bat parser
js_parser.exe --dump-ast tests\test_basic.js
```

## 目录速览

```text
js_compiler_by_c/
├── ast.c / ast.h              # AST 节点、打印、释放
├── build.bat                  # Windows 构建脚本
├── docs/                      # 中文文档与清单
│   ├── BUILD.md               # 构建与调试指南
│   ├── TEST_REPORT.md         # 最近测试结果
│   ├── asi_implementation.md  # ASI 逻辑详解
│   ├── parser.md / lex.md     # 语法 / 词法说明
│   └── todo.md                # 任务与进度
├── lexer.re                   # re2c 词法描述
├── main.c                     # js_lexer.exe 入口
├── Makefile                   # MSYS2/Linux 构建脚本
├── parser.y                   # Bison 语法描述
├── parser_lex_adapter.c       # 词法-语法桥接 + ASI
├── parser_main.c              # js_parser.exe 入口
├── tests/                     # JS 用例集
│   ├── test_basic.js
│   ├── test_simple.js
│   ├── test_asi_basic.js
│   ├── test_asi_control.js
│   ├── test_asi_return.js
│   ├── test_error_cases.js
│   ├── test_error_missing_semicolon.js
│   ├── test_error_object.js
│   ├── test_operators.js
│   ├── test_switch.js
│   ├── test_try.js
│   └── test_while.js
└── token.h                    # Token 定义与词法状态
```

## 测试矩阵

- `build.bat test-parse` / `make test-parse`：顺序执行 9 个正向用例（含运算符、ASI、控制流）并确保全部通过；
- 错误用例集：`tests/test_error_cases.js`、`tests/test_error_object.js`、`tests/test_error_missing_semicolon.js` 用于验证诊断信息；
- 词法 smoke 测试：`build.bat test` 或手动运行 `js_lexer.exe tests\test_basic.js`。

## 已知限制

- 仍专注 ES5，暂不支持箭头函数、类、模板字符串、正则字面量等 ES6+ 特性；
- re2c 和 Bison 在构建阶段会提示惯常的 sentinel/shift-reduce 警告，可按需抑制或调整；
- 尚未引入 CI、模糊测试与性能基准，参考 `docs/todo.md` 中的 P5/PQ 任务。

## 参考资料

- [ECMAScript 5.1 规范](https://262.ecma-international.org/5.1/)
- [re2c 官方手册](https://re2c.org/manual/manual_c.html)
- [GNU Bison Manual](https://www.gnu.org/software/bison/manual/)
- [Automatic Semicolon Insertion](https://262.ecma-international.org/5.1/#sec-11.9)

---

**最后更新**：2025 年 11 月 10 日
