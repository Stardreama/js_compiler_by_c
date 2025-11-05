/*
 * JavaScript 语法分析器（Bison）
 * 目标：在不改变项目现有风格的前提下，支持 tests/test_basic.js 的语法通过
 * 说明：本解析器仅做语法校验，不构建 AST；如需扩展，可在语义动作中逐步加入 AST 构建
 */

%{
#include <stdio.h>
#include <stdlib.h>

// 由 parser_lex_adapter.c 提供
int yylex(void);
void yyerror(const char *s);
%}

// 关键字与字面量等 token（避免与 token.h 中的枚举名冲突，去掉 TOK_ 前缀）
%token VAR LET CONST FUNCTION IF ELSE FOR RETURN
%token WHILE DO BREAK CONTINUE
%token SWITCH CASE DEFAULT TRY CATCH FINALLY THROW NEW THIS TYPEOF DELETE IN INSTANCEOF VOID WITH DEBUGGER

%token TRUE FALSE NULL_T UNDEFINED
%token IDENTIFIER NUMBER STRING

// 复合/关系/逻辑运算符
%token PLUS_PLUS MINUS_MINUS
%token EQ NE EQ_STRICT NE_STRICT
%token LE GE AND OR
%token LSHIFT RSHIFT URSHIFT
%token PLUS_ASSIGN MINUS_ASSIGN STAR_ASSIGN SLASH_ASSIGN PERCENT_ASSIGN
%token AND_ASSIGN OR_ASSIGN XOR_ASSIGN LSHIFT_ASSIGN RSHIFT_ASSIGN URSHIFT_ASSIGN

// 运算符结合性与优先级（从低到高）
%define parse.error verbose
%right '='
%left OR
%left AND
%left EQ NE EQ_STRICT NE_STRICT
%left '<' '>' LE GE
%left '+' '-'
%left '*' '/' '%'
%right UMINUS '!' '~'

%%

program
  : stmt_list
  ;

stmt_list
  : /* empty */
  | stmt_list stmt
  ;

stmt
  : ';'                                 /* 空语句 */
  | var_stmt ';'
  | expr_no_obj ';'                     /* 表达式语句：禁止以 { 开头，从而避免与 block 冲突 */
  | block
  | if_stmt
  | for_stmt
  | func_decl
  | return_stmt ';'
  ;

block
  : '{' '}'
  | '{' stmt_list '}'
  ;

// 变量声明：本仓库测试只涉及单个声明，支持可选初始化
var_stmt
  : VAR IDENTIFIER opt_init
  | LET IDENTIFIER opt_init
  | CONST IDENTIFIER opt_init
  ;

opt_init
  : /* empty */
  | '=' expr
  ;

return_stmt
  : RETURN
  | RETURN expr
  ;

if_stmt
  : IF '(' expr ')' stmt
  | IF '(' expr ')' stmt ELSE stmt
  ;

for_stmt
  : FOR '(' for_init ';' opt_expr ';' opt_expr ')' stmt
  ;

for_init
  : /* empty */
  | var_stmt
  | expr
  ;

opt_expr
  : /* empty */
  | expr
  ;

func_decl
  : FUNCTION IDENTIFIER '(' opt_param_list ')' block
  ;

opt_param_list
  : /* empty */
  | param_list
  ;

param_list
  : IDENTIFIER
  | param_list ',' IDENTIFIER
  ;

// 表达式（从赋值到原子与后缀）
expr
  : assignment_expr
  ;

assignment_expr
  : postfix_expr '=' assignment_expr
  | logical_or_expr
  ;

logical_or_expr
  : logical_and_expr
  | logical_or_expr OR logical_and_expr
  ;

logical_and_expr
  : equality_expr
  | logical_and_expr AND equality_expr
  ;

equality_expr
  : relational_expr
  | equality_expr EQ relational_expr
  | equality_expr NE relational_expr
  | equality_expr EQ_STRICT relational_expr
  | equality_expr NE_STRICT relational_expr
  ;

relational_expr
  : additive_expr
  | relational_expr '<' additive_expr
  | relational_expr '>' additive_expr
  | relational_expr LE  additive_expr
  | relational_expr GE  additive_expr
  ;

