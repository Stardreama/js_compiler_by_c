# JS Parser Memory Exhaustion 现状与行动方案

## 1. 背景与问题概述

- **触发场景**：诸如 `tmp/repro_mem10.js` 的长链式成员访问与解构组合，会在 `_no_obj`/`_no_obj_no_arr` 表达式族内造成大量 GLR 分支；即使同时存在的栈并不多（≤16），但在提交之前重复回溯会消耗 10k+ 解析项，触发 "memory exhausted"。
- **临时缓解**：目前在 `src/parser.y` 中通过 `#define YYMAXDEPTH 1000000` 放大了 GLR 栈上限，`repro_mem10.js` 不再崩溃，ES6 stage/goodjs 测试可完整跑完。但根因依旧存在：`primary_no_obj_no_arr` 到 `member/call_expr` 的分支重复导致的堆叠爆炸仍会消耗大量内存/时间。

## 2. 既有工作回顾

1. **跟踪工具**：`%debug` + `JS_PARSER_TRACE=1` + `tmp/trace_compare.py` 已能定位到 `postfix_expr`/`member_expr` 阶段的拆栈情况；`trace_compare.py` 也会标出热点规则（例如 rule 443 导致的 50+ splits）。
2. **语法尝试**：
   - 单纯折叠 `primary_no_obj`（共用 `_no_arr`）无效果。
   - 直接合并 `member_expr`/`call_expr` 的后缀处理导致 ES6 stage1 模糊解析，被回滚。
   - `import/export` 的尾随逗号修复只解决了模块测试，与内存问题无关。
3. **内存设置**：上调 `YYMAXDEPTH` 属于“资源扩容”策略；不减少分支即可规避崩溃，但并未降低栈分配峰值，也掩盖了潜在性能瓶颈。

## 3. 当前症状与度量

- **Trace 指标（2025-12）**：
  - `repro_mem10.js` 仍会在 `'.'` 处产生 ~76 次分裂，顶层 rule 来自 `_no_obj_no_arr` 的 base case；
  - `repro_mem16.js` 仅 ~12 次分裂，可视作期望参考；
  - 两者的差距被 `trace_compare.py` 精确量化，可作为优化成效的验收指标。
- **临时修复的副作用**：`YYMAXDEPTH = 1000000` 会增加 parser.c 的内存占用（Bison 会按上限分配数组/批次扩容），在更大输入上可能仍不足，同时也可能掩盖其它歧义。

## 4. 待解决事项

1. **结构性减枝**（尚未实施）：
   - 引入共享的 `postfix_suffix_chain` 非终结符，让 `member_expr` 与 `call_expr` 只在“基底”层分叉，而后缀路径单独维护，减少 `_no_obj`、`_no_obj_no_arr` 的组合爆炸；
   - 或者引入独立的 “Assignment LHS” 非终结符，将禁止以 `{` 开头的场景与普通表达式彻底分离，取代当前 `_no_obj` 家族的递归复制。
2. **精细化指标**：为 `trace_compare.py` 增加“每个规则的累计栈条目”和“token 位置”统计，便于观察某次修改是否真正压缩了 `.` 分裂次数及峰值；若指标无改善则回滚。
3. **压力测试**：任何语法改动后都需要跑：
   - `tmp/repro_mem*.js`（至少 `10/16/18`），
   - `make test test/es6_stage{1,4,6}`，
   - `make test test/JavaScript_Datasets/goodjs`；
     以防新的模糊解析或性能回退。

## 5. 推荐路线图

| 阶段            | 目标                       | 关键任务                                                                 | 成功标准                                                                 |
| --------------- | -------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| Phase 0（完成） | 避免崩溃                   | 提升 `YYMAXDEPTH`、全量回归                                              | `repro_mem10.js` 不再 `memory exhausted`                                 |
| Phase 1         | 限定 `_no_obj` 分支        | 设计 `postfix_suffix_chain` 或等价结构，单测覆盖 `_no_obj_no_arr` 的入口 | `trace_compare` 报告中的 `.` 分裂次数下降 ≥30% ，且 stage 测试无模糊     |
| Phase 2         | 精简 `_no_in/_no_obj` 组合 | 将“禁止 object literal”逻辑封装为布尔标志/统一非终结符，避免 N×M 复制    | GLR reduce/reduce 冲突数下降（当前 232），trace 峰值 ≤ passing 样本的 2× |
| Phase 3         | 收敛与清理                 | 更新 `docs/`、补充新的回归测试（加入 `tmp/repro_mem*.js` 到正式测试集）  | 数据集跑完后 `build/parser_error_locations.log` 无新增噪声               |

## 6. 风险与对策

- **风险 1：重新引入语法模糊** —— 任何后缀合并都有可能产生两条语义相同的 derivation。对策：使用 `bison -Wcounterexamples` 及时捕获，必要时在问题规则上加 `%dprec` 或显式拆分。
- **风险 2：性能测量缺失** —— 若只依赖 pass/fail，很难知道修改是否有效。对策：规范“trace 前后对比 + 峰值栈计数”作为 Merge Gate。
- **风险 3：临时文件漂移** —— 当前 repro/trace 文件仅在 `tmp/` 中未纳入测试。对策：挑选 1~2 个稳定 repro 纳入 `test/`，避免未来改动遗忘验证。

## 7. 建议的文档/代码更新

1. 将本文件纳入评审范围，并在 PR 模板中附上最新 `trace_compare` 输出。
2. 在 `docs/memory_issue_attempts.md` 末尾追加“同步路线图”段落，指向本计划。
3. 未来提交里若涉及 `_no_obj` 家族，务必在描述中列出“对 `repro_mem10.js` 的栈峰值影响”。

---

通过上述步骤，才能在维持语义正确性的前提下真正解决 memory exhausted，而不仅是依赖更大的 `YYMAXDEPTH`。
