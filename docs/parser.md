# JavaScript 语法解析（基础子集）说明

本文件描述当前项目已实现的“语法检测”（基于 Bison）能力、覆盖范围、歧义消解策略、错误信息形式，以及在 Windows/MSYS2 下的构建与使用方法。

> 目标定位：语法正确性校验（Syntax Check）。当前版本不生成 AST，不执行语义/风格检查（例如 `return + b` 在语法上合法，因此不会报错）。

---

## 1. 覆盖范围（已实现）

语句（Statements）：

- 空语句：`;`
- 变量声明：`var | let | const` 单个声明，支持可选初始化（如 `let x = 1;`）
- 表达式语句（Expression Statement）
- 块语句（Block）：`{ ... }`
- 条件语句：`if (...) stmt`、`if (...) stmt else stmt`
- for（经典三段式）：`for (init; test; update) stmt`
- 函数声明：`function foo(a, b) { ... }`

表达式（Expressions）：

- 成员访问与函数调用：`obj.prop`、`fn(a, b)`
- 一元运算：`+x`、`-x`、`!x`、`~x`
- 乘法/加法：`* / %`、`+ -`
- 关系/相等：`< > <= >=`、`== != === !==`
- 逻辑：`&& ||`
- 赋值（基础）：`lhs = expr`
- 括号分组：`( expr )`
- 字面量：`NUMBER`、`STRING`、`IDENTIFIER`
- 数组字面量：`[a, b, c]`（支持尾随逗号）
- 对象字面量：`{ key: value, ... }`（支持尾随逗号；键可为标识符或字符串）

> 注：上述能力足以解析 `test/test_basic.js`，并能对常见语法错误（漏冒号/括号/逗号/分号等）给出明确报错。

---

## 2. 关键歧义与消解

- 块 `{ ... }` vs 对象字面量 `{ ... }`：
  - 在“表达式语句”的位置，禁止以 `{` 开头的表达式（引入 `expr_no_obj` 变体）。
  - 因此：
    - `if (cond) { ... }` 中的 `{` 一定被解析为块。
    - 而赋值等表达式环境中仍允许对象字面量：`let x = { a: 1 }`。

---

## 3. 操作符优先级与结合性（摘录）

从低到高（同一行内左 → 右为结合性）：

- `=`（右结合）
- `||`
- `&&`
- `== != === !==`
- `< > <= >=`
- `+ -`
- `* / %`
- 一元：`+ - ! ~`（右结合，`UMINUS` 用于区分一元 -）

---

## 4. 错误信息与示例

已启用 Bison 详细错误信息（`%define parse.error verbose`）。典型报错形式：

- `Syntax error: syntax error, unexpected STRING, expecting ':'`
- `Syntax error: syntax error, unexpected ';', expecting ')'`
- `Syntax error: syntax error, unexpected NUMBER, expecting ',' or ']'`

示例（来源：`test/test_error_cases.js`，一次只激活一个 CASE）：

- 对象属性缺少冒号：`{ name "test" }` → 期待 `:`
- 函数调用漏右括号：`console.log("hi";` → 期待 `)`
- 数组缺逗号：`[1, 2 3]` → 期待 `,` 或 `]`
- for 头部缺分号：`for (var i = 0 i < 5; i++)` → 期待 `;`
- 省略分号（当前未实现 ASI）：`var x = 10` → 报错

> 提示：`return + b;` 在语法上合法（一元 `+`），不会报错；这类“可疑但合法”的情况属于语义/风格层面，后续可在 AST 基础上做静态分析再报告。

---

## 5. 构建与运行

MSYS2（推荐使用 “MSYS2 MinGW 64-bit” 终端）：

- 构建解析器：

```bash
cd /d/EduLibrary/OurEDA/js_compiler_by_c
make parser
```

- 检测样例：

```bash
./js_parser.exe ./test/test_basic.js
# 预期：Parsing successful!
```

- 检测错误用例（仅激活一个 CASE）：

```bash
./js_parser.exe ./test/test_error_cases.js
# 预期：Syntax error: ...
```

PowerShell（可选）：

```powershell
cd d:\EduLibrary\OurEDA\js_compiler_by_c
.\build.bat parser
.\js_parser.exe .\tests\test_basic.js
```

---

## 6. 工程文件概览

- `parser.y`：语法定义（Bison）。包含语句/表达式/数组/对象等产生式；在表达式语句位置使用 `expr_no_obj` 解决 `{` 歧义。
- `parser_lex_adapter.c`：词法到语法的适配层。把 `token.h` 的 `TOK_*` 映射为 Bison 终结符；分隔符直接返回字符（如 `'('`、`')'` 等）。
- `parser_main.c`：解析器入口程序（读取文件 → `yyparse()`），仅做“语法是否通过”的判断。
- `Makefile`：
  - `make parser` 生成 `parser.c/parser.h` 并编译 `js_parser.exe`
  - `make test-parse` 运行解析器对样例文件进行检测
