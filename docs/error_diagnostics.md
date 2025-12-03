# 失败定位辅助说明

由于数据集中的 JavaScript 文件数量庞大，控制台上滚动的 `Syntax error #...` 输出不便于快速定位问题。现已在测试流程中新增自动记录机制：

1. 执行 `./make test <路径>` 或 `make test-parse` 时，解析器会把每一次语法错误记录到 `build/parser_error_locations.log`。
2. 单条记录格式：
   ```
   <文件绝对或相对路径>:<行号>:<列号>: <Bison 错误提示>
   ```
   例如：
   ```
   test/JavaScript_Datasets/goodjs/1621567340.3796244:83:14: syntax error, unexpected ';', expecting ':'
   ```
3. 该日志会在每次 `make test` 之前自动清空，并在出现失败后持续追加，可直接在 VS Code 中打开或配合 `Ctrl+G` / `Ctrl+P` 跳转。
4. 控制台输出保持原状，方便继续使用现有的进度条与回归结果；若需查看更多上下文，可结合 `build/test_failures.log`（完整 stdout/stderr）与本日志的行列信息。

> 注意：当语法错误发生在自动分号插入 (ASI) 虚拟 token 上时，记录的行列会指向触发 ASI 的实际源码 token，便于手动检查相邻语句。
