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

1. **受限产生式**：`return`、`break`、`continue`、`throw`、`yield` 遇到换行、`}` 或 EOF 必须插入分号：

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

| 文件                       | 场景                 | 预期         | 备注             |
| -------------------------- | -------------------- | ------------ | ---------------- |
| `test/test_asi_basic.js`   | `a` 换行 `++b`       | 分号自动插入 | 也覆盖链式语句   |
| `test/test_asi_return.js`  | `return` 换行        | `return;`    | 验证受限产生式   |
| `test/test_asi_control.js` | `if (true)` 单行语句 | 不误插分号   | 校验控制语句保护 |

## 常见扩展需求

- **新增关键字**：务必在 `parser_lex_adapter.c` 的 `is_control_keyword()` 与 `can_end_statement()` 中同步更新。
- **新增语句**：若语法允许隐式分号（例如现已支持的 `yield`），请及时把 token 加入 `is_restricted_token()`。
- **调试建议**：
  - 在 `should_insert_semicolon()` 内部加入日志可观察决策。
  - 使用 `js_parser.exe` 对照 V8/Node.js 行为验证边界情况。

## 未覆盖的边界

- 当前未实现 for/while 循环头中的 ASI 复杂场景（例如 `for (a
in b)`），后续若支持需补充测试。
- 正则字面量、模板字符串等 ES6+ 特性会引入更多上下文分析，这部分留待未来迭代。

## 2025-11-11 修复记录

- `test/JavaScript_Datasets/badjs/c262a89b9308208a2296a22303c06b84` 暴露了一个缺陷：内联函数体中的语句若未写分号且 `}` 后紧跟 `)`，`should_insert_semicolon()` 会因为把函数体括号视为“非 block”而拒绝插入分号，导致解析报 `unexpected '}'`。
- 解决方案：在 `parser_lex_adapter.c` 中允许 `BRACE_FUNCTION`（以及普通 `BRACE_BLOCK`）触发 ASI，而保留 `BRACE_OBJECT` 的抑制逻辑，防止对象字面量误拆。

## 2025-12-01 修复记录

- `test/JavaScript_Datasets/1kbjs/20170223_bf0d33845db834a400d0e4b9e56ee02a` 中的 `try { ... } catch (e) {}` 语句在 `catch` 头与 `{` 之间存在换行，导致适配层在 `)` 之后插入了多余分号，从而报 `unexpected ';', expecting '{'`。
- 解决方案：把 `CATCH` 视作控制语句关键字，进入括号时压入控制栈，这样 `)` 会设置 `g_last_token_closed_control = true`，ASI 就不会在 `catch` 头与块之间插入分号。
- `test/JavaScript_Datasets/1kbjs/20170323_05a3cc924d4c8c0699f8d72342482e51` 的 `WScript.CreateObject(...)` 调用把实参分多行书写，`zx.toUpperCase()` 结束后紧接换行再出现 `)`，适配层错误地在该换行处插入分号，导致 `unexpected ';', expecting ')'`。
- 解决方案：把 `')'` 纳入 `suppress_newline_insertion()`，在括号内部遇到换行再闭合 `)` 时不会触发 ASI，合法的多行调用/条件表达式即可正常解析。
- `test/JavaScript_Datasets/1kbjs/343a86f7478055585a263256fa1d61c1` 末尾的 `document.getElementById(...).onclick = function(){ ... }` 依赖 EOF 处的 ASI 来补分号，但我们为了支持 `function(){ }()` 这类 IIFE，曾经在所有函数体闭合后直接禁止 ASI，导致语句被解析器要求显式 `;`，报 `unexpected end of file, expecting ';' or ','`。
- 解决方案：仅当函数体闭合后紧跟 `(`、`[`、`.` 或 `{`（即继续调用/访问或即将出现函数体）时才禁止 ASI；面对 EOF 或其他 token 时允许 ASI，从而既保留 IIFE 行为又能在文件末尾补分号。
- Generator 特性引入后，`yield` 也必须遵循“受限产生式”规则，否则 `yield\nvalue` 会被误判为合法表达式。
- 解决方案：在 `is_restricted_token()` 中加入 `YIELD`，并复用现有逻辑在 `yield` 与换行/`}`/EOF 相遇时主动回放 `';'`。

## 2025-12-03 修复记录

- `test/JavaScript_Datasets/1kbjs/960b1ba66cd62048f5a7553ad1b1260a` 以及 `tmp/repro_new_iife.js` 复现了 `new Foo()` 后换行紧跟 `(function(){ ... }())` 的模式。适配层把所有前瞻到 `(` 的换行都判定为“安全”，从而抑制了 ASI，Bison 继续把 `(` 视作调用结果，最终报 `syntax is ambiguous`。
- 解决方案：在 `should_insert_semicolon()` 调用链中使用 `paren_starts_function_literal()` 判断该 `(` 是否引入 IIFE。若是 `(function ...` 开头，则既允许 ASI 插入分号，也阻止 `suppress_newline_insertion()` 抑制该换行，从而把 `new` 表达式正确结束成独立语句。

## 2025-12-02 修复记录

- `test/JavaScript_Datasets/3kbjs/11071667787002.163551`（与 `test/1.js` 语义相同但移除了显式分号）在 `function o(e){ return n.call(this,e) || this }` 处触发 `unexpected '}', expecting ';'`。原因是 ASI 的 `can_end_statement()` 把 `this`/`super` 视作“不可结束语句”的 token，导致在 `}` 前拒绝插入分号。
- 该缺陷也可以通过最小 repro `function outer(){function o(e){return n.call(this,e)||this}t.Team=1;}` 复现。
- 修复：在 `parser_lex_adapter.c` 的 `can_end_statement()` 中补充 `THIS` / `SUPER`，让 `return ... || this`、`return super.foo` 等语句在缺少显式分号时依旧满足 ASI 条件，从而与真实 JS 引擎保持一致。

---

**最后更新**：2025-12-03
