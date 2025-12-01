# JavaScript 编译器 ES6 拓展路线图

> **最后更新**: 2025 年 11 月 30 日  
> **目标**: 在现有 ES5 正确性的基础上，逐步补齐 ES6/ES2015 关键语法，使 `test/JavaScript_Datasets` 中的现代样例能够通过解析。

---

## 0. 当前能力与约束

- 词法与语法仍以 ES5 子集为准：不支持解构、模板字符串、类、模块等高级语法；`docs/es6_limitations.md` 已列出现状。
- `parser_lex_adapter.c` 的 ASI 与括号/控制栈设计假设“形参 = 标识符”；扩展时需重新审视触发行列及 `g_brace_stack` 行为。
- AST (`ast.h/.c`) 仅覆盖传统语法，尚无 `BindingPattern`、`ClassDeclaration`、`TemplateLiteral`、`Import/Export` 等节点类型。
- 测试框架依赖 `make test path/to/files`；需要通过新增“语法特性分组”来回归（例如 `test/es6_destructuring/*.js`）。

---

## 1. 设计原则

1. **对齐规范**：参照 ECMA-262 第 6 版（2015）章节顺序扩展，不盲目跳跃，确保每个里程碑有完整语法+AST+测试+文档。
2. **最小破坏**：尽量在适配层/AST 中引入 feature flag 或能力探针，避免一次性重写全部语法；必要时保持 ES5 行为默认开启。
3. **成对迭代**：凡是 lexer 新 token → parser 规则 → AST 节点 → `--dump-ast` → 测试数据，必须一次完成，防止“半成品”污染主干。
4. **回归优先**：每个里程碑须新增针对性的 `goodjs` 抽样 + 手写用例，以便定位 regressions。

---

## 2. 里程碑导航

| 编号 | 主题               | 主要语法                              | 关键文件                                            |
| ---- | ------------------ | ------------------------------------- | --------------------------------------------------- |
| M0   | 基础加固           | re2c/bison 警告、测试分组、诊断       | `lexer.re`, `Makefile`, `docs/error_diagnostics.md` |
| M1   | Binding Pattern    | 解构、默认值、rest                    | `parser.y`, `ast.[ch]`, `parser_lex_adapter.c`      |
| M2   | 参数系统与箭头函数 | 完整箭头函数、函数默认值、rest 形参   | 同上                                                |
| M3   | 模板字符串         | TemplateLiteral、Tagged Template      | `lexer.re`, `ast.[ch]`, `parser.y`                  |
| M4   | 类与增强对象字面量 | class、extends、super、计算属性       | `parser.y`, `ast.[ch]`, `docs/parser.md`            |
| M5   | 迭代协议扩展       | for-of、Spread/Rest、Generator、yield | `lexer.re`, `parser.y`, `ast.[ch]`                  |
| M6   | 模块与顶层 await   | import/export、default、命名空间      | `parser.y`, `ast.[ch]`, `parser_main.c`             |

以下章节详细拆解各里程碑。

---

## M0. 基础加固（准备阶段）

1. **工具告警清理**

- 处理 `lexer.re` sentinel 警告，显式配置 `re2c:sentinel = 0`，确保新增状态机时无噪音。
- 在 `parser.y` 中使用 `%expect` 锁定当前冲突数，以免 ES6 扩展时误引入新的 S/R 冲突而不自知。

2. **诊断与日志**

- 扩展 `diagnostics.c`，记录 token 文本与上下文片段，为复杂结构（模板字面量、类体）调试提供依据。
- 在 `docs/error_diagnostics.md` 中新增“如何定位 ES6 失败”的流程（利用 feature gate + 日志）。

3. **测试分层**

- 新增 `test/es5_baseline/` 与 `test/es6_stageX/` 目录，并调整 Makefile 允许 `make test target=es6_stage1` 形式分批执行。

> ✅ 完成后再切入后续特性，避免“地基不稳”。

---

## M1. Binding Pattern & 解构赋值

**目标**: 支持对象/数组解构、默认值和 `rest` 绑定，覆盖变量声明、赋值表达式、`for-in/of` 头部、函数形参。

任务拆解：

1. **AST 设计**