- `test/test_basic.js`：语法正确的样例。
- `test/test_error_cases.js`：常见语法错误集合（一次只激活一个用例）。

> 若编辑器提示找不到 `parser.h`，先执行一次 `make parser` 生成。

---

## 7. 当前限制与后续计划

- 未实现 ASI（自动分号插入）：当前分号必须显式书写。
- 未生成 AST：后续可在语义动作中构建节点，并提供打印/检查能力。
- 覆盖子集：尚未包含 `?:` 条件表达式、完整赋值/位移/位运算优先级、更丰富语句（`while`/`do-while`/`switch` 等）、正则/模板字面量、类/模块、箭头函数、解构等。
- 错误恢复：当前遇到错误直接终止；后续可加入同步/恢复与更精确的位置信息。

路线建议：

1. 工程实用性优先：先实现 AST 与 ASI（`return/break/continue/throw`、行终止、输入末尾等），并增加静态检查；
2. 语法完备度优先：扩展表达式与语句集合，逐步覆盖更多 ES 语法特性。

---

## 8. 附：与词法（`lex.md`）的分工

- 词法（`js_lexer.exe`）：负责把源码切分为 Token；遇到非法字符/未闭合字符串时报“Lexical Error”，可输出 Token 列表调试。
- 语法（`js_parser.exe`）：在 Token 基础上进行结构化规则匹配；遇到结构不合法时报 “Syntax error: … unexpected …, expecting …”。

两者独立构建、互不影响，建议在定位语法问题时先确认词法输出是否符合预期。

---

## 9. Binding Pattern 支持概览（2025-12 更新）

- **新增 AST 节点**：`AST_BINDING_PATTERN`、`AST_OBJECT_BINDING`、`AST_ARRAY_BINDING`、`AST_BINDING_PROPERTY`、`AST_REST_ELEMENT`、`AST_ARRAY_HOLE`，配套 `ast_make_* / ast_print / ast_free` 均已实现，可通过 `js_parser.exe --dump-ast ...` 观察树结构。
- **语法覆盖**：
  - 变量声明：`var/let/const { a: x = 1, ...rest } = expr;`
  - 函数/箭头形参：`function f({ x, y = 1 }, [head, ...tail]) {}`、`({ value }) => value`。
  - `catch` 绑定：`catch ({ message, info: { code = 0 } }) {}`。
  - `for-in` 头部：`for (const { key } in source) { ... }`、`for (let [entry] in dict) { ... }`。
- **赋值表达式**：`assignment_expr` / `assignment_expr_no_obj` 现在通过 `assignment_target( _no_obj )` 自动识别对象/数组左值，并在构造 AST 时将其包裹成 `AST_BINDING_PATTERN`，因此 `({ foo: target.name, bar = 2 } = payload)`、`[items.first, items.second = 10] = source`、`[first, ...rest] = payload` 这类语句可以直接作为表达式使用。
- **词法/ASI 调整**：词法器提供 `TOK_ELLIPSIS`，适配层在 `...`、`{`、`}` 场景下维护 brace stack，避免在解构上下文中误插分号。
- **测试套件**：`make test test/es6_stage1` 当前运行 `catch_binding.js`、`destructuring_for_in.js`、`destructuring_params.js`、`destructuring_var.js` 以及新增的 `destructuring_assign.js`，即可覆盖声明、循环、函数参数与赋值四类场景；必要时可使用 `build/parser_error_locations.log` 查看失败定位。
- **已知限制**：解构赋值表达式（`({a} = expr)`、`[a] = expr`）仍未实现；对应文件目前保持 `test_error_*` 命名以提醒该语法尚未开放。

## 10. Arrow Function 与参数系统更新（2025-12 更新）

