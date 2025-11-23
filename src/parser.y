/*
 * JavaScript 语法分析器（Bison）
 * 现支持在语义动作中构建 AST，并可通过 --dump-ast 选项输出树结构。
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include "ast.h"

int yylex(void);
void yyerror(const char *s);

static ASTNode *g_parser_ast_root = NULL;
static int g_parser_error_count = 0;
%}

%code provides {
    ASTNode *parser_take_ast(void);
    void parser_reset_error_count(void);
    int parser_error_count(void);
}

%code requires {
    #include "ast.h"
}

%union {
    ASTNode *node;
    ASTList *list;
    char *str;
}

%token VAR LET CONST FUNCTION IF ELSE FOR RETURN
%token WHILE DO BREAK CONTINUE
%token SWITCH CASE DEFAULT TRY CATCH FINALLY THROW NEW THIS TYPEOF DELETE IN INSTANCEOF VOID WITH DEBUGGER

%token TRUE FALSE NULL_T UNDEFINED
%token <str> IDENTIFIER NUMBER STRING

%token PLUS_PLUS MINUS_MINUS
%token EQ NE EQ_STRICT NE_STRICT
%token LE GE AND OR
%token LSHIFT RSHIFT URSHIFT
%token PLUS_ASSIGN MINUS_ASSIGN STAR_ASSIGN SLASH_ASSIGN PERCENT_ASSIGN
%token AND_ASSIGN OR_ASSIGN XOR_ASSIGN LSHIFT_ASSIGN RSHIFT_ASSIGN URSHIFT_ASSIGN

%define parse.error verbose
%right '=' PLUS_ASSIGN MINUS_ASSIGN STAR_ASSIGN SLASH_ASSIGN PERCENT_ASSIGN AND_ASSIGN OR_ASSIGN XOR_ASSIGN LSHIFT_ASSIGN RSHIFT_ASSIGN URSHIFT_ASSIGN
%right '?' ':'
%left OR
%left AND
%left '|'
%left '^'
%left '&'
%left EQ NE EQ_STRICT NE_STRICT
%left '<' '>' LE GE
%left LSHIFT RSHIFT URSHIFT
%left '+' '-'
%left '*' '/' '%'
%right UMINUS '!' '~' TYPEOF DELETE VOID PLUS_PLUS MINUS_MINUS

%type <node> program stmt block var_stmt opt_init return_stmt if_stmt for_stmt while_stmt do_stmt switch_stmt try_stmt with_stmt labeled_stmt break_stmt continue_stmt throw_stmt func_decl for_init opt_expr catch_clause finally_clause finally_clause_opt switch_case
%type <node> expr assignment_expr conditional_expr logical_or_expr logical_and_expr bitwise_or_expr bitwise_xor_expr bitwise_and_expr equality_expr relational_expr shift_expr additive_expr multiplicative_expr unary_expr postfix_expr primary_expr
%type <node> expr_no_obj assignment_expr_no_obj conditional_expr_no_obj logical_or_expr_no_obj logical_and_expr_no_obj bitwise_or_expr_no_obj bitwise_xor_expr_no_obj bitwise_and_expr_no_obj equality_expr_no_obj relational_expr_no_obj shift_expr_no_obj additive_expr_no_obj multiplicative_expr_no_obj unary_expr_no_obj postfix_expr_no_obj primary_no_obj
%type <node> array_literal object_literal prop
%type <list> stmt_list opt_param_list param_list opt_arg_list arg_list el_list prop_list switch_case_list case_stmt_seq

%%

program
  : stmt_list
      {
          $$ = ast_make_program($1);
          g_parser_ast_root = $$;
      }
  ;

stmt_list
  : /* empty */
      { $$ = NULL; }
  | stmt_list stmt
      { $$ = ast_list_append($1, $2); }
  ;

stmt
  : ';'
      { $$ = ast_make_empty_statement(); }
  | var_stmt ';'
      { $$ = $1; }
  | expr_no_obj ';'
      { $$ = ast_make_expression_stmt($1); }
  | block
      { $$ = $1; }
  | if_stmt
      { $$ = $1; }
  | for_stmt
      { $$ = $1; }
  | while_stmt
      { $$ = $1; }
  | do_stmt
      { $$ = $1; }
  | switch_stmt
      { $$ = $1; }
  | try_stmt
      { $$ = $1; }
  | with_stmt
      { $$ = $1; }
  | func_decl
      { $$ = $1; }
  | return_stmt ';'
      { $$ = $1; }
  | break_stmt ';'
      { $$ = $1; }
  | continue_stmt ';'
      { $$ = $1; }
  | throw_stmt ';'
      { $$ = $1; }
  | labeled_stmt
      { $$ = $1; }
  ;

