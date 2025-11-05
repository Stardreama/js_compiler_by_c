# JavaScript 语法解析器（基于 C 语言）

## 项目简介

本项目旨在开发一个基于 C 语言的 JavaScript 语法解析器，能够解析 JavaScript 脚本并判断其是否符合语法规范。

## 技术栈

- **词法分析器**: re2c（支持 Unicode 定义）
- **语法分析器**: Bison
- **编程语言**: C/C++

> **注意**: 不使用 Flex 的原因是其不支持 Unicode 定义，而 JavaScript 中的多种符号是基于 Unicode 定义的。

## 核心功能要求

1. **语法验证**: 判断输入的 JavaScript 脚本是否符合语法规范
2. **ASI 机制**: 实现自动分号插入（Automatic Semicolon Insertion）机制，正确处理省略的分号

## 规范参考

- ECMAScript 规范: https://tc39.es/ecma262/
- 参考项目示例: https://github.com/sunxfancy/flex-bison-examples

## 项目结构

```
js_compiler_by_c/
├── readme.md           # 项目说明文档
├── Makefile           # 编译和测试脚本
├── lexer.re           # re2c 词法分析文件
├── parser.y           # Bison 语法分析文件
├── main.c             # 主程序入口
├── ast.h              # 抽象语法树定义
├── ast.c              # AST 相关实现
├── utils.h            # 工具函数头文件
├── utils.c            # 工具函数实现
└── tests/             # 测试用例目录
    ├── test_basic.js
    ├── test_asi.js
    └── test_complex.js
```

## 开发步骤

### 1. 环境准备

#### Windows 环境

- 安装 MinGW 或 MSYS2
- 安装 re2c: `pacman -S re2c`（MSYS2）或从官网下载
- 安装 Bison: `pacman -S bison`（MSYS2）
- 安装 make: `pacman -S make`（MSYS2）
- 安装 gcc: `pacman -S gcc`（MSYS2）

#### Linux/Mac 环境

```bash
# Ubuntu/Debian
sudo apt-get install re2c bison gcc make

# macOS
brew install re2c bison
```

### 2. 词法分析器开发 (lexer.re)

使用 re2c 定义 JavaScript 词法规则：

- **关键字**: `var`, `let`, `const`, `function`, `if`, `else`, `for`, `while`, `return` 等
- **标识符**: 支持 Unicode 字符
- **字面量**:
  - 数字（整数、浮点数、科学计数法）
  - 字符串（单引号、双引号、模板字符串）
  - 布尔值（true/false）
  - null, undefined
- **运算符**: `+`, `-`, `*`, `/`, `%`, `=`, `==`, `===`, `!=`, `!==`, `<`, `>`, `<=`, `>=`, `&&`, `||`, `!` 等
- **分隔符**: `{`, `}`, `[`, `]`, `(`, `)`, `;`, `,`, `.` 等
- **注释**: 单行注释 `//` 和多行注释 `/* */`
- **空白字符**: 空格、制表符、换行符

**关键点**:

- 正确处理 Unicode 标识符
- 识别正则表达式字面量（需要上下文相关处理）
- 跟踪行号和列号用于错误报告

### 3. 语法分析器开发 (parser.y)

使用 Bison 定义 JavaScript 语法规则：

#### 主要语法结构

- **程序结构**: Program → StatementList
- **语句**:
  - 变量声明: `var`/`let`/`const` 声明
  - 函数声明和函数表达式
  - 表达式语句
  - 控制流: `if-else`, `switch-case`
  - 循环: `for`, `while`, `do-while`
  - 跳转: `break`, `continue`, `return`
  - 块语句
- **表达式**:
  - 字面量表达式
  - 标识符
  - 赋值表达式
  - 二元运算表达式
  - 一元运算表达式
  - 三元运算符
  - 函数调用
  - 成员访问
  - 数组/对象字面量

### 4. ASI（自动分号插入）实现

根据 ECMAScript 规范 11.9 节实现 ASI 规则：

#### ASI 触发条件

1. **换行符触发**: 当遇到不符合语法的 token，且该 token 与前一个 token 之间有换行符
2. **文件结束**: 当到达输入流末尾，且无法形成完整程序
3. **受限产生式**: 某些语句后面的 token 受限（如 `return`, `break`, `continue`, `throw`）

#### 实现策略

```c
// 在词法分析器中跟踪换行
bool hasNewline = false;

// 在语法分析器中检查 ASI 条件
// 当语法错误发生时，检查是否可以插入分号
```

