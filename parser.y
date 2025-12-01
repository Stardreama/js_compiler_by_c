/*
 * JavaScript 语法分析器（Bison）
 * 现支持在语义动作中构建 AST，并可通过 --dump-ast 选项输出树结构。
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "diagnostics.h"

int yylex(void);
void yyerror(const char *s);

static ASTNode *g_parser_ast_root = NULL;
static int g_parser_error_count = 0;

static ASTNode *make_template_string_node(char *text) {
    return ast_make_string_literal_raw(text);
}

static ASTNode *build_template_concatenation(ASTList *parts) {
    ASTNode *result = NULL;
    ASTList *iter = parts;
    while (iter) {
        if (!result) {
            result = iter->node;
        } else {
            result = ast_make_binary("+", result, iter->node);
        }
        ASTList *next = iter->next;
        free(iter);
        iter = next;
    }
    if (!result) {
        return ast_make_string_literal_raw(NULL);
    }
    return result;
}
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
    struct {
        ASTNode *body;
        bool is_expression;
    } arrow;
}

%token VAR LET CONST FUNCTION IF ELSE FOR RETURN
%token WHILE DO BREAK CONTINUE
%token SWITCH CASE DEFAULT TRY CATCH FINALLY THROW NEW THIS TYPEOF DELETE IN INSTANCEOF VOID WITH DEBUGGER

%token TRUE FALSE NULL_T UNDEFINED
%token <str> IDENTIFIER NUMBER STRING REGEX TEMPLATE_NO_SUB TEMPLATE_HEAD TEMPLATE_MIDDLE TEMPLATE_TAIL

%token PLUS_PLUS MINUS_MINUS
%token EQ NE EQ_STRICT NE_STRICT
%token LE GE AND OR
%token LSHIFT RSHIFT URSHIFT
%token PLUS_ASSIGN MINUS_ASSIGN STAR_ASSIGN SLASH_ASSIGN PERCENT_ASSIGN
%token AND_ASSIGN OR_ASSIGN XOR_ASSIGN LSHIFT_ASSIGN RSHIFT_ASSIGN URSHIFT_ASSIGN
%token ARROW ELLIPSIS

%define parse.error verbose
%right '=' PLUS_ASSIGN MINUS_ASSIGN STAR_ASSIGN SLASH_ASSIGN PERCENT_ASSIGN AND_ASSIGN OR_ASSIGN XOR_ASSIGN LSHIFT_ASSIGN RSHIFT_ASSIGN URSHIFT_ASSIGN
%right '?' ':'
%left OR
%left AND
%left '|'
%left '^'
%left '&'
%left EQ NE EQ_STRICT NE_STRICT
%left '<' '>' LE GE INSTANCEOF IN
%left LSHIFT RSHIFT URSHIFT
%left '+' '-'
%left '*' '/' '%'
%right NEW
%right UMINUS '!' '~' TYPEOF DELETE VOID PLUS_PLUS MINUS_MINUS

%type <node> program stmt block var_stmt return_stmt if_stmt for_stmt while_stmt do_stmt switch_stmt try_stmt with_stmt labeled_stmt break_stmt continue_stmt throw_stmt func_decl for_init for_in_left opt_expr catch_clause finally_clause finally_clause_opt switch_case var_decl
%type <node> expr assignment_expr conditional_expr logical_or_expr logical_and_expr bitwise_or_expr bitwise_xor_expr bitwise_and_expr equality_expr relational_expr relational_expr_in shift_expr additive_expr multiplicative_expr unary_expr postfix_expr primary_expr function_expr new_expr template_literal
%type <node> expr_no_obj assignment_expr_no_obj conditional_expr_no_obj logical_or_expr_no_obj logical_and_expr_no_obj bitwise_or_expr_no_obj bitwise_xor_expr_no_obj bitwise_and_expr_no_obj equality_expr_no_obj relational_expr_no_obj relational_expr_no_obj_in shift_expr_no_obj additive_expr_no_obj multiplicative_expr_no_obj unary_expr_no_obj postfix_expr_no_obj primary_no_obj
%type <node> binding_element binding_initializer_opt object_binding array_binding binding_property binding_rest_property binding_rest_element assignment_pattern object_assignment_pattern array_assignment_pattern assignment_property assignment_element assignment_rest_element assignment_target for_binding for_binding_declarator catch_parameter rest_param
%type <node> arrow_function
%type <arrow> arrow_body
%type <node> array_literal object_literal prop

%type <str> property_name property_name_keyword

%type <list> stmt_list opt_param_list param_list param_list_items opt_arg_list arg_list el_list prop_list switch_case_list case_stmt_seq var_decl_list template_part_list binding_property_list binding_property_sequence binding_element_list assignment_property_list assignment_property_sequence assignment_element_list

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
  : VAR var_decl_list
      { $$ = ast_make_var_stmt(AST_VAR_KIND_VAR, $2); }
  | LET var_decl_list
      { $$ = ast_make_var_stmt(AST_VAR_KIND_LET, $2); }
  | CONST var_decl_list
      { $$ = ast_make_var_stmt(AST_VAR_KIND_CONST, $2); }
  ;

var_decl_list
  : var_decl
      { $$ = ast_list_append(NULL, $1); }
  | var_decl_list ',' var_decl
      { $$ = ast_list_append($1, $3); }
  ;

var_decl
  : IDENTIFIER binding_initializer_opt
      { $$ = ast_make_var_decl(ast_make_binding_pattern(ast_make_identifier($1), $2)); }
  | object_binding '=' assignment_expr
      { $$ = ast_make_var_decl(ast_make_binding_pattern($1, $3)); }
  | array_binding '=' assignment_expr
      { $$ = ast_make_var_decl(ast_make_binding_pattern($1, $3)); }
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
  | FOR '(' for_in_left IN expr ')' stmt
      { $$ = ast_make_for_in($3, $5, $7); }
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
    | expr_no_obj
      { $$ = $1; }
  ;

for_in_left
  : for_binding
      { $$ = $1; }
  | assignment_pattern
      { $$ = $1; }
  | assignment_expr_no_obj
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
  : param_list_items
      { $$ = $1; }
  | param_list_items ',' rest_param
      { $$ = ast_list_append($1, $3); }
  | rest_param
      { $$ = ast_list_append(NULL, $1); }
  ;

param_list_items
  : binding_element
      { $$ = ast_list_append(NULL, $1); }
  | param_list_items ',' binding_element
      { $$ = ast_list_append($1, $3); }
  ;

rest_param
  : binding_rest_element
      { $$ = $1; }
  ;

catch_clause
    : CATCH '(' catch_parameter ')' block
        { $$ = ast_make_catch($3, $5); }
    ;

catch_parameter
    : IDENTIFIER
        { $$ = ast_make_binding_pattern(ast_make_identifier($1), NULL); }
    | object_binding
        { $$ = ast_make_binding_pattern($1, NULL); }
    | array_binding
        { $$ = ast_make_binding_pattern($1, NULL); }
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
  | arrow_function
      { $$ = $1; }
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
  | relational_expr INSTANCEOF shift_expr
      { $$ = ast_make_binary("instanceof", $1, $3); }
  | relational_expr_in
      { $$ = $1; }
  ;

relational_expr_in
  : shift_expr IN shift_expr
      { $$ = ast_make_binary("in", $1, $3); }
  | relational_expr_in IN shift_expr
      { $$ = ast_make_binary("in", $1, $3); }
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
  | postfix_expr '.' property_name
      { $$ = ast_make_member($1, ast_make_identifier($3), false); }
  | postfix_expr '[' expr ']'
      { $$ = ast_make_member($1, $3, true); }
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
  | THIS
        { $$ = ast_make_this_expr(); }
  | NUMBER
      { $$ = ast_make_number_literal($1); }
  | STRING
      { $$ = ast_make_string_literal($1); }
  | REGEX
      { $$ = ast_make_regex_literal($1); }
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
  | template_literal
      { $$ = $1; }
  | '(' function_expr ')'
      { $$ = $2; }
  | function_expr
      { $$ = $1; }
  | new_expr
      { $$ = $1; }
  ;

function_expr
  : FUNCTION IDENTIFIER '(' opt_param_list ')' block
      { $$ = ast_make_function_expr($2, $4, $6); }
  | FUNCTION '(' opt_param_list ')' block
      { $$ = ast_make_function_expr(NULL, $3, $5); }
  ;

new_expr
  : NEW unary_expr
      { $$ = ast_make_new_expr($2, NULL); }
  | NEW unary_expr '(' opt_arg_list ')'
      { $$ = ast_make_new_expr($2, $4); }
  ;

expr_no_obj
    : assignment_expr_no_obj
            { $$ = $1; }
    | expr_no_obj ',' assignment_expr_no_obj
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
  | arrow_function
      { $$ = $1; }
  | conditional_expr_no_obj
      { $$ = $1; }
  ;

arrow_function
  : IDENTIFIER ARROW arrow_body
      {
          ASTList *params = NULL;
          ASTNode *binding = ast_make_binding_pattern(ast_make_identifier($1), NULL);
          params = ast_list_append(params, binding);
          $$ = ast_make_arrow_function(params, $3.body, $3.is_expression);
      }
  | '(' opt_param_list ')' ARROW arrow_body
      { $$ = ast_make_arrow_function($2, $5.body, $5.is_expression); }
  ;

arrow_body
  : assignment_expr
      {
          ASTList *stmts = NULL;
          stmts = ast_list_append(stmts, ast_make_return($1));
          $$.body = ast_make_block(stmts);
          $$.is_expression = true;
      }
  | block
      {
          $$.body = $1;
          $$.is_expression = false;
      }
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
  | relational_expr_no_obj INSTANCEOF shift_expr_no_obj
      { $$ = ast_make_binary("instanceof", $1, $3); }
  | relational_expr_no_obj_in
      { $$ = $1; }
  ;

relational_expr_no_obj_in
  : shift_expr_no_obj IN shift_expr_no_obj
      { $$ = ast_make_binary("in", $1, $3); }
  | relational_expr_no_obj_in IN shift_expr_no_obj
      { $$ = ast_make_binary("in", $1, $3); }
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
  | postfix_expr_no_obj '.' property_name
      { $$ = ast_make_member($1, ast_make_identifier($3), false); }
  | postfix_expr_no_obj '[' expr ']'
      { $$ = ast_make_member($1, $3, true); }
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
  | THIS
        { $$ = ast_make_this_expr(); }
  | NUMBER
      { $$ = ast_make_number_literal($1); }
  | STRING
      { $$ = ast_make_string_literal($1); }
  | REGEX
      { $$ = ast_make_regex_literal($1); }
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
  | template_literal
      { $$ = $1; }
  | '(' function_expr ')'
        { $$ = $2; }
  | function_expr
        { $$ = $1; }
  | new_expr
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

template_literal
  : TEMPLATE_NO_SUB
      { $$ = make_template_string_node($1); }
  | TEMPLATE_HEAD template_part_list
      {
          ASTList *parts = NULL;
          parts = ast_list_append(parts, make_template_string_node($1));
          parts = ast_list_concat(parts, $2);
          $$ = build_template_concatenation(parts);
      }
  ;

template_part_list
  : assignment_expr TEMPLATE_TAIL
      {
          ASTList *parts = NULL;
          parts = ast_list_append(parts, $1);
          parts = ast_list_append(parts, make_template_string_node($2));
          $$ = parts;
      }
  | assignment_expr TEMPLATE_MIDDLE template_part_list
      {
          ASTList *parts = NULL;
          parts = ast_list_append(parts, $1);
          parts = ast_list_append(parts, make_template_string_node($2));
          $$ = ast_list_concat(parts, $3);
      }
  ;

prop_list
  : prop
      { $$ = ast_list_append(NULL, $1); }
  | prop_list ',' prop
      { $$ = ast_list_append($1, $3); }
  ;

prop
  : property_name ':' assignment_expr
      { $$ = ast_make_property($1, true, $3); }
  | IDENTIFIER
      {
          ASTNode *id = ast_make_identifier($1);
          $$ = ast_make_property(strdup(id->data.identifier.name), true, id);
      }
  ;

property_name
    : IDENTIFIER { $$ = $1; }
    | property_name_keyword { $$ = $1; }
    ;

property_name_keyword
    : STRING     { $$ = $1; }
    | NUMBER     { $$ = $1; }
    | DEFAULT    { $$ = strdup("default"); }
    | IF         { $$ = strdup("if"); }
    | ELSE       { $$ = strdup("else"); }
    | FOR        { $$ = strdup("for"); }
    | WHILE      { $$ = strdup("while"); }
    | DO         { $$ = strdup("do"); }
    | FUNCTION   { $$ = strdup("function"); }
    | VAR        { $$ = strdup("var"); }
    | LET        { $$ = strdup("let"); }
    | CONST      { $$ = strdup("const"); }
    | RETURN     { $$ = strdup("return"); }
    | BREAK      { $$ = strdup("break"); }
    | CONTINUE   { $$ = strdup("continue"); }
    | SWITCH     { $$ = strdup("switch"); }
    | CASE       { $$ = strdup("case"); }
    | TRY        { $$ = strdup("try"); }
    | CATCH      { $$ = strdup("catch"); }
    | FINALLY    { $$ = strdup("finally"); }
    | THROW      { $$ = strdup("throw"); }
    | NEW        { $$ = strdup("new"); }
    | THIS       { $$ = strdup("this"); }
    | TYPEOF     { $$ = strdup("typeof"); }
    | DELETE     { $$ = strdup("delete"); }
    | IN         { $$ = strdup("in"); }
    | INSTANCEOF { $$ = strdup("instanceof"); }
    | VOID       { $$ = strdup("void"); }
    | WITH       { $$ = strdup("with"); }
    | DEBUGGER   { $$ = strdup("debugger"); }
    | TRUE       { $$ = strdup("true"); }
    | FALSE      { $$ = strdup("false"); }
    | NULL_T     { $$ = strdup("null"); }
    | UNDEFINED  { $$ = strdup("undefined"); }
    ;

binding_initializer_opt
  : /* empty */
      { $$ = NULL; }
  | '=' assignment_expr
      { $$ = $2; }
  ;

