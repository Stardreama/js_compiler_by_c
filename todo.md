# JavaScript 编译器项目 - 开发任务清单

> **最后更新**: 2025 年 11 月 10 日  
> **项目状态**: 词法分析器 ✅ | 语法分析器 ✅ | 双可执行程序架构 ✅ | ASI 基础规则 ✅

---

## 📊 项目概览

### 已完成功能 (100%)

- ✅ **词法分析器** (lexer.re, 374 行)

  - 27 个 ES5 关键字识别
  - 73+ 种运算符和分隔符
  - 数字/字符串字面量解析
  - 单行和多行注释处理
  - 行号/列号精确跟踪
  - 换行标记 `has_newline`（为 ASI 预留）

- ✅ **语法分析器** (parser.y, 317 行)

  - 变量声明（var/let/const）
  - 函数声明和调用
  - 控制流（if-else、for 循环）
  - 表达式（一元、二元、赋值、成员访问）
  - 数组和对象字面量
  - 7 级运算符优先级
  - 块 vs 对象字面量歧义消解

- ✅ **构建系统**

  - build.bat (Windows) - 6 个命令
  - Makefile (MSYS2/Linux)
  - 双可执行程序架构

- ✅ **测试套件**

  - 5 个测试用例全部通过
  - 词法分析测试
  - 语法验证测试
  - 错误检测测试

- ✅ **文档**
  - .github/copilot-instructions.md (AI 指南)
  - BUILD.md (构建文档)
  - TEST_REPORT.md (测试报告)
  - readme.md (项目说明)

---

## 🎯 优先级 P1 - ASI（自动分号插入）机制 ✅

**重要性**: 🔴 关键功能  
**难度**: ⭐⭐⭐⭐  
**完成时间**: 2025 年 11 月 10 日

### 背景说明（P1）

ASI (Automatic Semicolon Insertion) 是 JavaScript 的核心特性，允许省略分号。根据 ECMAScript 11.9 节规范，有三种触发条件：

1. **换行符触发**: 遇到语法错误 token 且前面有换行
2. **文件结束**: 到达输入流末尾
3. **受限产生式**: `return`/`break`/`continue`/`throw`/`yield` 后遇到换行

### 任务清单（P1）

- [x] **Task 1.1**: 在适配层实现 ASI 插入逻辑（`parser_lex_adapter.c`）

  - 读取 `lexer->has_newline` 信号并根据 EOF/`}`/受限产生式注入虚拟分号
  - 维护控制语句括号栈，避免 `if (...)`/`for (...)` 后误插分号

- [x] **Task 1.2**: 受限产生式处理

  - `return`/`break`/`continue`/`throw` 遇到换行、EOF 或 `}` 时强制插入分号
  - 覆盖 `a\n++b` 等需强制断句的场景

- [x] **Task 1.3**: 测试用例开发

  - 新增 `tests/test_asi_basic.js`（链式语句 + `a\n++b`）
  - 新增 `tests/test_asi_return.js`（`return` 换行）
  - 新增 `tests/test_asi_control.js`（验证 `if`/`else` 不误插）
  - `build.bat`/`Makefile` 扩展 `test-parse` 覆盖上述用例

- [ ] **Task 1.4**: 文档更新
  - 在 BUILD.md 中添加 ASI 功能说明
  - 更新 .github/copilot-instructions.md
  - 添加 ASI 实现技术文档

### 技术参考

