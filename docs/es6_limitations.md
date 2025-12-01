# ES6 语法支持现状说明

## 背景

在分析 `test/JavaScript_Datasets/goodjs/1621567341.1976447` 时，编译器报告：

```
Syntax error #1: syntax error, unexpected ';', expecting ':'
```

该文件是由构建工具压缩后的现代 JavaScript，需要完整的 ES2015+ 语法支持。我们逐段排查后确认：

1. **Binding Pattern（部分支持）**

   - ✅ 变量声明（`var/let/const`）、函数形参（含箭头函数）、`catch`、`for-in` 头部现已支持对象 / 数组解构、默认值与 `...rest`。
   - ⚠️ 赋值表达式（`({a} = expr)`、`[a] = expr`）仍未实现，相关文件需继续命名为 `test_error_*` 以标记期望失败。

2. **模板字符串**

   ```js
   const F = `${x}/ui/v1/checkout/${t}/${r}`;
   ```

   虽然词法层面已有 `TEMPLATE_*` token，但 AST 与语义动作尚未覆盖所有组合用法。

3. **默认参数 / rest 参数（函数体内）**
   形参列表内部可使用默认值与 `...rest`，但生成器 / async / class method 等更高阶形态仍缺失。

综上，当前主干已覆盖声明类解构的高频场景，但尚未完成以下 ES6 语法：

- 解构赋值表达式（需要引入更复杂的 lookahead 或 GLR 方案）。
- 模板字符串、类、模块等 M1 之后的特性。

运行 `make test test/es6_stage1` 可获得最新的解构用例回归结果；`test/es6_stage1/test_error_destructuring_assign.js` 用于追踪尚未支持的赋值语法，请保持该命名以提示测试框架“预期失败”。