binding_element
  : IDENTIFIER binding_initializer_opt
      { $$ = ast_make_binding_pattern(ast_make_identifier($1), $2); }
  | object_binding binding_initializer_opt
      { $$ = ast_make_binding_pattern($1, $2); }
  | array_binding binding_initializer_opt
      { $$ = ast_make_binding_pattern($1, $2); }
  ;

object_binding
  : '{' '}'
      { $$ = ast_make_object_binding(NULL); }
  | '{' binding_property_sequence '}'
      { $$ = ast_make_object_binding($2); }
  ;

binding_property_sequence
  : binding_property_list opt_trailing_comma
      { $$ = $1; }
  | binding_property_list ',' binding_rest_property
      { $$ = ast_list_append($1, $3); }
  | binding_rest_property
      { $$ = ast_list_append(NULL, $1); }
  ;

binding_property_list
  : binding_property
      { $$ = ast_list_append(NULL, $1); }
  | binding_property_list ',' binding_property
      { $$ = ast_list_append($1, $3); }
  ;

binding_property
  : IDENTIFIER ':' binding_element
      { $$ = ast_make_binding_property($1, true, $3, false); }
  | property_name_keyword ':' binding_element
      { $$ = ast_make_binding_property($1, false, $3, false); }
  | IDENTIFIER binding_initializer_opt
      {
          ASTNode *id = ast_make_identifier($1);
          ASTNode *pattern = ast_make_binding_pattern(id, $2);
          char *key_copy = strdup(id->data.identifier.name);
          $$ = ast_make_binding_property(key_copy, true, pattern, true);
      }
  ;