- **统一的形参语义**：函数声明/表达式与箭头函数的 `param_list` 现基于 `binding_element`，支持解构、默认值，以及末尾 `...rest` 形参；AST 中的参数列表维持与 M1 相同的数据结构。
- **新增 `AST_ARROW_FUNCTION`**：语义动作会构建独立节点，并记录 `is_expression_body`，便于后续生成器/async 扩展或做 `this`/`arguments` 差异化分析。
- **LineTerminator 规则**：当 `=>` 之前出现换行时，适配层会阻止 ASI 插入并调用 `yyerror`，与 ECMAScript “no LineTerminator here” 要求一致；`test/es6_stage2/test_error_arrow_newline.js` 用于回归该场景。
- **测试覆盖**：`test/es6_stage2/arrow_functions.js`, `arrow_expression_contexts.js`, `function_params_variants.js` 验证默认值、rest、解构、表达式/块体、调用上下文等正向场景，`test/es6_stage2/test_error_arrow_newline.js` 与 `test_error_arrow_rest_position.js` 回归受限的换行与 rest 位置错误，可通过 `make test test/es6_stage2` 复现。
- **ARROW_HEAD 前瞻**：适配层在读取到 `(` 后会向前匹配，若该括号组的匹配 `)` 紧跟 `=>`，则先回放一个虚拟 token `ARROW_HEAD`。语法只在看到该 token 时才进入 `ARROW_HEAD '(' opt_param_list ')' ARROW ...` 产出，从而避免与普通 `(' expr ')` 表达式产生冲突。
- **FUNCTION_DECL 令牌**：词法适配层会在“语句起始位置”（文件开头、`}`/`;`/`else`/`case` 之后、或 `if/while/for` 条件闭合后）把 `function` 重写为 `FUNCTION_DECL`，语法仅允许它归约为 `func_decl`。其余位置（如 `var fn = function () {}`）仍然返回普通 `FUNCTION`，以便继续作为表达式使用。此举可避免 GLR 在“函数声明 vs 函数表达式语句”之间产生歧义。

## 11. `new` 表达式与调用链结合（2025-12 更新）

- **新的层次结构**：`parser.y` 引入 `member_expr` / `call_expr` / `left_hand_side_expr` 三段式产生式，遵循 ECMAScript 的 `MemberExpression` / `CallExpression` 设计。`new Foo(bar)`、`new Foo.bar()`、`new Foo().bar` 等组合都能在该结构下按优先级解析。
- **避免 GLR 歧义**：旧版 `new_expr : NEW unary_expr` 会在 `new Image().src` 这类语句上产生二义性。现在 `new` 直接归入 `member_expr`，并允许在其外层继续附加 `.`、`[]`、`()`，GLR 不再产生多个解析分支，测试 `test/JavaScript_Datasets/goodjs/eb8511178bbe1d5132aa2504c710c666` 已通过。
- **AST 一致性**：无论 `.` / `[]` / `()` 出现在 `new` 之前还是之后，都会调用同一套 `ast_make_member` / `ast_make_call` / `ast_make_new_expr`，因此 `--dump-ast` 输出与旧实现保持兼容，同时补足了 previously missing 的 `(new C()).prop` 用例。

## 12. 类与增强对象字面量（2025-12 更新）

- **语法覆盖**：`class` 声明/表达式现已支持，可选 `extends` 继承、实例方法、`static` 静态方法以及 `get/set` 访问器。类体中的 `;` 被视为空元素，不会生成 AST 节点。
- **AST 节点**：`AST_CLASS_DECL/EXPR`、`AST_METHOD_DEF`、`AST_SUPER`、`AST_COMPUTED_PROP` 全量启用。语法动作会在必要时调用 `maybe_tag_constructor`/`mark_method_static`，确保 `constructor` 仅在非静态方法上标记为构造器，静态 getter/setter 则保留 `static` 标记。
- **对象字面量增强**：`prop` 规则支持方法速记（含生成器）、访问器以及计算属性键（`[{expr}]: value`）。AST 使用 `AST_METHOD_DEF` 直接记录这些成员，可在 `--dump-ast` 中看到同类结构。
- **测试**：新增 `test/es6_stage4/class_basic.js`、`class_inheritance.js`、`object_literal_enhancement.js`，可通过 `make test test/es6_stage4` 或 `build.bat test test\es6_stage4` 运行，覆盖静态成员、`super` 调用、计算属性键及访问器。
- **适配层**：类体被视为 `BRACE_BLOCK`，维持此前的 ASI 行为；访问器/方法的新增语法仅在 `parser.y` 层处理，词法无需改动。
- **回归/待办**：`make test ./test/es6_stage4` 于 2025-12-01 通过；`test/JavaScript_Datasets/goodjs` 仍包含 `for-of`、`async`、`decorator` 等未在 M4 范畴内的失败。进入 M5 之前，需要：① 在 `docs/es6_limitations.md` 标记剩余语法空缺；② 为常见的类/对象模式新增精简 repro；③ 将 `build/test_failures.log` 中与类相关的样例打标签，确认是否由 M4 语义造成，以免把下一阶段问题混淆。

## 13. 函数表达式括号歧义（2025-12-01）