block
  : '{' '}'
      { $$ = ast_make_block(NULL); }
  | '{' stmt_list '}'
      { $$ = ast_make_block($2); }
  ;

var_stmt
  : VAR IDENTIFIER opt_init
      { $$ = ast_make_var_decl(AST_VAR_KIND_VAR, $2, $3); }
  | LET IDENTIFIER opt_init
      { $$ = ast_make_var_decl(AST_VAR_KIND_LET, $2, $3); }
  | CONST IDENTIFIER opt_init
      { $$ = ast_make_var_decl(AST_VAR_KIND_CONST, $2, $3); }
  ;

opt_init
  : /* empty */
      { $$ = NULL; }
  | '=' expr
      { $$ = $2; }
  ;

return_stmt
  : RETURN
      { $$ = ast_make_return(NULL); }
  | RETURN expr
      { $$ = ast_make_return($2); }
  ;

if_stmt
  : IF '(' expr ')' stmt
      { $$ = ast_make_if($3, $5, NULL); }
  | IF '(' expr ')' stmt ELSE stmt
      { $$ = ast_make_if($3, $5, $7); }
  ;

for_stmt
  : FOR '(' for_init ';' opt_expr ';' opt_expr ')' stmt
      { $$ = ast_make_for($3, $5, $7, $9); }
  ;

while_stmt
    : WHILE '(' expr ')' stmt
            { $$ = ast_make_while($3, $5); }
    ;

do_stmt
    : DO stmt WHILE '(' expr ')' ';'
            { $$ = ast_make_do_while($2, $5); }
    | DO stmt WHILE '(' expr ')'
            { $$ = ast_make_do_while($2, $5); }
    ;

for_init
  : /* empty */
      { $$ = NULL; }
  | var_stmt
      { $$ = $1; }
  | expr
      { $$ = $1; }
  ;

opt_expr
  : /* empty */
      { $$ = NULL; }
  | expr
      { $$ = $1; }
  ;

switch_stmt
    : SWITCH '(' expr ')' '{' switch_case_list '}'
            { $$ = ast_make_switch($3, $6); }
    ;

switch_case_list
    : /* empty */
            { $$ = NULL; }
    | switch_case_list switch_case
            { $$ = ast_list_append($1, $2); }
    ;

switch_case
    : CASE expr ':' case_stmt_seq
            { $$ = ast_make_switch_case($2, $4); }
    | DEFAULT ':' case_stmt_seq
            { $$ = ast_make_switch_default($3); }
    ;

case_stmt_seq
    : /* empty */
            { $$ = NULL; }
    | case_stmt_seq stmt
            { $$ = ast_list_append($1, $2); }
    ;

func_decl
  : FUNCTION IDENTIFIER '(' opt_param_list ')' block
      { $$ = ast_make_function_decl($2, $4, $6); }
  ;

opt_param_list
  : /* empty */
      { $$ = NULL; }
  | param_list
      { $$ = $1; }
  ;

param_list
  : IDENTIFIER
      { $$ = ast_list_append(NULL, ast_make_identifier($1)); }
  | param_list ',' IDENTIFIER
      { $$ = ast_list_append($1, ast_make_identifier($3)); }
  ;

catch_clause
    : CATCH '(' IDENTIFIER ')' block
            { $$ = ast_make_catch($3, $5); }
    ;

finally_clause
    : FINALLY block
            { $$ = $2; }
    ;

finally_clause_opt
    : /* empty */
            { $$ = NULL; }
    | finally_clause
            { $$ = $1; }
    ;

try_stmt
    : TRY block catch_clause finally_clause_opt
            { $$ = ast_make_try($2, $3, $4); }
    | TRY block finally_clause
            { $$ = ast_make_try($2, NULL, $3); }
    ;

with_stmt
    : WITH '(' expr ')' stmt
            { $$ = ast_make_with($3, $5); }
    ;

labeled_stmt
    : IDENTIFIER ':' stmt
            { $$ = ast_make_labeled($1, $3); }
    ;

break_stmt
    : BREAK
            { $$ = ast_make_break(NULL); }
    | BREAK IDENTIFIER
            { $$ = ast_make_break($2); }
    ;