binding_rest_property
  : ELLIPSIS IDENTIFIER
      { $$ = ast_make_rest_element(ast_make_identifier($2)); }
  ;

array_binding
  : '[' ']'
      { $$ = ast_make_array_binding(NULL); }
  | '[' binding_element_list opt_trailing_comma ']'
      { $$ = ast_make_array_binding($2); }
  | '[' binding_element_list ',' binding_rest_element opt_trailing_comma ']'
      { $$ = ast_make_array_binding(ast_list_append($2, $4)); }
  | '[' binding_rest_element opt_trailing_comma ']'
      { ASTList *list = NULL; list = ast_list_append(list, $2); $$ = ast_make_array_binding(list); }
  ;

binding_element_list
  : binding_element
      { $$ = ast_list_append(NULL, $1); }
  | binding_element_list ',' binding_element
      { $$ = ast_list_append($1, $3); }
  ;

binding_rest_element
  : ELLIPSIS IDENTIFIER
      { $$ = ast_make_rest_element(ast_make_identifier($2)); }
  ;

assignment_target
  : postfix_expr %dprec 1
      { $$ = $1; }
  | object_assignment_pattern %dprec 2
      { $$ = $1; }
  | array_assignment_pattern %dprec 2
      { $$ = $1; }
  ;

assignment_target_no_obj
  : postfix_expr_no_obj %dprec 1
      { $$ = $1; }
  | object_assignment_pattern %dprec 2
      { $$ = $1; }
  | array_assignment_pattern %dprec 2
      { $$ = $1; }
  ;
  | assignment_property_list ',' assignment_rest_element
      { $$ = ast_list_append($1, $3); }
  | assignment_rest_element
      { $$ = ast_list_append(NULL, $1); }
  ;