- 问题来源：`test/JavaScript_Datasets/1kbjs/04b34bf323b7d469b0416d861cc0bf62039ac870` 中的 IIFE `(function(){ ... })();` 触发 GLR “Ambiguity detected”。`primary_expr` / `primary_no_obj` 同时拥有 `'( expr )'` 与 `'( function_expr )'` 两条产生式，而 `expr` 自身又可以归约为 `function_expr`，因此 Bison 看到括号包裹的 `function` 时会分裂为“分组表达式”与“直接函数表达式”两个解析分支。
- 解决方案：移除两份语法中的 `'( function_expr )'` 规则，仅保留通用的 `'( expr )'`，语义不变但可避免额外分支。两份 `parser.y`（根目录与 `src/` 下的源副本）需同步修改后重新生成解析器。
- 验证：重新运行 `make test ./test/JavaScript_Datasets/1kbjs/04b34bf323b7d469b0416d861cc0bf62039ac870`，测试通过且不再出现歧义日志。

## 14. `expr_no_obj` 中的 `new` 调用链歧义（2025-12-03）

- 症状：`test/JavaScript_Datasets/1kbjs/960b1ba66cd62048f5a7553ad1b1260a` 以及最小复现 `tmp/repro_new_iife.js` 在解析 `new Foo()`（无显式 `;`）时触发 “syntax is ambiguous”。原因是 `_no_obj` 变体里只有 `member_expr_no_obj` 与 `call_expr_no_obj`，缺少 `call_member_expr_no_obj` 这一层，GLR 会同时尝试把 `()` 当作 `new` 的实参或额外的函数调用。
- 解决方案：与主语法保持一致，新增 `call_member_expr_no_obj`，并让 `call_expr_no_obj` 从它开始构造调用链。这样 `new Foo()` 的括号只会归属于 `new` 产生式，除非后续再出现额外的 `()`，从而消除了歧义。根目录与 `src/` 下的 `parser.y` 同步更新后重新运行 `make parser` 即可。
- 结果：`make test tmp/repro_new_iife.js` 与 `make test ./test/JavaScript_Datasets/1kbjs/960b1ba66cd62048f5a7553ad1b1260a` 现均通过，且 GLR log 不再产生 `Ambiguity detected`。

## 15. 迭代协议与 `yield/spread`（2025-12-01）

- **词法与适配层**：`lexer.re` 将 `...` 解析为 `TOK_ELLIPSIS`，`yield` 解析为 `TOK_YIELD`；`parser_lex_adapter.c` 在 `convert_token_type()` 中完成映射，并把 `yield` 纳入 `is_restricted_token()`，避免 `yield\nvalue` 被错误拆分。
- **语法**：`parser.y` 新增 `for_of_keyword`、`spread_element`、`yield_expr` 等产生式，`for_stmt` 允许 `for (binding of iterable)`，数组字面量和调用实参都可以混合 `assignment_expr` 与 `spread_element`。函数/方法声明新增 `generator_marker_opt` 以匹配 `function*`，`arrow_function`、`assignment_expr` 的 `_no_in`/`_no_obj` 版本也同步补强。
- **AST**：加入 `AST_FOR_OF_STMT`、`AST_YIELD_EXPR`、`AST_SPREAD_ELEMENT` 节点，`function_decl`/`function_expr` 的 `is_generator` 标记会在 `function*` 或 `*method()` 时被置位；`ast_traverse`、`ast_print`、`ast_free` 均已更新。
- **测试套件**：`test/es6_stage5/for_of.js`、`generators.js`、`spread_rest.js`、`for_of_bindings.js`、`generator_methods.js`、`spread_calls.js` 以及负例 `test_error_yield_newline.js`、`test_error_for_of_initializer.js` 覆盖 for-of 绑定模式、`yield*`/`finally`、类与对象生成器方法、调用/箭头中的 spread 组合与对应错误分支。执行 `make test ./test/es6_stage5` 可验证该阶段能力。
- **当前限制**：尚未实现对象字面量 spread（`{ ...obj }`）、`for-await-of`、`async function*`、`yield` 在严格模式下的语义校验等高级特性；仍主要关注语法层面的可解析性。

## 16. 表达式语句中的 `in` 运算符（2025-12-05）

- `test/1.js` 与 `test/JavaScript_Datasets/3kbjs/21231667792110.278031` 使用了 `try { "localStorage" in window && ...; }` 这样的表达式语句，解析时却在 `in` 处报 `unexpected IN, expecting ';' or ','`。
- 根因：表达式语句强制使用 `expr_no_obj` 以区分 `{}` 块与对象字面量，但我们忘记在 `relational_expr_no_obj` 中加入 `in` 分支（只有 `<`、`>`、`<=`、`>=`、`instanceof`）。因此一旦语句以字面量/标识符开头并出现 `in`，解析器会误认为仍在变量声明上下文。
- 修复：为 `relational_expr_no_obj` 增加 `| relational_expr_no_obj IN shift_expr_no_obj`，并保持 `*_no_in` 族不允许 `in`，以免影响 `for (var x = expr; ...)` 和 `for-in` 之间的判定。现在表达式语句可以直接写 `"foo" in obj`, `key in dict && ...`，无需额外括号。