- [x] 新增 `AST_BINDING_PATTERN`, `AST_OBJECT_BINDING`, `AST_ARRAY_BINDING`, `AST_BINDING_PROPERTY`, `AST_REST_ELEMENT`, `AST_ARRAY_HOLE` 节点。
- [x] 更新 `ast_print/ast_free`，确保递归结构无泄漏，支持 `--dump-ast`。

2. **语法扩展**

- [x] `var_decl`、函数/箭头形参、`catch_clause`、`for_in_left` 接入 `binding_element`。
- [x] `lexer.re`/`parser_lex_adapter.c` 支持 `...` 并维护 brace stack，避免 ASI 误触发。
- [x] `assignment_expr` 的解构赋值：`assignment_target( _no_obj )` 现在会在遇到对象/数组左值时自动转换为 `AST_BINDING_PATTERN`，`test/es6_stage1/destructuring_assign.js` 负责覆盖 `( { foo: target.name, bar = 2 } = payload )`、`[first, ...rest] = array` 等场景。

3. **测试/回归**

- [x] `test/es6_stage1/{destructuring_var,destructuring_params,catch_binding,destructuring_for_in,destructuring_assign}.js` 作为正向用例。
- [ ] 补充 `goodjs` 抽样与更复杂的嵌套 for-in/of 场景。

---

## M2. 参数系统 & 箭头函数增强

**目标**: 支持所有 ES6 形参语法，以及表达式体/块体箭头函数、隐式 return、`this` 绑定差异。

任务拆解：

1. **词法**

- [x] 确认 `=>` token 在压缩代码中不会被 ASI 误切分；必要时在 `lexer.re` 中增加 `lookahead` 处理。

2. **语法/AST**

- [x] `arrow_function` 允许 `binding_element` 参数列表与单参数解构形式。
- [x] 函数声明/表达式形参列表加入 `param_initializer`、`rest_param` 语义动作。
- [x] 在 AST 中区分 `AST_ARROW_FUNCTION` 与普通函数，记录 `is_expression_body` 以便后续生成器/async 扩展。

3. **ASI 调整**

- [x] 当 `=>` 前存在换行时，需要参照规范（LineTerminator 不能出现在 `=>` 前）。适配层需阻止在 `)`→`=>` 之间插入分号。

4. **测试**

- [x] `test/es6_stage2/arrow_functions.js`：覆盖单参数省略括号、解构参数、默认值、rest、嵌套箭头。
- [x] 负例：`(a\n)=>{}` 应报错以符合规范。

> ✅ **进展更新（2025-12-01）**：通过 `ARROW_HEAD` 预读与 `binding_element` 统一形参与 AST 结构，`test/es6_stage1/destructuring_params.js`、`test/es6_stage1/destructuring_assign.js`、`test/es6_stage2/arrow_functions.js` 全部通过；`test/es6_stage2/test_error_arrow_newline.js` 继续验证 LineTerminator 受限规则。对象字面量简写属性、`({ value, rest }) => ...` 等 cover 语法在 GLR 模式下稳定归约。

> 🔧 **新增粒度控制**：`parser.y` 现采用 `member_expr/call_expr/left_hand_side_expr` 三段式建模 `new`，成功解析 `new Image().src = ...`、`new Foo(bar).baz()` 等调用链；`assignment_target( _no_obj )` 则在直观的 `=` 左值上套用了相同的 cover 逻辑。

> 📌 **未完事项**：后续扩展（例如 `for-of`、`yield`、`spread`、`new.target`、`import()`）仍待 M5+/M6 处理；`goodjs` 样例中的剩余失败需要在完成模板字符串、类、模块等特性后再清理。

---

## M3. 模板字符串与 Tagged Template

**目标**: 让 `TEMPLATE_HEAD/MIDDLE/TAIL` token 形成完整 `TemplateLiteral`/`TemplateElement` AST，并支持 `tag` 调用链。

任务拆解：

1. **lexer.re**

- 引入模板字面量状态机，跟踪 `${` 嵌套层级，与现有 `in_template_expression` 字段合并。
- 允许 Unicode 转义与行内换行，不再把反引号内容拆成多行 token。

2. **parser.y/AST**

