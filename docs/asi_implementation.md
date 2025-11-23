# 自动分号插入（ASI）实现说明

> 适用于当前的 `js_compiler_by_c` 代码库。本文档以中文总结 ASI 的行为、实现细节与测试策略，便于继续扩展或排查问题。

## 功能概览

- **兼容范围**：遵循 ECMAScript 5.1 第 11.9 节的三类触发条件（换行、EOF、受限产生式）。
- **实现位置**：`parser_lex_adapter.c` 在向 Bison 交付 token 前决定是否插入虚拟分号；词法阶段无需改动。
- **测试覆盖**：`build.bat test-parse` / `make test-parse` 会顺序运行 `test/test_asi_basic.js`、`test/test_asi_return.js` 与 `test/test_asi_control.js`。

## 触发条件明细

1. **换行触发**：当上一个 token 可以合法结束语句、并且 `lexer->has_newline == true` 且继续解析会出现语法错误时，插入分号。例如：

```text
a
++b   // 解析为 a; ++b
```

1. **文件结束（EOF）**：输入结束但最后一个 token 可以结束语句时，自动补分号。

1. **受限产生式**：`return`、`break`、`continue`、`throw` 遇到换行、`}` 或 EOF 必须插入分号：

```javascript
function foo() {
  return;
  42; // => return; 42;
}
```

## 核心数据结构

- `g_last_token`：记录上一个提交给 Bison 的 token，判断其是否可结束语句。
- `g_last_token_closed_control`：指示最近一次 `)` 是否对应控制语句头（`if`/`for`/`while`/`with`/`switch`），避免 `if (true)
console.log(1)` 被错误拆分。
- `g_paren_depth` 与 `g_control_stack[]`：追踪括号深度以及控制语句的条件范围。
- `g_pending`：保存“真实”下一个 token；在注入虚拟分号后，延迟返回原 token 以维持顺序。

## 处理流程

1. `parser_lex_adapter.c` 调用 `lexer_next_token` 获取新 token，并读取 `lexer->has_newline`。
2. 若需插入分号，先缓存当前 token 到 `g_pending`，立即返回 `';'` 给 Bison。
3. 下一次 `yylex()` 调用会优先返回 `g_pending` 中保存的 token。
4. 在 `update_token_state()` 中同步括号深度与控制语句状态，保证后续判断准确。

## 可结束语句的 token

以下 token 被视为可以结束语句：标识符、字面量（包含 `true/false/null/undefined`）、右括号 `)` / `]` / `}`，以及后缀 `++` / `--`。

## 关键函数

```c
static bool should_insert_semicolon(int last_token,
                                    bool last_closed_control,
                                    int next_token,
                                    bool newline_before,
                                    bool is_eof);
```

- `last_closed_control` 为 `true` 时禁止插入（对应 `if (...)` 等控制语句头）。
- `suppress_newline_insertion()` 对 `(`、`[`、`.` 做特殊处理，防止 `obj
.prop` 被误拆。

## 典型测试用例

| 文件                        | 场景                 | 预期         | 备注             |
| --------------------------- | -------------------- | ------------ | ---------------- |
| `test/test_asi_basic.js`   | `a` 换行 `++b`       | 分号自动插入 | 也覆盖链式语句   |
| `test/test_asi_return.js`  | `return` 换行        | `return;`    | 验证受限产生式   |
| `test/test_asi_control.js` | `if (true)` 单行语句 | 不误插分号   | 校验控制语句保护 |

## 常见扩展需求

- **新增关键字**：务必在 `parser_lex_adapter.c` 的 `is_control_keyword()` 与 `can_end_statement()` 中同步更新。
- **新增语句**：若语法允许隐式分号（如未来的 `yield`），请将其加入 `is_restricted_token()`。
- **调试建议**：
  - 在 `should_insert_semicolon()` 内部加入日志可观察决策。
  - 使用 `js_parser.exe` 对照 V8/Node.js 行为验证边界情况。

## 未覆盖的边界

- 当前未实现 for/while 循环头中的 ASI 复杂场景（例如 `for (a
in b)`），后续若支持需补充测试。
- 正则字面量、模板字符串等 ES6+ 特性会引入更多上下文分析，这部分留待未来迭代。

---

**最后更新**：2025-11-10
