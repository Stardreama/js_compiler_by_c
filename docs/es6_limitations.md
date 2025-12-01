# ES6 语法支持现状说明（2025-12-01）

本文用于同步“已经实现的 ES2015 语法”与“仍待补齐的特性”。如遇到解析失败，可先确认是否属于“尚未支持”范畴，再决定是提 issue 还是继续扩展语法。

## 已覆盖能力快照

1. **Binding Pattern / 解构赋值**

   - 变量声明、函数/箭头形参、`catch`、`for-in/for-of` 头部以及普通赋值表达式均支持对象/数组解构、默认值与 `...rest`。
   - 对应测试：`test/es6_stage1/*.js`。

2. **参数系统与箭头函数**

   - `param_list` 与 `arrow_function` 共用 `binding_element`，支持解构 + 默认值 + `...rest`；`ARROW_HEAD` 前瞻解决了 `()=>{}` 的语法冲突。
   - 受限换行规则（`=>` 前不可换行）已在适配层实现。

3. **模板字符串与 Tagged Template**

   - 词法状态机可区分 `TEMPLATE_HEAD/MIDDLE/TAIL`，语法会构建 `AST_TEMPLATE_LITERAL` 与 `AST_TAGGED_TEMPLATE`。
   - 测试：`test/es6_stage3/*.js`。

4. **类与增强对象字面量**

   - `class` 声明/表达式、`extends`、`super`、静态/实例方法、`get/set`、对象字面量中的方法简写与计算属性均可解析。
   - 测试：`test/es6_stage4/*.js`。

5. **迭代协议（M5）**
   - `for-of` 语句、`function*`/`yield`/`yield*`、数组与调用上下文中的 `...spread`、rest 形参已落地；`yield` 也加入 ASI 受限 token。
   - 新增 AST：`AST_FOR_OF_STMT`、`AST_YIELD_EXPR`、`AST_SPREAD_ELEMENT`。
   - 测试：`test/es6_stage5/{for_of.js,generators.js,spread_rest.js}`。

## 仍待补齐的语法

- **对象字面量 spread / rest 属性**：`{ ...foo }`、`const { a, ...rest } = obj;` 的前者尚未实现。
- **模块与顶层语法**：`import` / `export` / `export default` / `export *` 未建模；`parser_main` 仍按 Script 模式工作。
- **Async / Await / Async Generator**：`async function`、`await`、`for-await-of`、`async function*` 均未支持。
- **新表达式**：`new.target`、`import()`、`super()` 以外的属性写入（如 `super.foo = 1`）仍缺乏覆盖。
- **可选链、空值合并等 ES2020+ 特性**：`?.`、`??`、`??=` 等语法未纳入规划。
- **语义约束**：当前实现仅保证语法层面通过，未对 `yield` 的上下文、重复声明、`Symbol.iterator` 协议等进行校验。

如在 `goodjs` 样例中遇到上述尚未实现的语法，可在 `docs/todo.md` 中登记具体文件与失败原因，或在 `tmp/` 下创建最小复现以便后续迭代。

## 调试与回归建议

- 执行 `make test ./test/es6_stageX`（X=1~5）可快速确认对应阶段是否回归通过。
- 对压缩代码，可使用 `node --check file.js` 先确认源文件本身合法，再与 `js_parser.exe` 的错误位置对照。
- 若 `build/parser_error_locations.log` 中同一语法连续失败，请在 `docs/todo.md` 中标注所属里程碑，避免重复排查。