assignment_property_list
  : assignment_property
      { $$ = ast_list_append(NULL, $1); }
  | assignment_property_list ',' assignment_property
      { $$ = ast_list_append($1, $3); }
  ;

assignment_property
  : IDENTIFIER ':' assignment_element
      { $$ = ast_make_binding_property($1, true, $3, false); }
  | property_name_keyword ':' assignment_element
      { $$ = ast_make_binding_property($1, false, $3, false); }
  | IDENTIFIER binding_initializer_opt
      {
          ASTNode *id = ast_make_identifier($1);
          ASTNode *pattern = ast_make_binding_pattern(id, $2);
          char *key_copy = strdup(id->data.identifier.name);
          $$ = ast_make_binding_property(key_copy, true, pattern, true);
      }
  ;

assignment_rest_element
  : ELLIPSIS postfix_expr
      { $$ = ast_make_rest_element($2); }
  ;

array_assignment_pattern
  : '[' ']'
      { $$ = ast_make_array_binding(NULL); }
  | '[' assignment_element_list opt_trailing_comma ']'
      { $$ = ast_make_array_binding($2); }
  | '[' assignment_element_list ',' assignment_rest_element opt_trailing_comma ']'
      { $$ = ast_make_array_binding(ast_list_append($2, $4)); }
  | '[' assignment_rest_element opt_trailing_comma ']'
      { ASTList *list = NULL; list = ast_list_append(list, $2); $$ = ast_make_array_binding(list); }
  ;