- 新增 `template_literal` 规则，返回 `AST_TEMPLATE_LITERAL`（含 `quasis` 与 `expressions` 列表）。
- 支持 `tag template_literal` 组合生成 `AST_TAGGED_TEMPLATE`。

3. **适配层**

- 在模板插值结束 `}` → `` ` `` 之间，禁止自动插分号；需要额外的状态位标识“模板字面量上下文”。

4. **测试**

- `test/es6_stage3/template_basic.js`, `template_tagged.js`, `template_asi.js` 等。

> ✅ **进展更新（2025-12-02）**：`ast.[ch]` 与 `parser.y` 已实现 `AST_TEMPLATE_LITERAL`/`AST_TAGGED_TEMPLATE` 节点，并复用 `member_expr`/`call_expr` 支持 tagged templates。新回归用例位于 `test/es6_stage3/template_basic.js` 与 `test/es6_stage3/template_tagged.js`，覆盖插值、嵌套字符串及调用表达式为 tag 的场景。

---

## M4. 类、增强对象字面量与 super

**目标**: 覆盖 `class` 声明/表达式、`extends`、构造器、方法定义、静态属性、`super` 调用，以及对象字面量中的简写/计算属性。

任务拆解：

1. **lexer.re**

- 添加关键字 `class`, `extends`, `super`，并确保保留字集合同步更新。

2. **AST**

- 新增 `AST_CLASS_DECL`, `AST_CLASS_EXPR`, `AST_METHOD_DEF`, `AST_SUPER`, `AST_COMPUTED_PROP`。

3. **语法**

- `class_declaration` 支持可选 `extends`，类体由 `class_element` 列表组成。
- 对象字面量中加入 `method_definition`, `shorthand_property`, `computed_property_name`。

4. **适配层/ASI**

- 类体 `{` 与对象字面量 `{` 需要新的种类区分，以避免 `}` 后误插 `;` 破坏 `class A {}` `export default class {}` 等结构。

5. **测试**

- `test/es6_stage4/class_basic.js`, `class_inheritance.js`, `object_literal_enhancement.js`。

---

## M5. 迭代协议、Generator、Spread/Rest、for-of

**目标**: 引入迭代相关语法，使 `for-of`, `yield`, `yield*`, `...` spread 与 rest 均可解析。

任务拆解：

1. **lexer.re**

- 新增 `...` spread token（若未完全支持），以及关键字 `yield`, `of`（上下文关键字）。

2. **语法/AST**

- `for_stmt` 新增 `for_of_stmt` 产生式，复用 M1 的 binding pattern。
- `function` 与 `generator_function` 区分：`function*`、`yield` 表达式（含 `yield*`）。
- `spread_element` 用于数组/调用表达式。

3. **ASI**

- `yield` 属于受限产生式，需要加入 `is_restricted_token` 列表，防止 `yield\n1` 被错误解析。

4. **测试**

- `test/es6_stage5/for_of.js`, `generators.js`, `spread.js`, `rest_in_objects.js`。

---

## M6. 模块、顶层 await 与其他 ES6+ 补全

**目标**: 使编译器能够解析 `import/export`、`default`、`export *`, 以及（可选）`async function`、`await`。

任务拆解：

1. **词法**

- 关键字：`import`, `export`, `from`, `as`, `default`, `async`, `await`。注意 `await` 仅在 async 函数内为关键字。

2. **语法/AST**

- 新增 `AST_IMPORT_DECL`, `AST_EXPORT_DECL`, `AST_EXPORT_ALL`, `AST_IMPORT_SPEC`, `AST_EXPORT_SPEC`。
- 支持 `export default class/function/expression`、`import("module")`（动态导入可暂缓）。
- 若引入 `async function`，需在 AST 中标识 `is_async`，并允许 `await` 表达式。

3. **入口与命令行**

- `parser_main.c` 可添加 `--module` 标志，决定是否允许 `import`/`export` 出现在顶层。

4. **测试**

- `test/es6_stage6/modules_basic.js`, `export_variants.js`, `async_await.js`。

---

## 3. 横切关注点

1. **文档同步**

- 每个里程碑结束后更新：`docs/parser.md`（新增语法）、`docs/es6_limitations.md`（已支持 vs 待支持）、`README`（能力矩阵）。

2. **性能与内存**

- 新语法会显著增加 AST 节点数量，需在 `ast_free` 中加入压力测试；建议在 `build.bat` 中新增 `test-memory` 目标，运行 parse → free 循环以发现泄漏。

3. **CI/回归**

- 当引入模块/类等特性后，`goodjs` 目录中的失败列表应写入 `build/parser_error_locations.log` 供比对；可以新增脚本统计“解析成功率”。

---

## 4. 参考资料

- 《ECMAScript 2015 Language Specification》章节 12~15（解构、函数、类、模块）。
- `esprima`, `acorn` 等开源解析器，可参考其 BNF 与 AST 设计。
- `docs/es6_limitations.md`：持续更新未覆盖语法与定位示例。

---

**下一步建议**

1. 完成 M0 基础加固与测试分层，建立可持续的回归环境。
2. 以 M1 解构为切入点（该特性阻塞了 `goodjs` 中最多的文件），逐步验证后推进后续里程碑。
3. 每完成一个里程碑，务必在 `todo.md` 中打勾并新增下一阶段的失败样例说明，确保团队对当前支持范围达成共识。

- 集成 Clang Static Analyzer
- 使用 Valgrind 检测内存泄漏
- Cppcheck 代码质量检查

- [ ] **Tool 3**: 代码覆盖率

  - 使用 gcov 生成覆盖率报告
  - 目标：达到 80% 以上代码覆盖率

- [ ] **Tool 4**: 性能基准测试
  - 创建性能测试套件
  - 监控性能回归

---

## 📅 里程碑规划

### Milestone 1: ASI 机制实现 (预计 2 周)

- 完成 P1 所有任务
- 通过 ASI 相关测试
- 更新文档

### Milestone 2: AST 构建 (预计 3 周)

- 完成 P2 所有任务
- 实现完整的 AST 节点系统
- 支持 AST 可视化

### Milestone 3: 语句扩展 (预计 2 周)

- 完成 P3 所有任务
- 支持完整的 ES5 语句集
- 通过综合测试

### Milestone 4: 运算符完善 (已完成)

- ✅ 完成 P4 所有任务
- ✅ 支持所有 ES5 基础运算符层级
- ✅ 验证优先级和结合性

### Milestone 5: 高级特性（可选）

- 根据需要实现 P5 任务
- 评估 ES6+ 支持的必要性

---

## 🎓 学习资源

### 必读文档

- [ECMAScript 5.1 规范](https://262.ecma-international.org/5.1/)
- [re2c 手册](https://re2c.org/manual/manual_c.html)
- [Bison 手册](https://www.gnu.org/software/bison/manual/)

### 推荐项目

- [flex-bison-examples](https://github.com/sunxfancy/flex-bison-examples)
- [Esprima (JavaScript 解析器)](https://esprima.org/)
- [Acorn (轻量级 JS 解析器)](https://github.com/acornjs/acorn)

### 编译原理书籍

- 《编译原理》（龙书）- 经典教材
- 《现代编译原理》- 实用指南

---

## 📊 进度跟踪

| 优先级   | 类别     | 总任务数 | 已完成 | 进行中 | 待开始 | 完成率  |
| -------- | -------- | -------- | ------ | ------ | ------ | ------- |
| P1       | ASI 机制 | 4        | 4      | 0      | 0      | 100%    |
| P2       | AST 构建 | 6        | 6      | 0      | 0      | 100%    |
| P3       | 语句扩展 | 6        | 6      | 0      | 0      | 100%    |
| P4       | 运算符   | 5        | 5      | 0      | 0      | 100%    |
| P5       | 高级特性 | 7        | 0      | 0      | 7      | 0%      |
| **总计** |          | **28**   | **21** | **0**  | **7**  | **75%** |

---

## 💡 贡献建议

如果你想为本项目做贡献，建议：

1. **新手友好**: 从修复编译警告、添加测试用例开始
2. **中级开发者**: 评估并实现 P5 启动项（正则、模板字符串等高级语法）
3. **高级开发者**: 基于 AST 实现代码生成、静态分析或优化 passes
4. **专家级**: 探索 P5 高级特性或性能优化

---

**项目维护者**: Stardreama  
**创建日期**: 2025 年 11 月 10 日  
**最后更新**: 2025 年 11 月 10 日
