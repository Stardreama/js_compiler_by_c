# JavaScript 语法解析器（C 实现）

## 概要

`js_compiler_by_c` 是一个面向 ES5 子集的语法前端，使用本地打包的 re2c + Bison 在 C 语言环境下实现：

- **词法分析器**：`src/lexer.re` 生成的扫描器负责 token 切分以及行列跟踪；
- **语法分析器**：`src/parser.y` 生成的 LR 语法，集成自动分号插入（ASI）和 AST 构建；
- **AST 能力**：`ast.c/ast.h` 提供节点构造、打印（`--dump-ast`）与释放；
- **双执行程序**：`js_lexer.exe` 用于 token dump，`js_parser.exe` 进行语法校验与 AST 输出。

项目已覆盖 while/try/switch/with 等语句、复合赋值与按位/三元/逗号等表达式，并配备回归测试与中文技术文档。

## 核心特性

- **自动分号插入**：依照 ECMA-262 11.9 实现换行、EOF、受限产生式三类触发；
- **运算符层级完善**：支持位运算、位移、`?:`、复合赋值、`typeof/delete/void` 与逗号序列；
- **语句覆盖**：含标签语句、with、try-catch-finally、switch、do-while 等 ES5 常见结构；
- **AST 工具**：`js_parser.exe --dump-ast file.js` 可打印缩进树，便于调试和后续静态分析；
- **测试脚本**：`make test` 一次性跑通 `test/` 下的正向/负向 JS 用例。

## 构建与运行

项目提供统一的 `Makefile`，只需一个工具链即可在 **Windows（MSYS2/Git Bash）**、**Linux** 和 **macOS** 上构建：

```bash
cd /path/to/js_compiler_by_c
make              # 生成 js_lexer(.exe)，默认产物
make parser       # 额外生成 js_parser(.exe)
make test         # 在 test/ 目录中跑通所有 JS 用例
make clean        # 清理 build/ 与可执行文件
```

> 📦 **内置工具链**：`bin/` 目录需放置对应平台的 `gcc`、`re2c`、`bison` 可执行文件（Windows 使用 `.exe` 扩展，Linux/macOS 则为无扩展 ELF/Mach-O）。Windows 环境推荐直接把 MSYS2 的 `mingw64/` 目录拷贝到 `bin/mingw64/`，并把 `usr/bin` 精简副本放到 `bin/bin_usr/`（内含 `bison.exe`、`re2c.exe` 等），`Makefile` 会自动将这两个子目录加入 `PATH`。Linux/macOS 可继续把二进制直接放到 `bin/` 或复用系统级工具链。

语法分析器支持 AST 输出：

```bash
make parser
./js_parser --dump-ast test/test_basic.js
```

## 目录速览

```text
js_compiler_by_c/
├── Makefile                   # 跨平台构建入口（make/make parser/make test）
├── bin/                      # 打包工具链（Windows: mingw64/ + bin_usr/，其他平台直接平铺）
├── build/                    # make 生成的临时目录（obj/generated）
├── docs/                     # 中文文档与清单
├── lib/                      # 预留静态库/第三方依赖（占位）
├── src/                      # 所有 C / re2c / bison 源文件
│   ├── ast.c / ast.h
│   ├── lexer.re
│   ├── main.c
│   ├── parser.y
│   ├── parser_lex_adapter.c
│   ├── parser_main.c
│   └── token.h
├── test/                     # JS 用例集（make test 自动遍历）
│   ├── test_basic.js
│   ├── test_simple.js
│   ├── test_asi_basic.js
│   ├── test_asi_control.js
│   ├── test_asi_return.js
│   ├── test_error_cases.js
│   ├── test_error_missing_semicolon.js
│   ├── test_error_object.js
│   ├── test_error_unclosed_block.js
│   ├── test_operators.js
│   ├── test_switch.js
│   ├── test_try.js
│   └── test_while.js
└── 项目介绍.md / PROJECT_OVERVIEW.md 等补充文档
```

## 测试矩阵

- `make test`：顺序执行 `test/` 下的正向/负向用例，遇到非预期结果会立即标红；
- 错误用例集：`test/test_error_cases.js`、`test/test_error_object.js`、`test/test_error_missing_semicolon.js` 用于验证诊断信息；
- 词法 smoke 测试：`./js_lexer$(EXE) test/test_basic.js`。

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

**最后更新**：2025 年 11 月 17 日