assignment_element_list
  : assignment_element
      { $$ = ast_list_append(NULL, $1); }
  | assignment_element_list ',' assignment_element
      { $$ = ast_list_append($1, $3); }
  ;

assignment_element
  : assignment_target binding_initializer_opt
      { $$ = ast_make_binding_pattern($1, $2); }
  ;

assignment_target
  : postfix_expr
      { $$ = $1; }
  | object_assignment_pattern
      { $$ = $1; }
  | array_assignment_pattern
      { $$ = $1; }
  ;

for_binding
  : VAR for_binding_declarator
      { ASTList *list = NULL; list = ast_list_append(list, $2); $$ = ast_make_var_stmt(AST_VAR_KIND_VAR, list); }
  | LET for_binding_declarator
      { ASTList *list = NULL; list = ast_list_append(list, $2); $$ = ast_make_var_stmt(AST_VAR_KIND_LET, list); }
  | CONST for_binding_declarator
      { ASTList *list = NULL; list = ast_list_append(list, $2); $$ = ast_make_var_stmt(AST_VAR_KIND_CONST, list); }
  ;

for_binding_declarator
  : IDENTIFIER
      { $$ = ast_make_var_decl(ast_make_binding_pattern(ast_make_identifier($1), NULL)); }
  | object_binding
      { $$ = ast_make_var_decl(ast_make_binding_pattern($1, NULL)); }
  | array_binding
      { $$ = ast_make_var_decl(ast_make_binding_pattern($1, NULL)); }
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
    diag_record_error(s);
}

void parser_reset_error_count(void) {
    g_parser_error_count = 0;
}

int parser_error_count(void) {
    return g_parser_error_count;
}