continue_stmt
    : CONTINUE
            { $$ = ast_make_continue(NULL); }
    | CONTINUE IDENTIFIER
            { $$ = ast_make_continue($2); }
    ;

throw_stmt
    : THROW expr
            { $$ = ast_make_throw($2); }
    ;

expr
  : assignment_expr
      { $$ = $1; }
    | expr ',' assignment_expr
            { $$ = ast_make_sequence($1, $3); }
  ;

assignment_expr
  : postfix_expr '=' assignment_expr
      { $$ = ast_make_assignment("=", $1, $3); }
  | postfix_expr PLUS_ASSIGN assignment_expr
      { $$ = ast_make_assignment("+=", $1, $3); }
  | postfix_expr MINUS_ASSIGN assignment_expr
      { $$ = ast_make_assignment("-=", $1, $3); }
  | postfix_expr STAR_ASSIGN assignment_expr
      { $$ = ast_make_assignment("*=", $1, $3); }
  | postfix_expr SLASH_ASSIGN assignment_expr
      { $$ = ast_make_assignment("/=", $1, $3); }
  | postfix_expr PERCENT_ASSIGN assignment_expr
      { $$ = ast_make_assignment("%=", $1, $3); }
  | postfix_expr AND_ASSIGN assignment_expr
      { $$ = ast_make_assignment("&=", $1, $3); }
  | postfix_expr OR_ASSIGN assignment_expr
      { $$ = ast_make_assignment("|=", $1, $3); }
  | postfix_expr XOR_ASSIGN assignment_expr
      { $$ = ast_make_assignment("^=", $1, $3); }
  | postfix_expr LSHIFT_ASSIGN assignment_expr
      { $$ = ast_make_assignment("<<=", $1, $3); }
  | postfix_expr RSHIFT_ASSIGN assignment_expr
      { $$ = ast_make_assignment(">>=", $1, $3); }
  | postfix_expr URSHIFT_ASSIGN assignment_expr
      { $$ = ast_make_assignment(">>>=", $1, $3); }
  | conditional_expr
      { $$ = $1; }
  ;

conditional_expr
    : logical_or_expr
            { $$ = $1; }
    | logical_or_expr '?' assignment_expr ':' assignment_expr
            { $$ = ast_make_conditional($1, $3, $5); }
    ;

logical_or_expr
  : logical_and_expr
      { $$ = $1; }
  | logical_or_expr OR logical_and_expr
      { $$ = ast_make_binary("||", $1, $3); }
  ;

logical_and_expr
    : bitwise_or_expr
      { $$ = $1; }
    | logical_and_expr AND bitwise_or_expr
      { $$ = ast_make_binary("&&", $1, $3); }
  ;

bitwise_or_expr
    : bitwise_xor_expr
            { $$ = $1; }
    | bitwise_or_expr '|' bitwise_xor_expr
            { $$ = ast_make_binary("|", $1, $3); }
    ;

bitwise_xor_expr
    : bitwise_and_expr
            { $$ = $1; }
    | bitwise_xor_expr '^' bitwise_and_expr
            { $$ = ast_make_binary("^", $1, $3); }
    ;

bitwise_and_expr
    : equality_expr
            { $$ = $1; }
    | bitwise_and_expr '&' equality_expr
            { $$ = ast_make_binary("&", $1, $3); }
    ;

equality_expr
    : relational_expr
      { $$ = $1; }
  | equality_expr EQ relational_expr
      { $$ = ast_make_binary("==", $1, $3); }
  | equality_expr NE relational_expr
      { $$ = ast_make_binary("!=", $1, $3); }
  | equality_expr EQ_STRICT relational_expr
      { $$ = ast_make_binary("===", $1, $3); }
  | equality_expr NE_STRICT relational_expr
      { $$ = ast_make_binary("!==", $1, $3); }
  ;

relational_expr
  : shift_expr
      { $$ = $1; }
  | relational_expr '<' shift_expr
      { $$ = ast_make_binary("<", $1, $3); }
  | relational_expr '>' shift_expr
      { $$ = ast_make_binary(">", $1, $3); }
  | relational_expr LE shift_expr
      { $$ = ast_make_binary("<=", $1, $3); }
  | relational_expr GE shift_expr
      { $$ = ast_make_binary(">=", $1, $3); }
  ;