- [ECMAScript 5.1 规范 11.9 节](https://262.ecma-international.org/5.1/#sec-11.9)
- 已实现的基础设施: `lexer->has_newline` 标记
- 适配层全局状态: `g_lexer` in parser_lex_adapter.c

---

## 🎯 优先级 P2 - AST（抽象语法树）构建

**重要性**: 🟡 重要功能  
**难度**: ⭐⭐⭐⭐⭐  
**预计工时**: 7-10 天

### 背景说明（P2）

当前解析器仅做语法验证（parser.y 的语义动作为空），需要构建 AST 才能支持后续的语义分析、代码生成或解释执行。

### 任务清单（P2）

- [ ] **Task 2.1**: 设计 AST 节点结构

  - 创建 `ast.h` 定义节点类型和结构体
  - 定义节点类型枚举（Stmt、Expr、Literal 等）
  - 设计节点内存管理策略（malloc/free）
  - 参考现有的 Token 内存管理模式

- [ ] **Task 2.2**: 实现 AST 构建函数

  - 创建 `ast.c` 实现节点创建函数
  - `ast_create_program()` - 程序根节点
  - `ast_create_var_decl()` - 变量声明节点
  - `ast_create_function()` - 函数声明节点
  - `ast_create_binary_expr()` - 二元表达式节点
  - 等其他节点类型...

- [ ] **Task 2.3**: 在 parser.y 中添加语义动作

  ```c
  // 示例：变量声明的 AST 构建
  var_declaration
      : VAR IDENTIFIER '=' expr ';'
          { $$ = ast_create_var_decl($2, $4); }
      ;
  ```

  - 为所有语法规则添加 AST 构建代码
  - 处理节点的父子关系
  - 实现 AST 树的正确组装

- [ ] **Task 2.4**: 实现 AST 遍历和打印

  - `ast_print()` - 以缩进格式打印 AST
  - `ast_traverse()` - 深度优先遍历
  - `ast_free()` - 递归释放 AST 内存

- [ ] **Task 2.5**: 集成到主程序

  - 修改 `parser_main.c` 输出 AST
  - 添加 `--dump-ast` 命令行参数
  - 在测试中验证 AST 结构正确性

- [ ] **Task 2.6**: 测试和文档
  - 为所有语法结构验证 AST 构建
  - 添加 AST 可视化输出（JSON 或 Graphviz）
  - 编写 AST 设计文档

---

## 🎯 优先级 P3 - 扩展语句覆盖

**重要性**: 🟢 增强功能  
**难度**: ⭐⭐⭐  
**预计工时**: 4-6 天

### 背景说明（P3）

当前仅支持基本语句（var/let/const、if-else、for、function、return），需要扩展到完整的 ES5 语句集。

### 任务清单（P3）

- [ ] **Task 3.1**: while 循环

  - 在 parser.y 中添加 while 语法规则
  - 添加 `tests/test_while.js` 测试用例
  - 验证嵌套 while 和 break/continue

- [ ] **Task 3.2**: do-while 循环

  - 在 parser.y 中添加 do-while 语法规则
  - 测试 do-while 的执行至少一次语义
  - 验证与 ASI 的交互（do {} while(x) 后的分号）

- [ ] **Task 3.3**: switch-case 语句

  - 实现 switch、case、default 规则
  - 处理 fall-through 语义
  - 测试多 case 和嵌套 switch

- [ ] **Task 3.4**: try-catch-finally 异常处理

  - 实现 try/catch/finally 语法规则
  - 支持 catch 子句的异常变量绑定
  - 验证 finally 块的执行保证

- [ ] **Task 3.5**: with 语句

  - 实现 with 语法规则（虽然不推荐使用）
  - 添加词法分析器的 `with` 关键字支持（已有）

- [ ] **Task 3.6**: 标签语句和 labeled break/continue
  - 支持 `label: statement` 语法
  - 支持 `break label` 和 `continue label`

### 技术要点

- 词法分析器已支持所有关键字（while、do、switch、case、default、try、catch、finally）
- 主要工作在 parser.y 的语法规则扩展

---

## 🎯 优先级 P4 - 完整运算符支持

**重要性**: 🟢 增强功能  
**难度**: ⭐⭐⭐  
**预计工时**: 3-4 天

### 背景说明（P4）

当前支持基本运算符，但缺少三元运算符、完整的位运算和复合赋值。

### 任务清单（P4）

- [ ] **Task 4.1**: 三元条件运算符 `? :`

  - 在 parser.y 中添加 `expr ? expr : expr` 规则
  - 设置正确的优先级（低于逻辑或 OR）
  - 测试嵌套三元运算符

- [ ] **Task 4.2**: 位运算符

  - 按位与 `&`、按位或 `|`、按位异或 `^`
  - 左移 `<<`、有符号右移 `>>`、无符号右移 `>>>`
  - 设置正确的优先级（在算术和逻辑之间）

- [ ] **Task 4.3**: 复合赋值运算符

  - 算术复合赋值: `+=`, `-=`, `*=`, `/=`, `%=`
  - 位运算复合赋值: `&=`, `|=`, `^=`, `<<=`, `>>=`, `>>>=`
  - 词法分析器已支持，需在 parser.y 中映射

- [ ] **Task 4.4**: 逗号运算符

  - 支持 `expr, expr` 语法
  - 设置最低优先级
  - 测试在 for 循环中的使用

- [ ] **Task 4.5**: typeof、delete、void 运算符
  - 一元运算符扩展
  - 词法分析器已支持关键字
  - 在 parser.y 中添加规则

### 测试要求

- 创建 `tests/test_operators.js` 综合测试
- 验证运算符优先级和结合性
- 测试复杂表达式的解析正确性

---

## 🎯 优先级 P5 - 高级特性

**重要性**: 🔵 可选功能  
**难度**: ⭐⭐⭐⭐⭐  
**预计工时**: 10+ 天

### 任务清单（P5）

- [ ] **Task 5.1**: 正则表达式字面量

  - 实现上下文感知词法分析（区分 `/` 除法与正则开头）
  - 在词法分析器中维护前一个 token 类型
  - 添加正则表达式标志（g、i、m、u、y）解析
  - **难点**: 需要词法-语法协同判断

- [ ] **Task 5.2**: 模板字符串（ES6）

  - 支持反引号 `` ` `` 字符串
  - 实现 `${...}` 插值表达式
  - 需要状态机或递归处理嵌套
  - **难点**: 插值内部可包含任意表达式

- [ ] **Task 5.3**: 箭头函数（ES6）

  - 支持 `() => expr` 和 `() => { stmt }` 语法
  - 处理参数解构和默认值
  - **难点**: 与小于号 `<` 的歧义消解

- [ ] **Task 5.4**: 类声明（ES6）

  - 支持 `class Name { ... }` 语法
  - 构造函数、方法、静态方法
  - 继承 `extends` 和 `super`

- [ ] **Task 5.5**: async/await（ES8）

  - 支持异步函数声明
  - await 表达式解析

- [ ] **Task 5.6**: 解构赋值（ES6）

  - 数组解构 `[a, b] = [1, 2]`
  - 对象解构 `{x, y} = obj`

- [ ] **Task 5.7**: 扩展运算符（ES6）
  - 扩展语法 `...args`
  - 在函数调用、数组、对象中的应用

### 技术挑战

- 这些特性大多属于 ES6+，超出当前 ES5 范围
- 需要权衡是否值得投入（可能需要重构现有架构）
- 建议：先完成 P1-P4，再评估是否实现

---

## 🐛 已知问题和改进

### 编译警告（低优先级）

- [ ] **Issue 1**: re2c sentinel 警告 (lexer.re:82)

  - 不影响功能
  - 可通过添加 `re2c:sentinel` 配置解决

- [ ] **Issue 2**: Bison 2 项冲突警告

  - 不影响功能
  - 可添加 `%expect 2` 指令消除警告
  - 或通过更精确的语法规则解决

- [ ] **Issue 3**: 未使用变量 comment_start (lexer.re:89)
  - 删除未使用的变量

### 代码质量改进

- [ ] **Task Q1**: 添加单元测试框架

  - 集成 CTest 或其他 C 测试框架
  - 为词法分析器编写单元测试
  - 为语法分析器编写单元测试

- [ ] **Task Q2**: 改进错误报告

  - 实现更友好的错误信息格式
  - 添加代码片段高亮显示错误位置
  - 提供错误修复建议（Did you mean...）

- [ ] **Task Q3**: 性能优化

  - 词法分析器性能分析
  - 减少 Token 内存分配次数
  - 优化字符串复制操作

- [ ] **Task Q4**: 代码重构
  - 统一命名约定
  - 添加详细的代码注释
  - 分离接口和实现（.h 和 .c）

---

## 📚 文档改进

- [ ] **Doc 1**: 编写架构设计文档

  - 详细说明词法-语法适配层设计
  - 解释歧义消解策略
  - 记录设计决策和权衡

- [ ] **Doc 2**: 添加贡献指南 (CONTRIBUTING.md)

  - 代码风格规范
  - Pull Request 流程
  - 测试要求

- [ ] **Doc 3**: 创建开发者指南 (DEVELOPMENT.md)

  - 调试技巧
  - 常见问题解答
  - 工具链详细说明

- [ ] **Doc 4**: API 文档生成
  - 使用 Doxygen 生成 API 文档
  - 为所有公共函数添加文档注释

---

## 🧪 测试扩展

- [ ] **Test 1**: 创建完整的测试套件

  - 按语法类别组织测试（statements、expressions、literals 等）
  - 每个特性至少 3 个测试用例（正常、边界、错误）

- [ ] **Test 2**: 模糊测试 (Fuzzing)

  - 使用 AFL 或 libFuzzer 进行模糊测试
  - 发现潜在的崩溃和内存问题

- [ ] **Test 3**: 与标准引擎对比测试
  - 收集真实 JavaScript 代码样本
  - 与 V8、SpiderMonkey 对比解析结果
  - 确保兼容性

---

## 🔧 工具和基础设施

- [ ] **Tool 1**: 持续集成 (CI/CD)

  - 配置 GitHub Actions 自动构建
  - 在多平台测试（Windows、Linux、macOS）
  - 自动运行测试套件

- [ ] **Tool 2**: 静态分析

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

### Milestone 4: 运算符完善 (预计 1 周)

- 完成 P4 所有任务
- 支持所有 ES5 运算符
- 验证优先级和结合性

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

| 优先级   | 类别     | 总任务数 | 已完成 | 进行中 | 待开始 | 完成率    |
| -------- | -------- | -------- | ------ | ------ | ------ | --------- |
| P1       | ASI 机制 | 4        | 3      | 0      | 1      | 75%       |
| P2       | AST 构建 | 6        | 0      | 0      | 6      | 0%        |
| P3       | 语句扩展 | 6        | 0      | 0      | 6      | 0%        |
| P4       | 运算符   | 5        | 0      | 0      | 5      | 0%        |
| P5       | 高级特性 | 7        | 0      | 0      | 7      | 0%        |
| **总计** |          | **28**   | **3**  | **0**  | **25** | **10.7%** |

---

## 💡 贡献建议

如果你想为本项目做贡献，建议：

1. **新手友好**: 从修复编译警告、添加测试用例开始
2. **中级开发者**: 实现 P3/P4 的语句和运算符扩展
3. **高级开发者**: 挑战 P1 ASI 机制或 P2 AST 构建
4. **专家级**: 探索 P5 高级特性或性能优化

---

**项目维护者**: Stardreama  
**创建日期**: 2025 年 11 月 10 日  
**最后更新**: 2025 年 11 月 10 日