additive_expr
  : multiplicative_expr
  | additive_expr '+' multiplicative_expr
  | additive_expr '-' multiplicative_expr
  ;

multiplicative_expr
  : unary_expr
  | multiplicative_expr '*' unary_expr
  | multiplicative_expr '/' unary_expr
  | multiplicative_expr '%' unary_expr
  ;

unary_expr
  : postfix_expr
  | '+' unary_expr
  | '-' unary_expr %prec UMINUS
  | '!' unary_expr
  | '~' unary_expr
  ;

postfix_expr
  : primary_expr
  | postfix_expr '.' IDENTIFIER
  | postfix_expr '(' opt_arg_list ')'
  | postfix_expr PLUS_PLUS
  | postfix_expr MINUS_MINUS
  ;

opt_arg_list
  : /* empty */
  | arg_list
  ;

arg_list
  : expr
  | arg_list ',' expr
  ;

primary_expr
  : IDENTIFIER
  | NUMBER
  | STRING
  | '(' expr ')'
  | array_literal
  | object_literal
  ;

/*
 * 为了解决 if (...) { ... } 与以 { 开头的对象字面量表达式语句的冲突，
 * 我们为“表达式语句”引入一个不以 { 开头的表达式变体 expr_no_obj。
 * 对于需要对象字面量的场景（如初始化：a = { ... }），仍通过一般 expr 使用。
 */
expr_no_obj
  : assignment_expr_no_obj
  ;

assignment_expr_no_obj
  : postfix_expr_no_obj '=' assignment_expr
  | logical_or_expr_no_obj
  ;

logical_or_expr_no_obj
  : logical_and_expr_no_obj
  | logical_or_expr_no_obj OR logical_and_expr_no_obj
  ;

logical_and_expr_no_obj
  : equality_expr_no_obj
  | logical_and_expr_no_obj AND equality_expr_no_obj
  ;

equality_expr_no_obj
  : relational_expr_no_obj
  | equality_expr_no_obj EQ relational_expr_no_obj
  | equality_expr_no_obj NE relational_expr_no_obj
  | equality_expr_no_obj EQ_STRICT relational_expr_no_obj
  | equality_expr_no_obj NE_STRICT relational_expr_no_obj
  ;

relational_expr_no_obj
  : additive_expr_no_obj
  | relational_expr_no_obj '<' additive_expr_no_obj
  | relational_expr_no_obj '>' additive_expr_no_obj
  | relational_expr_no_obj LE  additive_expr_no_obj
  | relational_expr_no_obj GE  additive_expr_no_obj
  ;

additive_expr_no_obj
  : multiplicative_expr_no_obj
  | additive_expr_no_obj '+' multiplicative_expr_no_obj
  | additive_expr_no_obj '-' multiplicative_expr_no_obj
  ;

multiplicative_expr_no_obj
  : unary_expr_no_obj
  | multiplicative_expr_no_obj '*' unary_expr_no_obj
  | multiplicative_expr_no_obj '/' unary_expr_no_obj
  | multiplicative_expr_no_obj '%' unary_expr_no_obj
  ;

unary_expr_no_obj
  : postfix_expr_no_obj
  | '+' unary_expr_no_obj
  | '-' unary_expr_no_obj %prec UMINUS
  | '!' unary_expr_no_obj
  | '~' unary_expr_no_obj
  ;

postfix_expr_no_obj
  : primary_no_obj
  | postfix_expr_no_obj '.' IDENTIFIER
  | postfix_expr_no_obj '(' opt_arg_list ')'
  | postfix_expr_no_obj PLUS_PLUS
  | postfix_expr_no_obj MINUS_MINUS
  ;

primary_no_obj
  : IDENTIFIER
  | NUMBER
  | STRING
  | '(' expr ')'
  | array_literal
  ;

array_literal
  : '[' ']'
  | '[' el_list opt_trailing_comma ']'
  ;

el_list
  : expr
  | el_list ',' expr
  ;

opt_trailing_comma
  : /* empty */
  | ','
  ;

object_literal
  : '{' '}'
  | '{' prop_list opt_trailing_comma '}'
  ;

prop_list
  : prop
  | prop_list ',' prop
  ;

prop
  : IDENTIFIER ':' expr
  | STRING ':' expr
  ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Syntax error: %s\n", s);
}