shift_expr
  : additive_expr
      { $$ = $1; }
  | shift_expr LSHIFT additive_expr
      { $$ = ast_make_binary("<<", $1, $3); }
  | shift_expr RSHIFT additive_expr
      { $$ = ast_make_binary(">>", $1, $3); }
  | shift_expr URSHIFT additive_expr
      { $$ = ast_make_binary(">>>", $1, $3); }
  ;

additive_expr
  : multiplicative_expr
      { $$ = $1; }
  | additive_expr '+' multiplicative_expr
      { $$ = ast_make_binary("+", $1, $3); }
  | additive_expr '-' multiplicative_expr
      { $$ = ast_make_binary("-", $1, $3); }
  ;

multiplicative_expr
  : unary_expr
      { $$ = $1; }
  | multiplicative_expr '*' unary_expr
      { $$ = ast_make_binary("*", $1, $3); }
  | multiplicative_expr '/' unary_expr
      { $$ = ast_make_binary("/", $1, $3); }
  | multiplicative_expr '%' unary_expr
      { $$ = ast_make_binary("%", $1, $3); }
  ;

unary_expr
  : postfix_expr
      { $$ = $1; }
  | '+' unary_expr
      { $$ = ast_make_unary("+", $2); }
  | '-' unary_expr %prec UMINUS
      { $$ = ast_make_unary("-", $2); }
  | '!' unary_expr
      { $$ = ast_make_unary("!", $2); }
  | '~' unary_expr
      { $$ = ast_make_unary("~", $2); }
  | TYPEOF unary_expr
      { $$ = ast_make_unary("typeof", $2); }
  | DELETE unary_expr
      { $$ = ast_make_unary("delete", $2); }
  | VOID unary_expr
      { $$ = ast_make_unary("void", $2); }
  | PLUS_PLUS unary_expr
      { $$ = ast_make_update("++", $2, true); }
  | MINUS_MINUS unary_expr
      { $$ = ast_make_update("--", $2, true); }
  ;

postfix_expr
  : primary_expr
      { $$ = $1; }
  | postfix_expr '.' IDENTIFIER
      { $$ = ast_make_member($1, $3, false); }
  | postfix_expr '(' opt_arg_list ')'
      { $$ = ast_make_call($1, $3); }
  | postfix_expr PLUS_PLUS
      { $$ = ast_make_update("++", $1, false); }
  | postfix_expr MINUS_MINUS
      { $$ = ast_make_update("--", $1, false); }
  ;

opt_arg_list
  : /* empty */
      { $$ = NULL; }
  | arg_list
      { $$ = $1; }
  ;

arg_list
  : assignment_expr
      { $$ = ast_list_append(NULL, $1); }
  | arg_list ',' assignment_expr
      { $$ = ast_list_append($1, $3); }
  ;

primary_expr
  : IDENTIFIER
      { $$ = ast_make_identifier($1); }
  | NUMBER
      { $$ = ast_make_number_literal($1); }
  | STRING
      { $$ = ast_make_string_literal($1); }
  | TRUE
      { $$ = ast_make_boolean_literal(true); }
  | FALSE
      { $$ = ast_make_boolean_literal(false); }
  | NULL_T
      { $$ = ast_make_null_literal(); }
  | UNDEFINED
      { $$ = ast_make_undefined_literal(); }
  | '(' expr ')'
      { $$ = $2; }
  | array_literal
      { $$ = $1; }
  | object_literal
      { $$ = $1; }
  ;

expr_no_obj
    : assignment_expr_no_obj
            { $$ = $1; }
    | expr_no_obj ',' assignment_expr
            { $$ = ast_make_sequence($1, $3); }
    ;