**示例**:

```javascript
// 合法（ASI 插入分号）
return;
a + b;

// 等价于
return;
a + b;
```

### 5. 主程序实现 (main.c)

```c
int main(int argc, char *argv[]) {
    // 1. 读取输入文件或标准输入
    // 2. 调用词法和语法分析器
    // 3. 报告解析结果（成功/失败）
    // 4. 输出错误信息（如果有）
    // 5. 可选：输出 AST（用于调试）
}
```

### 6. 编写 Makefile

```makefile
# 定义编译器和工具
CC = gcc
CFLAGS = -Wall -g
RE2C = re2c
BISON = bison

# 目标文件
TARGET = js_parser

# 生成词法分析器
lexer.c: lexer.re
	$(RE2C) -o lexer.c lexer.re

# 生成语法分析器
parser.c parser.h: parser.y
	$(BISON) -d -o parser.c parser.y

# 编译主程序
$(TARGET): lexer.c parser.c main.c ast.c utils.c
	$(CC) $(CFLAGS) -o $(TARGET) lexer.c parser.c main.c ast.c utils.c

# 清理
clean:
	rm -f lexer.c parser.c parser.h $(TARGET) *.o

# 测试
test: $(TARGET)
	./$(TARGET) tests/test_basic.js
	./$(TARGET) tests/test_asi.js
	./$(TARGET) tests/test_complex.js

.PHONY: clean test
```

### 7. 编写测试用例

#### test_basic.js - 基本语法测试

```javascript
var x = 10;
let y = 20;
const z = 30;

function add(a, b) {
  return a + b;
}

if (x > 5) {
  console.log("x is greater than 5");
}
```

#### test_asi.js - ASI 机制测试

```javascript
// 测试 return 后的 ASI
function test1() {
  return;
  42;
}

// 测试语句结尾的 ASI
var a = 10;
var b = 20;

// 测试 ++ 运算符的 ASI
a;
++b;
```

#### test_complex.js - 复杂语法测试

```javascript
// 对象字面量
const obj = {
  name: "test",
  value: 42,
  method: function () {
    return this.value;
  },
};

// 数组操作
const arr = [1, 2, 3, 4, 5];
const mapped = arr.map((x) => x * 2);

// 嵌套控制流
for (let i = 0; i < 10; i++) {
  if (i % 2 === 0) {
    continue;
  }
  console.log(i);
}
```

## 编译和运行

### 编译项目

```bash
make
```

### 运行测试

```bash
make test
```

### 手动测试单个文件

```bash
./js_parser test.js
```

### 清理生成文件

```bash
make clean
```

## 错误处理

解析器应当能够：

1. 准确报告错误位置（行号和列号）
2. 提供有意义的错误信息
3. 在可能的情况下进行错误恢复
4. 区分词法错误和语法错误

## 输出格式

### 成功解析

```
Parsing successful!
Input file: test.js
AST nodes: 42
```

### 解析失败

```
Syntax Error at line 5, column 12:
Unexpected token '}'
Expected: ';' or expression
```

## 调试建议

1. **分阶段测试**: 先测试简单的表达式，再测试复杂的语句结构
2. **AST 可视化**: 实现 AST 的打印功能，方便调试
3. **详细日志**: 在关键位置添加调试输出
4. **参考标准**: 对比主流 JavaScript 引擎（如 V8）的解析结果

## 已知限制和未来改进

- 当前版本仅支持 ES5 基本语法
- 可扩展支持 ES6+ 特性（箭头函数、类、模板字符串等）
- 可添加语义分析阶段
- 可实现代码生成或解释执行

## 提交材料清单

- [x] `lexer.re` - 词法分析文件
- [x] `parser.y` - 语法分析文件
- [x] `main.c`, `ast.c`, `utils.c` - C 语言程序文件
- [x] `tests/` - 测试用例目录
- [x] `Makefile` - 编译和测试脚本
- [x] `readme.md` - 项目文档

## 参考资料

1. **ECMAScript 规范**: https://tc39.es/ecma262/
2. **re2c 文档**: https://re2c.org/manual/manual_c.html
3. **Bison 手册**: https://www.gnu.org/software/bison/manual/
4. **参考项目**: https://github.com/sunxfancy/flex-bison-examples
5. **ASI 规则**: ECMAScript 规范 11.9 节

## 许可证

本项目仅用于学习和研究目的。

## 作者

Stardreama

---

**最后更新**: 2025 年 11 月 1 日
