# ES6 语法支持现状说明

## 背景

在分析 `test/JavaScript_Datasets/goodjs/1621567341.1976447` 时，编译器报告：

```
Syntax error #1: syntax error, unexpected ';', expecting ':'
```

该文件是由构建工具压缩后的现代 JavaScript，需要完整的 ES2015+ 语法支持。我们逐段排查后确认：

1. **Binding Pattern（已覆盖声明 + 赋值）**

   - ✅ 变量声明（`var/let/const`）、函数/箭头形参、`catch`、`for-in` 头部以及普通赋值表达式现已支持对象 / 数组解构、默认值与 `...rest`。`test/es6_stage1/destructuring_assign.js`、`destructuring_var.js` 等覆盖常见组合，`[items.first, items.second = 10] = tuple`、`({ foo: target.name, bar = 2 } = payload)` 等写法均可通过。
   - ⚠️ 仍未实现 `for-of`/`yield` 等迭代语法中的赋值拆解；`new.target`、`import()` 等 ES2015+ 扩展也暂未加入。

2. **模板字符串**

   ```js
   const F = `${x}/ui/v1/checkout/${t}/${r}`;
   ```

   虽然词法层面已有 `TEMPLATE_*` token，但 AST 与语义动作尚未覆盖所有组合用法。

3. **默认参数 / rest 参数（函数体内）**
   形参列表（含箭头函数）已拥抱解构 + 默认值 + `...rest` 组合；后续仍需为 generator / async / class method 提供语义差异化处理。

4. **箭头函数**

   - ✅ 新增 `AST_ARROW_FUNCTION` 节点区分表达式体/块体，保留 `is_expression_body` 元信息，便于 `this` 绑定及 async/generator 扩展。
   - ⚠️ 若在 `=>` 前插入换行会立即触发语法错误，与 ECMAScript “no LineTerminator here” 规则一致；`test/es6_stage2/test_error_arrow_newline.js` 记录该限制。

5. **`new` 表达式与链式调用**

   - ✅ `new` 语法已重写为 `member_expr / call_expr / left_hand_side_expr` 三段式，能够正确解析 `new Image().src = ...`、`new Foo(bar).baz()` 等常见写法。`test/JavaScript_Datasets/goodjs/eb8511178bbe1d5132aa2504c710c666` 不再因为“syntax is ambiguous” 报错。
   - ⚠️ `new.target`、`import()` 这类 ES2015+ 扩展仍未建模；若在 `goodjs` 集中遇到，可暂时通过 `docs/todo.md` 记录并等待下一阶段支持。

综上，当前主干已覆盖声明类解构的高频场景，但尚未完成以下 ES6 语法：

- 解构赋值表达式（需要引入更复杂的 lookahead 或 GLR 方案）。
- 模板字符串、类、模块等 M1 之后的特性。

运行 `make test test/es6_stage1` 可获得最新的解构用例回归结果；`test/es6_stage1/test_error_destructuring_assign.js` 用于追踪尚未支持的赋值语法，请保持该命名以提示测试框架“预期失败”。