assignment_expr_no_obj
  : postfix_expr_no_obj '=' assignment_expr
      { $$ = ast_make_assignment("=", $1, $3); }
  | postfix_expr_no_obj PLUS_ASSIGN assignment_expr
      { $$ = ast_make_assignment("+=", $1, $3); }
  | postfix_expr_no_obj MINUS_ASSIGN assignment_expr
      { $$ = ast_make_assignment("-=", $1, $3); }
  | postfix_expr_no_obj STAR_ASSIGN assignment_expr
      { $$ = ast_make_assignment("*=", $1, $3); }
  | postfix_expr_no_obj SLASH_ASSIGN assignment_expr
      { $$ = ast_make_assignment("/=", $1, $3); }
  | postfix_expr_no_obj PERCENT_ASSIGN assignment_expr
      { $$ = ast_make_assignment("%=", $1, $3); }
  | postfix_expr_no_obj AND_ASSIGN assignment_expr
      { $$ = ast_make_assignment("&=", $1, $3); }
  | postfix_expr_no_obj OR_ASSIGN assignment_expr
      { $$ = ast_make_assignment("|=", $1, $3); }
  | postfix_expr_no_obj XOR_ASSIGN assignment_expr
      { $$ = ast_make_assignment("^=", $1, $3); }
  | postfix_expr_no_obj LSHIFT_ASSIGN assignment_expr
      { $$ = ast_make_assignment("<<=", $1, $3); }
  | postfix_expr_no_obj RSHIFT_ASSIGN assignment_expr
      { $$ = ast_make_assignment(">>=", $1, $3); }
  | postfix_expr_no_obj URSHIFT_ASSIGN assignment_expr
      { $$ = ast_make_assignment(">>>=", $1, $3); }
  | conditional_expr_no_obj
      { $$ = $1; }
  ;

conditional_expr_no_obj
  : logical_or_expr_no_obj
      { $$ = $1; }
  | logical_or_expr_no_obj '?' assignment_expr ':' assignment_expr
      { $$ = ast_make_conditional($1, $3, $5); }
  ;

logical_or_expr_no_obj
  : logical_and_expr_no_obj
      { $$ = $1; }
  | logical_or_expr_no_obj OR logical_and_expr_no_obj
      { $$ = ast_make_binary("||", $1, $3); }
  ;

logical_and_expr_no_obj
  : bitwise_or_expr_no_obj
      { $$ = $1; }
  | logical_and_expr_no_obj AND bitwise_or_expr_no_obj
      { $$ = ast_make_binary("&&", $1, $3); }
  ;

bitwise_or_expr_no_obj
  : bitwise_xor_expr_no_obj
      { $$ = $1; }
  | bitwise_or_expr_no_obj '|' bitwise_xor_expr_no_obj
      { $$ = ast_make_binary("|", $1, $3); }
  ;

bitwise_xor_expr_no_obj
  : bitwise_and_expr_no_obj
      { $$ = $1; }
  | bitwise_xor_expr_no_obj '^' bitwise_and_expr_no_obj
      { $$ = ast_make_binary("^", $1, $3); }
  ;

bitwise_and_expr_no_obj
  : equality_expr_no_obj
      { $$ = $1; }
  | bitwise_and_expr_no_obj '&' equality_expr_no_obj
      { $$ = ast_make_binary("&", $1, $3); }
  ;

equality_expr_no_obj
  : relational_expr_no_obj
      { $$ = $1; }
  | equality_expr_no_obj EQ relational_expr_no_obj
      { $$ = ast_make_binary("==", $1, $3); }
  | equality_expr_no_obj NE relational_expr_no_obj
      { $$ = ast_make_binary("!=", $1, $3); }
  | equality_expr_no_obj EQ_STRICT relational_expr_no_obj
      { $$ = ast_make_binary("===", $1, $3); }
  | equality_expr_no_obj NE_STRICT relational_expr_no_obj
      { $$ = ast_make_binary("!==", $1, $3); }
  ;

relational_expr_no_obj
  : shift_expr_no_obj
      { $$ = $1; }
  | relational_expr_no_obj '<' shift_expr_no_obj
      { $$ = ast_make_binary("<", $1, $3); }
  | relational_expr_no_obj '>' shift_expr_no_obj
      { $$ = ast_make_binary(">", $1, $3); }
  | relational_expr_no_obj LE shift_expr_no_obj
      { $$ = ast_make_binary("<=", $1, $3); }
  | relational_expr_no_obj GE shift_expr_no_obj
      { $$ = ast_make_binary(">=", $1, $3); }
  ;

shift_expr_no_obj
  : additive_expr_no_obj
      { $$ = $1; }
  | shift_expr_no_obj LSHIFT additive_expr_no_obj
      { $$ = ast_make_binary("<<", $1, $3); }
  | shift_expr_no_obj RSHIFT additive_expr_no_obj
      { $$ = ast_make_binary(">>", $1, $3); }
  | shift_expr_no_obj URSHIFT additive_expr_no_obj
      { $$ = ast_make_binary(">>>", $1, $3); }
  ;

additive_expr_no_obj
  : multiplicative_expr_no_obj
      { $$ = $1; }
  | additive_expr_no_obj '+' multiplicative_expr_no_obj
      { $$ = ast_make_binary("+", $1, $3); }
  | additive_expr_no_obj '-' multiplicative_expr_no_obj
      { $$ = ast_make_binary("-", $1, $3); }
  ;

multiplicative_expr_no_obj
  : unary_expr_no_obj
      { $$ = $1; }
  | multiplicative_expr_no_obj '*' unary_expr_no_obj
      { $$ = ast_make_binary("*", $1, $3); }
  | multiplicative_expr_no_obj '/' unary_expr_no_obj
      { $$ = ast_make_binary("/", $1, $3); }
  | multiplicative_expr_no_obj '%' unary_expr_no_obj
      { $$ = ast_make_binary("%", $1, $3); }
  ;

unary_expr_no_obj
  : postfix_expr_no_obj
      { $$ = $1; }
  | '+' unary_expr_no_obj
      { $$ = ast_make_unary("+", $2); }
  | '-' unary_expr_no_obj %prec UMINUS
      { $$ = ast_make_unary("-", $2); }
  | '!' unary_expr_no_obj
      { $$ = ast_make_unary("!", $2); }
  | '~' unary_expr_no_obj
      { $$ = ast_make_unary("~", $2); }
  | TYPEOF unary_expr_no_obj
      { $$ = ast_make_unary("typeof", $2); }
  | DELETE unary_expr_no_obj
      { $$ = ast_make_unary("delete", $2); }
  | VOID unary_expr_no_obj
      { $$ = ast_make_unary("void", $2); }
  | PLUS_PLUS unary_expr_no_obj
      { $$ = ast_make_update("++", $2, true); }
  | MINUS_MINUS unary_expr_no_obj
      { $$ = ast_make_update("--", $2, true); }
  ;

postfix_expr_no_obj
  : primary_no_obj
      { $$ = $1; }
  | postfix_expr_no_obj '.' IDENTIFIER
      { $$ = ast_make_member($1, $3, false); }
  | postfix_expr_no_obj '(' opt_arg_list ')'
      { $$ = ast_make_call($1, $3); }
  | postfix_expr_no_obj PLUS_PLUS
      { $$ = ast_make_update("++", $1, false); }
  | postfix_expr_no_obj MINUS_MINUS
      { $$ = ast_make_update("--", $1, false); }
  ;

primary_no_obj
  : IDENTIFIER
      { $$ = ast_make_identifier($1); }
  | NUMBER
      { $$ = ast_make_number_literal($1); }
  | STRING
      { $$ = ast_make_string_literal($1); }
  | TRUE
      { $$ = ast_make_boolean_literal(true); }
  | FALSE
      { $$ = ast_make_boolean_literal(false); }
  | NULL_T
      { $$ = ast_make_null_literal(); }
  | UNDEFINED
      { $$ = ast_make_undefined_literal(); }
  | '(' expr ')'
      { $$ = $2; }
  | array_literal
      { $$ = $1; }
  ;

array_literal
  : '[' ']'
      { $$ = ast_make_array_literal(NULL); }
  | '[' el_list opt_trailing_comma ']'
      { $$ = ast_make_array_literal($2); }
  ;

el_list
  : assignment_expr
      { $$ = ast_list_append(NULL, $1); }
  | el_list ',' assignment_expr
      { $$ = ast_list_append($1, $3); }
  ;

opt_trailing_comma
  : /* empty */
  | ','
  ;

object_literal
  : '{' '}'
      { $$ = ast_make_object_literal(NULL); }
  | '{' prop_list opt_trailing_comma '}'
      { $$ = ast_make_object_literal($2); }
  ;

prop_list
  : prop
      { $$ = ast_list_append(NULL, $1); }
  | prop_list ',' prop
      { $$ = ast_list_append($1, $3); }
  ;

prop
  : IDENTIFIER ':' assignment_expr
      { $$ = ast_make_property($1, true, $3); }
  | STRING ':' assignment_expr
      { $$ = ast_make_property($1, false, $3); }
  ;

%%

ASTNode *parser_take_ast(void) {
    ASTNode *root = g_parser_ast_root;
    g_parser_ast_root = NULL;
    return root;
}

void yyerror(const char *s) {
    g_parser_error_count++;
    fprintf(stderr, "Syntax error #%d: %s\n", g_parser_error_count, s);
}

void parser_reset_error_count(void) {
    g_parser_error_count = 0;
}

int parser_error_count(void) {
    return g_parser_error_count;
}
