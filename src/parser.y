/*
 * JavaScript 语法分析器（Bison）
 * 现支持在语义动作中构建 AST，并可通过 --dump-ast 选项输出树结构。
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "ast.h"
#include "diagnostics.h"
#include "postfix_suffix.h"


int yylex(void);
void yyerror(const char *s);

#ifndef YYMAXDEPTH
#define YYMAXDEPTH 1000000 /* Allow deeper GLR stacks for dense member/call chains */
#endif

#ifndef YYINITDEPTH
#define YYINITDEPTH 16000   /* Start with a larger pool to reduce early reallocations */
#endif

static ASTNode *g_parser_ast_root = NULL;
static int g_parser_error_count = 0;
static bool g_parser_module_mode = true;
static char *dup_string(const char *text);

#ifndef JS_METHOD_INFO_DEFINED
#define JS_METHOD_INFO_DEFINED
typedef struct MethodInfo {
    char *name;
    ASTNode *computed_key;
    bool computed;
    bool is_generator;
    bool is_async;
    bool is_static;
    ASTMethodKind kind;
} MethodInfo;
#endif

static ASTNode *wrap_destructuring_target(ASTNode *target) {
    if (!target) {
        return NULL;
    }
    if (target->type == AST_OBJECT_BINDING || target->type == AST_ARRAY_BINDING) {
        return ast_make_binding_pattern(target, NULL);
    }
    return target;
}

static ASTNode *make_binding_with_initializer(ASTNode *target, ASTNode *initializer);
static ASTNode *convert_assignment_target(ASTNode *expr, bool allow_object_literal);
static ASTNode *convert_array_literal_to_binding(ASTNode *expr, bool allow_object_literal);
static ASTNode *convert_object_literal_to_binding(ASTNode *expr);

static ASTNode *make_binding_with_initializer(ASTNode *target, ASTNode *initializer) {
    if (!target) {
        return NULL;
    }
    if (target->type == AST_BINDING_PATTERN) {
        if (initializer && !target->data.binding_pattern.initializer) {
            target->data.binding_pattern.initializer = initializer;
        }
        return target;
    }
    return ast_make_binding_pattern(target, initializer);
}

static ASTNode *convert_assignment_target(ASTNode *expr, bool allow_object_literal) {
    if (!expr) {
        return NULL;
    }
    switch (expr->type) {
        case AST_IDENTIFIER:
            return expr;
        case AST_ARRAY_LITERAL:
            return convert_array_literal_to_binding(expr, allow_object_literal);
        case AST_OBJECT_LITERAL:
            return allow_object_literal ? convert_object_literal_to_binding(expr) : NULL;
        case AST_ASSIGN_EXPR:
            if (expr->data.assign.op && strcmp(expr->data.assign.op, "=") == 0) {
                ASTNode *lhs = convert_assignment_target(expr->data.assign.left, allow_object_literal);
                if (!lhs) {
                    return NULL;
                }
                return make_binding_with_initializer(lhs, expr->data.assign.right);
            }
            return NULL;
        default:
            return NULL;
    }
}

static ASTNode *convert_array_literal_to_binding(ASTNode *expr, bool allow_object_literal) {
    if (!expr || expr->type != AST_ARRAY_LITERAL) {
        return NULL;
    }
    ASTList *converted = NULL;
    ASTList *elem = expr->data.array_literal.elements;
    while (elem) {
        ASTNode *item = elem->node;
        if (!item) {
            elem = elem->next;
            continue;
        }
        ASTNode *converted_item = NULL;
        if (item->type == AST_ARRAY_HOLE) {
            converted_item = ast_make_array_hole();
        } else if (item->type == AST_SPREAD_ELEMENT) {
            ASTNode *rest_target = convert_assignment_target(item->data.spread_element.argument, allow_object_literal);
            if (!rest_target) {
                return NULL;
            }
            converted_item = ast_make_rest_element(rest_target);
        } else {
            ASTNode *init = NULL;
            ASTNode *value = item;
            if (item->type == AST_ASSIGN_EXPR && item->data.assign.op &&
                strcmp(item->data.assign.op, "=") == 0) {
                value = item->data.assign.left;
                init = item->data.assign.right;
            }
            ASTNode *target = convert_assignment_target(value, allow_object_literal);
            if (!target) {
                return NULL;
            }
            converted_item = make_binding_with_initializer(target, init);
        }
        converted = ast_list_append(converted, converted_item);
        elem = elem->next;
    }
    return ast_make_array_binding(converted);
}

static ASTNode *convert_object_literal_to_binding(ASTNode *expr) {
    if (!expr || expr->type != AST_OBJECT_LITERAL) {
        return NULL;
    }
    ASTList *converted = NULL;
    for (ASTList *prop = expr->data.object_literal.properties; prop; prop = prop->next) {
        ASTNode *item = prop->node;
        if (!item) {
            continue;
        }
        if (item->type == AST_SPREAD_ELEMENT) {
            ASTNode *rest_target = convert_assignment_target(item->data.spread_element.argument, true);
            if (!rest_target) {
                return NULL;
            }
            converted = ast_list_append(converted, ast_make_rest_element(rest_target));
            continue;
        }
        if (item->type != AST_PROPERTY) {
            return NULL;
        }
        bool is_identifier_key = item->data.property.key.is_identifier;
        char *key_copy = dup_string(item->data.property.key.name);
        ASTNode *value = item->data.property.value;
        ASTNode *init = NULL;
        ASTNode *binding_target = NULL;
        if (value && value->type == AST_ASSIGN_EXPR && value->data.assign.op &&
            strcmp(value->data.assign.op, "=") == 0) {
            binding_target = convert_assignment_target(value->data.assign.left, true);
            init = value->data.assign.right;
        } else {
            binding_target = convert_assignment_target(value, true);
        }
        if (!binding_target) {
            return NULL;
        }
        ASTNode *binding_value = make_binding_with_initializer(binding_target, init);
        bool shorthand = false;
        if (is_identifier_key && value && value->type == AST_IDENTIFIER && item->data.property.key.name) {
            shorthand = strcmp(item->data.property.key.name, value->data.identifier.name) == 0;
        }
        converted = ast_list_append(converted,
                                    ast_make_binding_property(key_copy, is_identifier_key, binding_value, shorthand));
    }
    return ast_make_object_binding(converted);
}

static PostfixSuffix *alloc_suffix(PostfixSuffixKind kind) {
    PostfixSuffix *suffix = (PostfixSuffix *)calloc(1, sizeof(PostfixSuffix));
    if (!suffix) {
        fprintf(stderr, "Out of memory while building postfix suffix chain\n");
        exit(EXIT_FAILURE);
    }
        suffix->kind = kind;
        return suffix;
}

static PostfixSuffix *make_suffix_prop(char *name) {
    PostfixSuffix *suffix = alloc_suffix(POSTFIX_SUFFIX_PROP);
    suffix->data.property_name = name;
    return suffix;
}

static PostfixSuffix *make_suffix_computed(ASTNode *expr) {
    PostfixSuffix *suffix = alloc_suffix(POSTFIX_SUFFIX_COMPUTED);
    suffix->data.computed_expr = expr;
    return suffix;
}

static PostfixSuffix *make_suffix_call(ASTList *args) {
    PostfixSuffix *suffix = alloc_suffix(POSTFIX_SUFFIX_CALL);
    suffix->data.arguments = args;
    return suffix;
}

static PostfixSuffix *make_suffix_template(ASTNode *literal) {
    PostfixSuffix *suffix = alloc_suffix(POSTFIX_SUFFIX_TEMPLATE);
    suffix->data.template_literal = literal;
    return suffix;
}

static PostfixSuffix *append_suffix(PostfixSuffix *list, PostfixSuffix *item) {
    if (!item) {
        return list;
    }
    item->next = NULL;
    if (!list) {
        return item;
    }
    PostfixSuffix *tail = list;
    while (tail->next) {
        tail = tail->next;
    }
    tail->next = item;
    return list;
}

static ASTNode *apply_suffix_chain(ASTNode *base, PostfixSuffix *chain) {
    PostfixSuffix *current = chain;
    while (current) {
        PostfixSuffix *next = current->next;
        switch (current->kind) {
            case POSTFIX_SUFFIX_PROP:
                base = ast_make_member(base, ast_make_identifier(current->data.property_name), false);
                break;
            case POSTFIX_SUFFIX_COMPUTED:
                base = ast_make_member(base, current->data.computed_expr, true);
                break;
            case POSTFIX_SUFFIX_CALL:
                base = ast_make_call(base, current->data.arguments);
                break;
            case POSTFIX_SUFFIX_TEMPLATE:
                base = ast_make_tagged_template(base, current->data.template_literal);
                break;
        }
        free(current);
        current = next;
    }
    return base;
}

static char *dup_string(const char *text) {
    if (!text) {
        return NULL;
    }
    size_t len = strlen(text);
    char *copy = (char *)malloc(len + 1);
    if (!copy) {
        fprintf(stderr, "Out of memory while duplicating string\n");
        exit(EXIT_FAILURE);
    }
    memcpy(copy, text, len + 1);
    return copy;
}

static MethodInfo method_info_from_name(char *name) {
    MethodInfo info;
    info.name = name;
    info.computed_key = NULL;
    info.computed = false;
    info.is_generator = false;
    info.is_async = false;
    info.is_static = false;
    info.kind = AST_METHOD_KIND_NORMAL;
    return info;
}

static MethodInfo method_info_from_computed(ASTNode *expr) {
    MethodInfo info;
    info.name = NULL;
    info.computed_key = expr;
    info.computed = true;
    info.is_generator = false;
    info.is_async = false;
    info.is_static = false;
    info.kind = AST_METHOD_KIND_NORMAL;
    return info;
}

static ASTList *make_single_param_list(ASTNode *param) {
    ASTList *list = NULL;
    return ast_list_append(list, param);
}

static ASTNode *build_method_node(MethodInfo *info, ASTList *params, ASTNode *body) {
    char *func_name = dup_string(info->name);
    ASTNode *func = ast_make_function_expr(func_name, params, body);
    if (info->is_generator && func) {
        func->data.function_expr.is_generator = true;
    }
    if (info->is_async && func) {
        func->data.function_expr.is_async = true;
    }
    return ast_make_method_def(info->name,
                              info->computed_key,
                              info->computed,
                              info->is_static,
                              info->is_generator,
                              info->is_async,
                              info->kind,
                              func);
}

static bool identifier_is(const char *text, const char *target) {
    if (!text || !target) {
        return false;
    }
    return strcmp(text, target) == 0;
}

static ASTNode *mark_method_static(ASTNode *method) {
    if (method && method->type == AST_METHOD_DEF) {
        if (method->data.method_def.kind == AST_METHOD_KIND_CONSTRUCTOR) {
            yyerror("Class constructor cannot be static");
            ast_free(method);
            return NULL;
        }
        method->data.method_def.is_static = true;
    }
    return method;
}

static ASTNode *maybe_tag_constructor(ASTNode *method) {
    if (!method || method->type != AST_METHOD_DEF) {
        return method;
    }
    if (!method->data.method_def.computed &&
        method->data.method_def.name &&
        identifier_is(method->data.method_def.name, "constructor") &&
        !method->data.method_def.is_static) {
        method->data.method_def.kind = AST_METHOD_KIND_CONSTRUCTOR;
    }
    return method;
}

static size_t count_method_params(ASTNode *method) {
    if (!method || method->type != AST_METHOD_DEF) {
        return (size_t)-1;
    }
    ASTNode *func = method->data.method_def.function;
    if (!func || func->type != AST_FUNCTION_EXPR) {
        return (size_t)-1;
    }
    size_t count = 0;
    ASTList *param = func->data.function_expr.params;
    while (param) {
        ++count;
        param = param->next;
    }
    return count;
}

static ASTNode *apply_accessor_keyword(ASTNode *method, const char *keyword) {
    if (!method) {
        return NULL;
    }
    ASTMethodKind kind;
    if (identifier_is(keyword, "get")) {
        kind = AST_METHOD_KIND_GET;
    } else if (identifier_is(keyword, "set")) {
        kind = AST_METHOD_KIND_SET;
    } else {
        yyerror("Unexpected identifier before class element");
        ast_free(method);
        return NULL;
    }
    size_t param_count = count_method_params(method);
    if (kind == AST_METHOD_KIND_GET && param_count != 0) {
        yyerror("Getter must not have parameters");
        ast_free(method);
        return NULL;
    }
    if (kind == AST_METHOD_KIND_SET && param_count != 1) {
        yyerror("Setter must have exactly one parameter");
        ast_free(method);
        return NULL;
    }
    method->data.method_def.kind = kind;
    return method;
}

static ASTNode *handle_single_prefix(char *prefix, ASTNode *method) {
    ASTNode *result = maybe_tag_constructor(method);
    if (identifier_is(prefix, "static")) {
        result = mark_method_static(result);
    } else if (identifier_is(prefix, "get") || identifier_is(prefix, "set")) {
        result = apply_accessor_keyword(result, prefix);
    } else {
        yyerror("Unexpected identifier before class element");
        ast_free(result);
        result = NULL;
    }
    free(prefix);
    return result;
}

static ASTNode *handle_double_prefix(char *first, char *second, ASTNode *method) {
    ASTNode *result = maybe_tag_constructor(method);
    if (!identifier_is(first, "static")) {
        yyerror("Unexpected identifier before class element");
        ast_free(result);
        free(first);
        free(second);
        return NULL;
    }
    result = mark_method_static(result);
    free(first);
    if (!result) {
        free(second);
        return NULL;
    }
    if (!(identifier_is(second, "get") || identifier_is(second, "set"))) {
        yyerror("Unexpected identifier before class element");
        ast_free(result);
        free(second);
        return NULL;
    }
    result = apply_accessor_keyword(result, second);
    free(second);
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
    #include "postfix_suffix.h"
    #ifndef JS_METHOD_INFO_DEFINED
    #define JS_METHOD_INFO_DEFINED
    typedef struct MethodInfo {
        char *name;
        ASTNode *computed_key;
        bool computed;
        bool is_generator;
        bool is_async;
        bool is_static;
        ASTMethodKind kind;
    } MethodInfo;
    #endif
}

%union {
    ASTNode *node;
    ASTList *list;
    char *str;
    int boolean;
    PostfixSuffix *suffix;
    struct {
        ASTNode *body;
        bool is_expression;
    } arrow;
    struct {
        ASTList *quasis;
        ASTList *exprs;
    } template_parts;
    MethodInfo method;
}


%token VAR LET CONST FUNCTION FUNCTION_DECL IF ELSE FOR RETURN ASYNC AWAIT IMPORT EXPORT
%token WHILE DO BREAK CONTINUE
%token SWITCH CASE DEFAULT TRY CATCH FINALLY THROW NEW THIS TYPEOF DELETE IN INSTANCEOF VOID WITH DEBUGGER CLASS EXTENDS SUPER
%token YIELD

%token TRUE FALSE NULL_T UNDEFINED
%token <str> IDENTIFIER NUMBER STRING REGEX TEMPLATE_NO_SUB TEMPLATE_HEAD TEMPLATE_MIDDLE TEMPLATE_TAIL

%token PLUS_PLUS MINUS_MINUS
%token EQ NE EQ_STRICT NE_STRICT
%token LE GE AND OR
%token LSHIFT RSHIFT URSHIFT
%token PLUS_ASSIGN MINUS_ASSIGN STAR_ASSIGN SLASH_ASSIGN PERCENT_ASSIGN
%token AND_ASSIGN OR_ASSIGN XOR_ASSIGN LSHIFT_ASSIGN RSHIFT_ASSIGN URSHIFT_ASSIGN
%token ARROW ELLIPSIS ARROW_HEAD

%glr-parser
%define parse.error verbose
%define parse.trace true
%debug
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
%nonassoc IF_NO_ELSE
%nonassoc ELSE

%type <node> program module_item stmt block var_stmt var_stmt_no_in return_stmt if_stmt for_stmt while_stmt do_stmt switch_stmt try_stmt with_stmt labeled_stmt break_stmt continue_stmt throw_stmt func_decl for_init for_in_left opt_expr catch_clause finally_clause finally_clause_opt switch_case var_decl var_decl_no_in class_decl class_expr class_element method_definition getter_definition setter_definition computed_property class_heritage_opt import_stmt export_stmt import_default_binding namespace_import import_specifier module_specifier export_specifier
%type <node> expr assignment_expr assignment_expr_no_pattern conditional_expr logical_or_expr logical_and_expr bitwise_or_expr bitwise_xor_expr bitwise_and_expr equality_expr relational_expr shift_expr additive_expr multiplicative_expr unary_expr postfix_expr postfix_expr_no_arr left_hand_side_expr left_hand_side_expr_no_arr call_expr call_expr_no_arr member_expr member_expr_no_arr new_expr new_expr_no_arr primary_expr primary_no_arr function_expr template_literal
%type <node> assignment_expr_no_pattern_no_in conditional_expr_no_in logical_or_expr_no_in logical_and_expr_no_in bitwise_or_expr_no_in bitwise_xor_expr_no_in bitwise_and_expr_no_in equality_expr_no_in relational_expr_no_in
%type <node> expr_no_obj assignment_expr_no_obj assignment_expr_no_pattern_no_obj conditional_expr_no_obj logical_or_expr_no_obj logical_and_expr_no_obj bitwise_or_expr_no_obj bitwise_xor_expr_no_obj bitwise_and_expr_no_obj equality_expr_no_obj relational_expr_no_obj shift_expr_no_obj additive_expr_no_obj multiplicative_expr_no_obj unary_expr_no_obj postfix_expr_no_obj postfix_expr_no_obj_no_arr left_hand_side_expr_no_obj left_hand_side_expr_no_obj_no_arr member_expr_no_obj member_expr_no_obj_no_arr member_call_expr_no_obj member_call_expr_no_obj_no_arr new_expr_no_obj new_expr_no_obj_no_arr primary_no_obj primary_no_obj_no_arr object_literal_expr_no_obj
%type <node> expr_no_in_no_obj assignment_expr_no_in_no_obj assignment_expr_no_pattern_no_in_no_obj conditional_expr_no_obj_no_in logical_or_expr_no_obj_no_in logical_and_expr_no_obj_no_in bitwise_or_expr_no_obj_no_in bitwise_xor_expr_no_obj_no_in bitwise_and_expr_no_obj_no_in equality_expr_no_obj_no_in relational_expr_no_obj_no_in
%type <node> yield_expr spread_element el_item arg_item
%type <node> binding_element binding_initializer_opt binding_initializer_opt_no_in object_binding array_binding binding_property binding_rest_property binding_rest_element assignment_pattern object_assignment_pattern array_assignment_pattern assignment_property assignment_element assignment_rest_element assignment_target destructuring_assignment_target destructuring_assignment_target_no_obj for_binding for_binding_declarator catch_parameter rest_param
%type <node> arrow_function
%type <arrow> arrow_body
%type <node> array_literal object_literal prop
%type <method> method_name

%type <str> property_name property_name_keyword
%type <str> for_of_keyword from_keyword as_keyword

%type <suffix> member_suffix_seq member_noncall_suffix call_suffix_seq call_any_suffix call_suffix_initial


%type <list> stmt_list module_item_list opt_param_list param_list param_list_items opt_arg_list arg_list prop_list switch_case_list case_stmt_seq var_decl_list var_decl_list_no_in binding_property_list binding_property_sequence binding_element_list binding_elision binding_elision_opt assignment_property_list assignment_property_sequence assignment_element_list class_body class_element_list class_element_list_opt import_clause named_imports import_specifier_list export_clause export_specifier_list
%type <list> elision elision_opt element_list
%type <template_parts> template_part_list
%type <boolean> generator_marker_opt async_modifier_opt

%destructor { if ($$) free($$); } <str>
%destructor { if ($$.body) ast_free($$.body); } <arrow>
%destructor {
    if ($$.quasis) {
        ast_list_free($$.quasis);
    }
    if ($$.exprs) {
        ast_list_free($$.exprs);
    }
} <template_parts>
%destructor {
    if ($$.computed_key) {
        ast_free($$.computed_key);
    }
    if ($$.name) {
        free($$.name);
    }
} <method>

%%

program
  : module_item_list
      {
          $$ = ast_make_program($1);
          g_parser_ast_root = $$;
      }
  ;

module_item_list
  : /* empty */
      { $$ = NULL; }
  | module_item_list module_item
      { $$ = ast_list_append($1, $2); }
  ;

module_item
  : stmt
      { $$ = $1; }
  | import_stmt
      { $$ = $1; }
  | export_stmt
      { $$ = $1; }
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
  | class_decl
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

import_stmt
    : IMPORT import_clause from_keyword module_specifier ';'
      { $$ = ast_make_import_decl($2, $4); }
    | IMPORT module_specifier ';'
      { $$ = ast_make_import_decl(NULL, $2); }
  ;

import_clause
  : import_default_binding
      { $$ = ast_list_append(NULL, $1); }
  | namespace_import
      { $$ = ast_list_append(NULL, $1); }
  | named_imports
      { $$ = $1; }
  | import_default_binding ',' namespace_import
      { ASTList *list = ast_list_append(NULL, $1); $$ = ast_list_append(list, $3); }
  | import_default_binding ',' named_imports
      { ASTList *list = ast_list_append(NULL, $1); $$ = ast_list_concat(list, $3); }
  ;

named_imports
    : '{' '}'
            { $$ = NULL; }
    | '{' import_specifier_list opt_trailing_comma '}'
            { $$ = $2; }
    ;

import_specifier_list
  : import_specifier
      { $$ = ast_list_append(NULL, $1); }
  | import_specifier_list ',' import_specifier
      { $$ = ast_list_append($1, $3); }
  ;

import_specifier
  : IDENTIFIER
      { $$ = ast_make_import_specifier($1, dup_string($1), false, false); }
  | IDENTIFIER as_keyword IDENTIFIER
      { $$ = ast_make_import_specifier($3, $1, false, false); }
  | DEFAULT as_keyword IDENTIFIER
      { $$ = ast_make_import_specifier($3, dup_string("default"), false, false); }
  ;

import_default_binding
  : IDENTIFIER
      { $$ = ast_make_import_specifier($1, dup_string("default"), false, true); }
  ;

namespace_import
  : '*' as_keyword IDENTIFIER
      { $$ = ast_make_import_specifier($3, NULL, true, false); }
  ;

module_specifier
  : STRING
      { $$ = ast_make_string_literal($1); }
  ;

export_stmt
  : EXPORT export_clause from_keyword module_specifier ';'
      { $$ = ast_make_export_decl(false, false, NULL, NULL, $2, $4); }
  | EXPORT export_clause ';'
      { $$ = ast_make_export_decl(false, false, NULL, NULL, $2, NULL); }
  | EXPORT '*' from_keyword module_specifier ';'
      { $$ = ast_make_export_decl(false, true, NULL, NULL, NULL, $4); }
  | EXPORT '*' as_keyword IDENTIFIER from_keyword module_specifier ';'
      { $$ = ast_make_export_decl(false, true, $4, NULL, NULL, $6); }
  | EXPORT var_stmt ';'
      { $$ = ast_make_export_decl(false, false, NULL, $2, NULL, NULL); }
  | EXPORT func_decl
      { $$ = ast_make_export_decl(false, false, NULL, $2, NULL, NULL); }
  | EXPORT class_decl
      { $$ = ast_make_export_decl(false, false, NULL, $2, NULL, NULL); }
  | EXPORT DEFAULT func_decl
      { $$ = ast_make_export_decl(true, false, NULL, $3, NULL, NULL); }
  | EXPORT DEFAULT class_decl
      { $$ = ast_make_export_decl(true, false, NULL, $3, NULL, NULL); }
    | EXPORT DEFAULT assignment_expr_no_obj ';'
      { $$ = ast_make_export_decl(true, false, NULL, $3, NULL, NULL); }
  ;

export_clause
    : '{' '}'
            { $$ = NULL; }
    | '{' export_specifier_list opt_trailing_comma '}'
            { $$ = $2; }
    ;

export_specifier_list
  : export_specifier
      { $$ = ast_list_append(NULL, $1); }
  | export_specifier_list ',' export_specifier
      { $$ = ast_list_append($1, $3); }
  ;

export_specifier
  : IDENTIFIER
      { $$ = ast_make_export_specifier($1, NULL, false); }
  | IDENTIFIER as_keyword IDENTIFIER
      { $$ = ast_make_export_specifier($1, $3, false); }
  | IDENTIFIER as_keyword DEFAULT
      { $$ = ast_make_export_specifier($1, dup_string("default"), false); }
  | DEFAULT as_keyword IDENTIFIER
      { $$ = ast_make_export_specifier(dup_string("default"), $3, false); }
  | DEFAULT as_keyword DEFAULT
      { $$ = ast_make_export_specifier(dup_string("default"), dup_string("default"), false); }
  | DEFAULT
      { $$ = ast_make_export_specifier(dup_string("default"), NULL, false); }
  ;

from_keyword
  : IDENTIFIER
      {
          if (!$1 || !identifier_is($1, "from")) {
              yyerror("Expected 'from' in module statement");
              free($1);
              YYERROR;
          }
          free($1);
          $$ = NULL;
      }
  ;

as_keyword
  : IDENTIFIER
      {
          if (!$1 || !identifier_is($1, "as")) {
              yyerror("Expected 'as' in module statement");
              free($1);
              YYERROR;
          }
          free($1);
          $$ = NULL;
      }
  ;

block
    : '{' stmt_list '}'
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
  | object_binding '=' assignment_expr_no_pattern
      { $$ = ast_make_var_decl(ast_make_binding_pattern($1, $3)); }
  | array_binding '=' assignment_expr_no_pattern
      { $$ = ast_make_var_decl(ast_make_binding_pattern($1, $3)); }
  ;

var_stmt_no_in
  : VAR var_decl_list_no_in
      { $$ = ast_make_var_stmt(AST_VAR_KIND_VAR, $2); }
  | LET var_decl_list_no_in
      { $$ = ast_make_var_stmt(AST_VAR_KIND_LET, $2); }
  | CONST var_decl_list_no_in
      { $$ = ast_make_var_stmt(AST_VAR_KIND_CONST, $2); }
  ;

var_decl_list_no_in
  : var_decl_no_in
      { $$ = ast_list_append(NULL, $1); }
  | var_decl_list_no_in ',' var_decl_no_in
      { $$ = ast_list_append($1, $3); }
  ;

var_decl_no_in
  : IDENTIFIER binding_initializer_opt_no_in
      { $$ = ast_make_var_decl(ast_make_binding_pattern(ast_make_identifier($1), $2)); }
  | object_binding '=' assignment_expr_no_pattern_no_in
      { $$ = ast_make_var_decl(ast_make_binding_pattern($1, $3)); }
  | array_binding '=' assignment_expr_no_pattern_no_in
      { $$ = ast_make_var_decl(ast_make_binding_pattern($1, $3)); }
  ;

return_stmt
  : RETURN
      { $$ = ast_make_return(NULL); }
  | RETURN expr
      { $$ = ast_make_return($2); }
  ;

if_stmt
    : IF '(' expr ')' stmt %prec IF_NO_ELSE
            { $$ = ast_make_if($3, $5, NULL); }
  | IF '(' expr ')' stmt ELSE stmt
      { $$ = ast_make_if($3, $5, $7); }
  ;

for_stmt
  : FOR '(' for_init ';' opt_expr ';' opt_expr ')' stmt
      { $$ = ast_make_for($3, $5, $7, $9); }
  | FOR '(' for_in_left IN expr ')' stmt
      { $$ = ast_make_for_in($3, $5, $7); }
  | FOR '(' for_in_left for_of_keyword expr ')' stmt
    { $$ = ast_make_for_of($3, $5, $7, false); }
    | FOR AWAIT '(' for_in_left for_of_keyword expr ')' stmt
        { $$ = ast_make_for_of($4, $6, $8, true); }
  ;

while_stmt
    : WHILE '(' expr ')' stmt
            { $$ = ast_make_while($3, $5); }
    ;

do_stmt
    : DO stmt WHILE '(' expr ')' ';'
        { $$ = ast_make_do_while($2, $5); }
    ;

for_init
  : /* empty */
      { $$ = NULL; }
    | var_stmt_no_in
      { $$ = $1; }
    | expr_no_in_no_obj
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

for_of_keyword
  : IDENTIFIER
      {
          if (!$1 || !identifier_is($1, "of")) {
              yyerror("Expected 'of' in for-of statement");
              free($1);
              YYERROR;
          }
          free($1);
          $$ = NULL;
      }
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

generator_marker_opt
  : '*'
      { $$ = 1; }
  | /* empty */
      { $$ = 0; }
  ;

async_modifier_opt
  : ASYNC
      { $$ = 1; }
  | /* empty */
      { $$ = 0; }
  ;

func_decl
    : async_modifier_opt FUNCTION_DECL generator_marker_opt IDENTIFIER '(' opt_param_list ')' block
      {
          $$ = ast_make_function_decl($4, $6, $8);
          if ($3 && $$) {
              $$->data.function_decl.is_generator = true;
          }
          if ($1 && $$) {
              $$->data.function_decl.is_async = true;
          }
      }
    | async_modifier_opt FUNCTION_DECL generator_marker_opt '(' opt_param_list ')' block
      {
          $$ = ast_make_function_decl(NULL, $5, $7);
          if ($3 && $$) {
              $$->data.function_decl.is_generator = true;
          }
          if ($1 && $$) {
              $$->data.function_decl.is_async = true;
          }
      }
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
  : assignment_expr_no_pattern
      { $$ = $1; }
  ;

assignment_expr_no_pattern
	: postfix_expr_no_arr '=' assignment_expr_no_pattern
	    {
	        ASTNode *lhs = convert_assignment_target($1, true);
	        if (!lhs) {
	            lhs = $1;
	        }
	        $$ = ast_make_assignment("=", wrap_destructuring_target(lhs), $3);
	    }
  | postfix_expr_no_arr PLUS_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("+=", $1, $3); }
  | postfix_expr_no_arr MINUS_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("-=", $1, $3); }
  | postfix_expr_no_arr STAR_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("*=", $1, $3); }
  | postfix_expr_no_arr SLASH_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("/=", $1, $3); }
  | postfix_expr_no_arr PERCENT_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("%=", $1, $3); }
  | postfix_expr_no_arr AND_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("&=", $1, $3); }
  | postfix_expr_no_arr OR_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("|=", $1, $3); }
  | postfix_expr_no_arr XOR_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("^=", $1, $3); }
  | postfix_expr_no_arr LSHIFT_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("<<=", $1, $3); }
  | postfix_expr_no_arr RSHIFT_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment(">>=", $1, $3); }
  | postfix_expr_no_arr URSHIFT_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment(">>>=", $1, $3); }
  | arrow_function
      { $$ = $1; }
    | conditional_expr
      { $$ = $1; }
    | yield_expr
            { $$ = $1; }
  ;

assignment_expr_no_pattern_no_in
	: postfix_expr_no_arr '=' assignment_expr_no_pattern_no_in
	    {
	        ASTNode *lhs = convert_assignment_target($1, true);
	        if (!lhs) {
	            lhs = $1;
	        }
	        $$ = ast_make_assignment("=", wrap_destructuring_target(lhs), $3);
	    }
  | postfix_expr_no_arr PLUS_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("+=", $1, $3); }
  | postfix_expr_no_arr MINUS_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("-=", $1, $3); }
  | postfix_expr_no_arr STAR_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("*=", $1, $3); }
  | postfix_expr_no_arr SLASH_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("/=", $1, $3); }
  | postfix_expr_no_arr PERCENT_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("%=", $1, $3); }
  | postfix_expr_no_arr AND_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("&=", $1, $3); }
  | postfix_expr_no_arr OR_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("|=", $1, $3); }
  | postfix_expr_no_arr XOR_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("^=", $1, $3); }
  | postfix_expr_no_arr LSHIFT_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("<<=", $1, $3); }
  | postfix_expr_no_arr RSHIFT_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment(">>=", $1, $3); }
  | postfix_expr_no_arr URSHIFT_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment(">>>=", $1, $3); }
  | arrow_function
      { $$ = $1; }
  | conditional_expr_no_in
      { $$ = $1; }
  | yield_expr
      { $$ = $1; }
  ;

conditional_expr
    : logical_or_expr
        { $$ = $1; }
    | logical_or_expr '?' assignment_expr ':' assignment_expr
        { $$ = ast_make_conditional($1, $3, $5); }
    ;

conditional_expr_no_in
    : logical_or_expr_no_in
        { $$ = $1; }
    | logical_or_expr_no_in '?' assignment_expr ':' assignment_expr
        { $$ = ast_make_conditional($1, $3, $5); }
    ;

logical_or_expr
  : logical_and_expr
      { $$ = $1; }
  | logical_or_expr OR logical_and_expr
      { $$ = ast_make_binary("||", $1, $3); }
  ;

logical_or_expr_no_in
  : logical_and_expr_no_in
      { $$ = $1; }
  | logical_or_expr_no_in OR logical_and_expr_no_in
      { $$ = ast_make_binary("||", $1, $3); }
  ;

logical_and_expr
    : bitwise_or_expr
      { $$ = $1; }
    | logical_and_expr AND bitwise_or_expr
      { $$ = ast_make_binary("&&", $1, $3); }
  ;

logical_and_expr_no_in
    : bitwise_or_expr_no_in
      { $$ = $1; }
    | logical_and_expr_no_in AND bitwise_or_expr_no_in
      { $$ = ast_make_binary("&&", $1, $3); }
  ;

bitwise_or_expr
    : bitwise_xor_expr
            { $$ = $1; }
    | bitwise_or_expr '|' bitwise_xor_expr
            { $$ = ast_make_binary("|", $1, $3); }
    ;

bitwise_or_expr_no_in
    : bitwise_xor_expr_no_in
        { $$ = $1; }
    | bitwise_or_expr_no_in '|' bitwise_xor_expr_no_in
        { $$ = ast_make_binary("|", $1, $3); }
    ;

bitwise_xor_expr
    : bitwise_and_expr
            { $$ = $1; }
    | bitwise_xor_expr '^' bitwise_and_expr
            { $$ = ast_make_binary("^", $1, $3); }
    ;

bitwise_xor_expr_no_in
    : bitwise_and_expr_no_in
        { $$ = $1; }
    | bitwise_xor_expr_no_in '^' bitwise_and_expr_no_in
        { $$ = ast_make_binary("^", $1, $3); }
    ;

bitwise_and_expr
    : equality_expr
            { $$ = $1; }
    | bitwise_and_expr '&' equality_expr
            { $$ = ast_make_binary("&", $1, $3); }
    ;

bitwise_and_expr_no_in
    : equality_expr_no_in
        { $$ = $1; }
    | bitwise_and_expr_no_in '&' equality_expr_no_in
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
 
equality_expr_no_in
    : relational_expr_no_in
      { $$ = $1; }
  | equality_expr_no_in EQ relational_expr_no_in
      { $$ = ast_make_binary("==", $1, $3); }
  | equality_expr_no_in NE relational_expr_no_in
      { $$ = ast_make_binary("!=", $1, $3); }
  | equality_expr_no_in EQ_STRICT relational_expr_no_in
      { $$ = ast_make_binary("===", $1, $3); }
  | equality_expr_no_in NE_STRICT relational_expr_no_in
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
  | relational_expr IN shift_expr
      { $$ = ast_make_binary("in", $1, $3); }
  ;

relational_expr_no_in
  : shift_expr
      { $$ = $1; }
  | relational_expr_no_in '<' shift_expr
      { $$ = ast_make_binary("<", $1, $3); }
  | relational_expr_no_in '>' shift_expr
      { $$ = ast_make_binary(">", $1, $3); }
  | relational_expr_no_in LE shift_expr
      { $$ = ast_make_binary("<=", $1, $3); }
  | relational_expr_no_in GE shift_expr
      { $$ = ast_make_binary(">=", $1, $3); }
  | relational_expr_no_in INSTANCEOF shift_expr
      { $$ = ast_make_binary("instanceof", $1, $3); }
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
  | multiplicative_expr '*' '*' unary_expr
      { $$ = ast_make_binary("**", $1, $4); }
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
  | AWAIT unary_expr
      { $$ = ast_make_await($2); }
  | PLUS_PLUS unary_expr
      { $$ = ast_make_update("++", $2, true); }
  | MINUS_MINUS unary_expr
      { $$ = ast_make_update("--", $2, true); }
  ;

postfix_expr
  : left_hand_side_expr
      { $$ = $1; }
  | postfix_expr PLUS_PLUS
      { $$ = ast_make_update("++", $1, false); }
  | postfix_expr MINUS_MINUS
      { $$ = ast_make_update("--", $1, false); }
  ;

postfix_expr_no_arr
  : left_hand_side_expr_no_arr
      { $$ = $1; }
  | postfix_expr_no_arr PLUS_PLUS
      { $$ = ast_make_update("++", $1, false); }
  | postfix_expr_no_arr MINUS_MINUS
      { $$ = ast_make_update("--", $1, false); }
  ;

left_hand_side_expr
  : call_expr
      { $$ = $1; }
  | new_expr
      { $$ = $1; }
  ;

left_hand_side_expr_no_arr
  : call_expr_no_arr
      { $$ = $1; }
  | new_expr_no_arr
      { $$ = $1; }
  ;

member_expr
  : primary_expr member_suffix_seq
      { $$ = apply_suffix_chain($1, $2); }
  | NEW member_expr '(' opt_arg_list ')' member_suffix_seq
      { $$ = apply_suffix_chain(ast_make_new_expr($2, $4), $6); }
  ;

member_expr_no_arr
  : primary_no_arr member_suffix_seq
      { $$ = apply_suffix_chain($1, $2); }
  | NEW member_expr_no_arr '(' opt_arg_list ')' member_suffix_seq
      { $$ = apply_suffix_chain(ast_make_new_expr($2, $4), $6); }
  ;

new_expr
  : member_expr
      { $$ = $1; }
  | NEW new_expr
      { $$ = ast_make_new_expr($2, NULL); }
  ;

new_expr_no_arr
  : member_expr_no_arr
      { $$ = $1; }
  | NEW new_expr_no_arr
      { $$ = ast_make_new_expr($2, NULL); }
  ;

call_expr
  : member_expr call_suffix_seq
      { $$ = apply_suffix_chain($1, $2); }
  ;

call_expr_no_arr
  : member_expr_no_arr call_suffix_seq
      { $$ = apply_suffix_chain($1, $2); }
  ;

member_suffix_seq
    : /* empty */
            { $$ = NULL; }
    | member_suffix_seq member_noncall_suffix
            { $$ = append_suffix($1, $2); }
    ;

member_noncall_suffix
    : '.' property_name
            { $$ = make_suffix_prop($2); }
    | '[' expr ']'
            { $$ = make_suffix_computed($2); }
    | template_literal
            { $$ = make_suffix_template($1); }
    ;

call_suffix_seq
    : call_suffix_seq call_any_suffix
            { $$ = append_suffix($1, $2); }
    | call_suffix_initial
            { $$ = $1; }
    ;

call_any_suffix
    : call_suffix_initial
            { $$ = $1; }
    | member_noncall_suffix
            { $$ = $1; }
    ;

call_suffix_initial
    : '(' opt_arg_list ')'
            { $$ = make_suffix_call($2); }
    ;

opt_arg_list
  : /* empty */
      { $$ = NULL; }
  | arg_list
      { $$ = $1; }
  ;

arg_list
  : arg_item
      { $$ = ast_list_append(NULL, $1); }
  | arg_list ',' arg_item
      { $$ = ast_list_append($1, $3); }
  ;

arg_item
  : assignment_expr
      { $$ = $1; }
  | spread_element
      { $$ = $1; }
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
  | class_expr
      { $$ = $1; }
  | SUPER
      { $$ = ast_make_super_expr(); }
  | function_expr
      { $$ = $1; }
  ;

primary_no_arr
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
  | class_expr
      { $$ = $1; }
  | SUPER
      { $$ = ast_make_super_expr(); }
  | function_expr
      { $$ = $1; }
  ;

function_expr
    : async_modifier_opt FUNCTION generator_marker_opt IDENTIFIER '(' opt_param_list ')' block
      {
          $$ = ast_make_function_expr($4, $6, $8);
          if ($3 && $$) {
              $$->data.function_expr.is_generator = true;
          }
          if ($1 && $$) {
              $$->data.function_expr.is_async = true;
          }
      }
  | async_modifier_opt FUNCTION generator_marker_opt '(' opt_param_list ')' block
      {
          $$ = ast_make_function_expr(NULL, $5, $7);
          if ($3 && $$) {
              $$->data.function_expr.is_generator = true;
          }
          if ($1 && $$) {
              $$->data.function_expr.is_async = true;
          }
      }
  ;

class_decl
    : CLASS IDENTIFIER class_heritage_opt class_body
            { $$ = ast_make_class_decl($2, $3, $4); }
    ;

class_expr
    : CLASS IDENTIFIER class_heritage_opt class_body
            { $$ = ast_make_class_expr($2, $3, $4); }
    | CLASS class_heritage_opt class_body
            { $$ = ast_make_class_expr(NULL, $2, $3); }
    ;

class_heritage_opt
    : EXTENDS assignment_expr
            { $$ = $2; }
    | /* empty */
            { $$ = NULL; }
    ;

class_body
    : '{' class_element_list_opt '}'
            { $$ = $2; }
    ;

class_element_list_opt
    : /* empty */
            { $$ = NULL; }
    | class_element_list
            { $$ = $1; }
    ;

class_element_list
    : class_element_list class_element
            { $$ = $2 ? ast_list_append($1, $2) : $1; }
    | class_element
            { $$ = $1 ? ast_list_append(NULL, $1) : NULL; }
    ;

class_element
    : method_definition
        { $$ = maybe_tag_constructor($1); }
    | IDENTIFIER method_definition
        {
            $$ = handle_single_prefix($1, $2);
            if (!$$) {
                YYERROR;
            }
        }
    | IDENTIFIER IDENTIFIER method_definition
        {
            $$ = handle_double_prefix($1, $2, $3);
            if (!$$) {
                YYERROR;
            }
        }
    | ';'
        { $$ = NULL; }
    ;

method_definition
    : async_modifier_opt method_name '(' opt_param_list ')' block
            {
                MethodInfo info = $2;
                if ($1) {
                    info.is_async = true;
                }
                $$ = build_method_node(&info, $4, $6);
            }
    | async_modifier_opt '*' method_name '(' opt_param_list ')' block
            {
                MethodInfo info = $3;
                info.is_generator = true;
                if ($1) {
                    info.is_async = true;
                }
                $$ = build_method_node(&info, $5, $7);
            }
    ;

getter_definition
    : IDENTIFIER method_name '(' ')' block
            {
                if (!identifier_is($1, "get")) {
                    yyerror("Unexpected identifier before getter definition");
                    free($1);
                    YYERROR;
                }
                free($1);
                MethodInfo info = $2;
                info.kind = AST_METHOD_KIND_GET;
                $$ = build_method_node(&info, NULL, $5);
            }
    ;

setter_definition
    : IDENTIFIER method_name '(' binding_element ')' block
            {
                if (!identifier_is($1, "set")) {
                    yyerror("Unexpected identifier before setter definition");
                    free($1);
                    YYERROR;
                }
                free($1);
                MethodInfo info = $2;
                info.kind = AST_METHOD_KIND_SET;
                ASTList *params = make_single_param_list($4);
                $$ = build_method_node(&info, params, $6);
            }
    ;

method_name
    : property_name
            { $$ = method_info_from_name($1); }
    | '[' assignment_expr ']'
            { $$ = method_info_from_computed($2); }
    ;
expr_no_obj
  : assignment_expr_no_obj
            { $$ = $1; }
  | expr_no_obj ',' assignment_expr_no_obj
            { $$ = ast_make_sequence($1, $3); }
  ;

assignment_expr_no_obj
  : assignment_expr_no_pattern_no_obj
      { $$ = $1; }
  ;



assignment_expr_no_pattern_no_obj
	: postfix_expr_no_obj_no_arr '=' assignment_expr_no_pattern
	    {
	        ASTNode *lhs = convert_assignment_target($1, false);
	        if (!lhs) {
	            lhs = $1;
	        }
	        $$ = ast_make_assignment("=", wrap_destructuring_target(lhs), $3);
	    }
  | postfix_expr_no_obj_no_arr PLUS_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("+=", $1, $3); }
  | postfix_expr_no_obj_no_arr MINUS_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("-=", $1, $3); }
  | postfix_expr_no_obj_no_arr STAR_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("*=", $1, $3); }
  | postfix_expr_no_obj_no_arr SLASH_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("/=", $1, $3); }
  | postfix_expr_no_obj_no_arr PERCENT_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("%=", $1, $3); }
  | postfix_expr_no_obj_no_arr AND_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("&=", $1, $3); }
  | postfix_expr_no_obj_no_arr OR_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("|=", $1, $3); }
  | postfix_expr_no_obj_no_arr XOR_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("^=", $1, $3); }
  | postfix_expr_no_obj_no_arr LSHIFT_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment("<<=", $1, $3); }
  | postfix_expr_no_obj_no_arr RSHIFT_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment(">>=", $1, $3); }
  | postfix_expr_no_obj_no_arr URSHIFT_ASSIGN assignment_expr_no_pattern
      { $$ = ast_make_assignment(">>>=", $1, $3); }
  | arrow_function
      { $$ = $1; }
    | conditional_expr_no_obj
      { $$ = $1; }
    | yield_expr
            { $$ = $1; }
  ;

arrow_function
  : IDENTIFIER ARROW arrow_body %dprec 2
      {
          ASTList *params = NULL;
          ASTNode *binding = ast_make_binding_pattern(ast_make_identifier($1), NULL);
          params = ast_list_append(params, binding);
          $$ = ast_make_arrow_function(params, $3.body, $3.is_expression);
      }
  | ARROW_HEAD '(' opt_param_list ')' ARROW arrow_body %dprec 2
      { $$ = ast_make_arrow_function($3, $6.body, $6.is_expression); }
  | ASYNC IDENTIFIER ARROW arrow_body %dprec 2
      {
          ASTList *params = NULL;
          ASTNode *binding = ast_make_binding_pattern(ast_make_identifier($2), NULL);
          params = ast_list_append(params, binding);
          $$ = ast_make_arrow_function(params, $4.body, $4.is_expression);
          if ($$) {
              $$->data.arrow_function.is_async = true;
          }
      }
  | ASYNC ARROW_HEAD '(' opt_param_list ')' ARROW arrow_body %dprec 2
      {
          $$ = ast_make_arrow_function($4, $7.body, $7.is_expression);
          if ($$) {
              $$->data.arrow_function.is_async = true;
          }
      }
  ;

arrow_body
    : assignment_expr_no_obj
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
  | logical_or_expr_no_obj OR logical_and_expr
      { $$ = ast_make_binary("||", $1, $3); }
  | logical_or_expr_no_obj OR object_literal_expr_no_obj
      { $$ = ast_make_binary("||", $1, $3); }
  ;

logical_and_expr_no_obj
  : bitwise_or_expr_no_obj
      { $$ = $1; }
  | logical_and_expr_no_obj AND bitwise_or_expr
      { $$ = ast_make_binary("&&", $1, $3); }
  | logical_and_expr_no_obj AND object_literal_expr_no_obj
      { $$ = ast_make_binary("&&", $1, $3); }
  ;

bitwise_or_expr_no_obj
  : bitwise_xor_expr_no_obj
      { $$ = $1; }
  | bitwise_or_expr_no_obj '|' bitwise_xor_expr
      { $$ = ast_make_binary("|", $1, $3); }
  | bitwise_or_expr_no_obj '|' object_literal_expr_no_obj
      { $$ = ast_make_binary("|", $1, $3); }
  ;

bitwise_xor_expr_no_obj
  : bitwise_and_expr_no_obj
      { $$ = $1; }
  | bitwise_xor_expr_no_obj '^' bitwise_and_expr
      { $$ = ast_make_binary("^", $1, $3); }
  | bitwise_xor_expr_no_obj '^' object_literal_expr_no_obj
      { $$ = ast_make_binary("^", $1, $3); }
  ;

bitwise_and_expr_no_obj
  : equality_expr_no_obj
      { $$ = $1; }
  | bitwise_and_expr_no_obj '&' equality_expr
      { $$ = ast_make_binary("&", $1, $3); }
  | bitwise_and_expr_no_obj '&' object_literal_expr_no_obj
      { $$ = ast_make_binary("&", $1, $3); }
  ;

equality_expr_no_obj
  : relational_expr_no_obj
      { $$ = $1; }
  | equality_expr_no_obj EQ relational_expr
      { $$ = ast_make_binary("==", $1, $3); }
  | equality_expr_no_obj NE relational_expr
      { $$ = ast_make_binary("!=", $1, $3); }
  | equality_expr_no_obj EQ_STRICT relational_expr
      { $$ = ast_make_binary("===", $1, $3); }
  | equality_expr_no_obj NE_STRICT relational_expr
      { $$ = ast_make_binary("!==", $1, $3); }
  | equality_expr_no_obj EQ object_literal_expr_no_obj
      { $$ = ast_make_binary("==", $1, $3); }
  | equality_expr_no_obj NE object_literal_expr_no_obj
      { $$ = ast_make_binary("!=", $1, $3); }
  | equality_expr_no_obj EQ_STRICT object_literal_expr_no_obj
      { $$ = ast_make_binary("===", $1, $3); }
  | equality_expr_no_obj NE_STRICT object_literal_expr_no_obj
      { $$ = ast_make_binary("!==", $1, $3); }
  ;

relational_expr_no_obj
  : shift_expr_no_obj
      { $$ = $1; }
  | relational_expr_no_obj '<' shift_expr
      { $$ = ast_make_binary("<", $1, $3); }
  | relational_expr_no_obj '>' shift_expr
      { $$ = ast_make_binary(">", $1, $3); }
  | relational_expr_no_obj LE shift_expr
      { $$ = ast_make_binary("<=", $1, $3); }
  | relational_expr_no_obj GE shift_expr
      { $$ = ast_make_binary(">=", $1, $3); }
  | relational_expr_no_obj INSTANCEOF shift_expr
      { $$ = ast_make_binary("instanceof", $1, $3); }
  | relational_expr_no_obj IN shift_expr
      { $$ = ast_make_binary("in", $1, $3); }
  | relational_expr_no_obj '<' object_literal_expr_no_obj
      { $$ = ast_make_binary("<", $1, $3); }
  | relational_expr_no_obj '>' object_literal_expr_no_obj
      { $$ = ast_make_binary(">", $1, $3); }
  | relational_expr_no_obj LE object_literal_expr_no_obj
      { $$ = ast_make_binary("<=", $1, $3); }
  | relational_expr_no_obj GE object_literal_expr_no_obj
      { $$ = ast_make_binary(">=", $1, $3); }
  | relational_expr_no_obj INSTANCEOF object_literal_expr_no_obj
      { $$ = ast_make_binary("instanceof", $1, $3); }
  | relational_expr_no_obj IN object_literal_expr_no_obj
      { $$ = ast_make_binary("in", $1, $3); }
  ;

shift_expr_no_obj
  : additive_expr_no_obj
      { $$ = $1; }
  | shift_expr_no_obj LSHIFT additive_expr
      { $$ = ast_make_binary("<<", $1, $3); }
  | shift_expr_no_obj RSHIFT additive_expr
      { $$ = ast_make_binary(">>", $1, $3); }
  | shift_expr_no_obj URSHIFT additive_expr
      { $$ = ast_make_binary(">>>", $1, $3); }
  | shift_expr_no_obj LSHIFT object_literal_expr_no_obj
      { $$ = ast_make_binary("<<", $1, $3); }
  | shift_expr_no_obj RSHIFT object_literal_expr_no_obj
      { $$ = ast_make_binary(">>", $1, $3); }
  | shift_expr_no_obj URSHIFT object_literal_expr_no_obj
      { $$ = ast_make_binary(">>>", $1, $3); }
  ;

additive_expr_no_obj
  : multiplicative_expr_no_obj
      { $$ = $1; }
  | additive_expr_no_obj '+' multiplicative_expr
      { $$ = ast_make_binary("+", $1, $3); }
  | additive_expr_no_obj '-' multiplicative_expr
      { $$ = ast_make_binary("-", $1, $3); }
  | additive_expr_no_obj '+' object_literal_expr_no_obj
      { $$ = ast_make_binary("+", $1, $3); }
  | additive_expr_no_obj '-' object_literal_expr_no_obj
      { $$ = ast_make_binary("-", $1, $3); }
  ;

multiplicative_expr_no_obj
  : unary_expr_no_obj
      { $$ = $1; }
  | multiplicative_expr_no_obj '*' unary_expr
      { $$ = ast_make_binary("*", $1, $3); }
  | multiplicative_expr_no_obj '*' '*' unary_expr
      { $$ = ast_make_binary("**", $1, $4); }
  | multiplicative_expr_no_obj '/' unary_expr
      { $$ = ast_make_binary("/", $1, $3); }
  | multiplicative_expr_no_obj '%' unary_expr
      { $$ = ast_make_binary("%", $1, $3); }
  | multiplicative_expr_no_obj '*' object_literal_expr_no_obj
      { $$ = ast_make_binary("*", $1, $3); }
  | multiplicative_expr_no_obj '/' object_literal_expr_no_obj
      { $$ = ast_make_binary("/", $1, $3); }
  | multiplicative_expr_no_obj '%' object_literal_expr_no_obj
      { $$ = ast_make_binary("%", $1, $3); }
  ;

unary_expr_no_obj
  : postfix_expr_no_obj
      { $$ = $1; }
  | '+' unary_expr_no_obj
      { $$ = ast_make_unary("+", $2); }
  | '+' object_literal_expr_no_obj
      { $$ = ast_make_unary("+", $2); }
  | '-' unary_expr_no_obj %prec UMINUS
      { $$ = ast_make_unary("-", $2); }
  | '-' object_literal_expr_no_obj %prec UMINUS
      { $$ = ast_make_unary("-", $2); }
  | '!' unary_expr_no_obj
      { $$ = ast_make_unary("!", $2); }
  | '!' object_literal_expr_no_obj
      { $$ = ast_make_unary("!", $2); }
  | '~' unary_expr_no_obj
      { $$ = ast_make_unary("~", $2); }
  | '~' object_literal_expr_no_obj
      { $$ = ast_make_unary("~", $2); }
  | TYPEOF unary_expr_no_obj
      { $$ = ast_make_unary("typeof", $2); }
  | TYPEOF object_literal_expr_no_obj
      { $$ = ast_make_unary("typeof", $2); }
  | DELETE unary_expr_no_obj
      { $$ = ast_make_unary("delete", $2); }
  | DELETE object_literal_expr_no_obj
      { $$ = ast_make_unary("delete", $2); }
  | VOID unary_expr_no_obj
      { $$ = ast_make_unary("void", $2); }
  | VOID object_literal_expr_no_obj
      { $$ = ast_make_unary("void", $2); }
  | AWAIT unary_expr_no_obj
      { $$ = ast_make_await($2); }
  | AWAIT object_literal_expr_no_obj
      { $$ = ast_make_await($2); }
  | PLUS_PLUS unary_expr_no_obj
      { $$ = ast_make_update("++", $2, true); }
  | MINUS_MINUS unary_expr_no_obj
      { $$ = ast_make_update("--", $2, true); }
  ;

postfix_expr_no_obj
  : left_hand_side_expr_no_obj
      { $$ = $1; }
  | postfix_expr_no_obj PLUS_PLUS
      { $$ = ast_make_update("++", $1, false); }
  | postfix_expr_no_obj MINUS_MINUS
      { $$ = ast_make_update("--", $1, false); }
  ;

postfix_expr_no_obj_no_arr
  : left_hand_side_expr_no_obj_no_arr
      { $$ = $1; }
  | postfix_expr_no_obj_no_arr PLUS_PLUS
      { $$ = ast_make_update("++", $1, false); }
  | postfix_expr_no_obj_no_arr MINUS_MINUS
      { $$ = ast_make_update("--", $1, false); }
  ;

left_hand_side_expr_no_obj
    : new_expr_no_obj
            { $$ = $1; }
    | member_call_expr_no_obj
            { $$ = $1; }
    ;

left_hand_side_expr_no_obj_no_arr
    : new_expr_no_obj_no_arr
            { $$ = $1; }
    | member_call_expr_no_obj_no_arr
            { $$ = $1; }
    ;

member_expr_no_obj
  : primary_no_obj member_suffix_seq
      { $$ = apply_suffix_chain($1, $2); }
  | NEW member_expr_no_obj '(' opt_arg_list ')' member_suffix_seq
      { $$ = apply_suffix_chain(ast_make_new_expr($2, $4), $6); }
  ;

member_expr_no_obj_no_arr
  : primary_no_obj_no_arr member_suffix_seq
      { $$ = apply_suffix_chain($1, $2); }
  | NEW member_expr_no_obj_no_arr '(' opt_arg_list ')' member_suffix_seq
      { $$ = apply_suffix_chain(ast_make_new_expr($2, $4), $6); }
  ;

member_call_expr_no_obj
  : member_expr_no_obj call_suffix_seq
      { $$ = apply_suffix_chain($1, $2); }
  ;

member_call_expr_no_obj_no_arr
  : member_expr_no_obj_no_arr call_suffix_seq
      { $$ = apply_suffix_chain($1, $2); }
  ;

new_expr_no_obj
  : member_expr_no_obj
      { $$ = $1; }
  | NEW new_expr_no_obj
      { $$ = ast_make_new_expr($2, NULL); }
  ;


new_expr_no_obj_no_arr
  : member_expr_no_obj_no_arr
      { $$ = $1; }
  | NEW new_expr_no_obj_no_arr
      { $$ = ast_make_new_expr($2, NULL); }
  ;

primary_no_obj
  : primary_no_obj_no_arr
      { $$ = $1; }
  ;

primary_no_obj_no_arr
  : IDENTIFIER
      { $$ = ast_make_identifier($1); }
  | THIS
      { $$ = ast_make_this_expr(); }
  | SUPER
      { $$ = ast_make_super_expr(); }
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
  | function_expr
      { $$ = $1; }
  ;
 
expr_no_in_no_obj
  : assignment_expr_no_in_no_obj
      { $$ = $1; }
  | expr_no_in_no_obj ',' assignment_expr_no_in_no_obj
      { $$ = ast_make_sequence($1, $3); }
  ;

assignment_expr_no_in_no_obj
  : assignment_expr_no_pattern_no_in_no_obj
      { $$ = $1; }
  ;


assignment_expr_no_pattern_no_in_no_obj
	: postfix_expr_no_obj_no_arr '=' assignment_expr_no_pattern_no_in
	    {
	        ASTNode *lhs = convert_assignment_target($1, false);
	        if (!lhs) {
	            lhs = $1;
	        }
	        $$ = ast_make_assignment("=", wrap_destructuring_target(lhs), $3);
	    }
  | postfix_expr_no_obj_no_arr PLUS_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("+=", $1, $3); }
  | postfix_expr_no_obj_no_arr MINUS_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("-=", $1, $3); }
  | postfix_expr_no_obj_no_arr STAR_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("*=", $1, $3); }
  | postfix_expr_no_obj_no_arr SLASH_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("/=", $1, $3); }
  | postfix_expr_no_obj_no_arr PERCENT_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("%=", $1, $3); }
  | postfix_expr_no_obj_no_arr AND_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("&=", $1, $3); }
  | postfix_expr_no_obj_no_arr OR_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("|=", $1, $3); }
  | postfix_expr_no_obj_no_arr XOR_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("^=", $1, $3); }
  | postfix_expr_no_obj_no_arr LSHIFT_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment("<<=", $1, $3); }
  | postfix_expr_no_obj_no_arr RSHIFT_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment(">>=", $1, $3); }
  | postfix_expr_no_obj_no_arr URSHIFT_ASSIGN assignment_expr_no_pattern_no_in
      { $$ = ast_make_assignment(">>>=", $1, $3); }
  | arrow_function
      { $$ = $1; }
  | conditional_expr_no_obj_no_in
      { $$ = $1; }
  | yield_expr
      { $$ = $1; }
  ;

yield_expr
  : YIELD
      { $$ = ast_make_yield(NULL, false); }
  | YIELD assignment_expr
      { $$ = ast_make_yield($2, false); }
  | YIELD '*' assignment_expr
      { $$ = ast_make_yield($3, true); }
  ;

conditional_expr_no_obj_no_in
  : logical_or_expr_no_obj_no_in
      { $$ = $1; }
  | logical_or_expr_no_obj_no_in '?' assignment_expr ':' assignment_expr
      { $$ = ast_make_conditional($1, $3, $5); }
  ;

logical_or_expr_no_obj_no_in
  : logical_and_expr_no_obj_no_in
      { $$ = $1; }
  | logical_or_expr_no_obj_no_in OR logical_and_expr_no_in
      { $$ = ast_make_binary("||", $1, $3); }
  | logical_or_expr_no_obj_no_in OR object_literal_expr_no_obj
      { $$ = ast_make_binary("||", $1, $3); }
  ;

logical_and_expr_no_obj_no_in
  : bitwise_or_expr_no_obj_no_in
      { $$ = $1; }
  | logical_and_expr_no_obj_no_in AND bitwise_or_expr_no_in
      { $$ = ast_make_binary("&&", $1, $3); }
  | logical_and_expr_no_obj_no_in AND object_literal_expr_no_obj
      { $$ = ast_make_binary("&&", $1, $3); }
  ;

bitwise_or_expr_no_obj_no_in
  : bitwise_xor_expr_no_obj_no_in
      { $$ = $1; }
  | bitwise_or_expr_no_obj_no_in '|' bitwise_xor_expr_no_in
      { $$ = ast_make_binary("|", $1, $3); }
  | bitwise_or_expr_no_obj_no_in '|' object_literal_expr_no_obj
      { $$ = ast_make_binary("|", $1, $3); }
  ;

bitwise_xor_expr_no_obj_no_in
  : bitwise_and_expr_no_obj_no_in
      { $$ = $1; }
  | bitwise_xor_expr_no_obj_no_in '^' bitwise_and_expr_no_in
      { $$ = ast_make_binary("^", $1, $3); }
  | bitwise_xor_expr_no_obj_no_in '^' object_literal_expr_no_obj
      { $$ = ast_make_binary("^", $1, $3); }
  ;

bitwise_and_expr_no_obj_no_in
  : equality_expr_no_obj_no_in
      { $$ = $1; }
  | bitwise_and_expr_no_obj_no_in '&' equality_expr_no_in
      { $$ = ast_make_binary("&", $1, $3); }
  | bitwise_and_expr_no_obj_no_in '&' object_literal_expr_no_obj
      { $$ = ast_make_binary("&", $1, $3); }
  ;

equality_expr_no_obj_no_in
  : relational_expr_no_obj_no_in
      { $$ = $1; }
  | equality_expr_no_obj_no_in EQ relational_expr_no_in
      { $$ = ast_make_binary("==", $1, $3); }
  | equality_expr_no_obj_no_in NE relational_expr_no_in
      { $$ = ast_make_binary("!=", $1, $3); }
  | equality_expr_no_obj_no_in EQ_STRICT relational_expr_no_in
      { $$ = ast_make_binary("===", $1, $3); }
  | equality_expr_no_obj_no_in NE_STRICT relational_expr_no_in
      { $$ = ast_make_binary("!==", $1, $3); }
  | equality_expr_no_obj_no_in EQ object_literal_expr_no_obj
      { $$ = ast_make_binary("==", $1, $3); }
  | equality_expr_no_obj_no_in NE object_literal_expr_no_obj
      { $$ = ast_make_binary("!=", $1, $3); }
  | equality_expr_no_obj_no_in EQ_STRICT object_literal_expr_no_obj
      { $$ = ast_make_binary("===", $1, $3); }
  | equality_expr_no_obj_no_in NE_STRICT object_literal_expr_no_obj
      { $$ = ast_make_binary("!==", $1, $3); }
  ;

relational_expr_no_obj_no_in
  : shift_expr_no_obj
      { $$ = $1; }
  | relational_expr_no_obj_no_in '<' shift_expr
      { $$ = ast_make_binary("<", $1, $3); }
  | relational_expr_no_obj_no_in '>' shift_expr
      { $$ = ast_make_binary(">", $1, $3); }
  | relational_expr_no_obj_no_in LE shift_expr
      { $$ = ast_make_binary("<=", $1, $3); }
  | relational_expr_no_obj_no_in GE shift_expr
      { $$ = ast_make_binary(">=", $1, $3); }
  | relational_expr_no_obj_no_in INSTANCEOF shift_expr
      { $$ = ast_make_binary("instanceof", $1, $3); }
  | relational_expr_no_obj_no_in '<' object_literal_expr_no_obj
      { $$ = ast_make_binary("<", $1, $3); }
  | relational_expr_no_obj_no_in '>' object_literal_expr_no_obj
      { $$ = ast_make_binary(">", $1, $3); }
  | relational_expr_no_obj_no_in LE object_literal_expr_no_obj
      { $$ = ast_make_binary("<=", $1, $3); }
  | relational_expr_no_obj_no_in GE object_literal_expr_no_obj
      { $$ = ast_make_binary(">=", $1, $3); }
  | relational_expr_no_obj_no_in INSTANCEOF object_literal_expr_no_obj
      { $$ = ast_make_binary("instanceof", $1, $3); }
  ;

array_literal
  : '[' ']'
      { $$ = ast_make_array_literal(NULL); }
  | '[' elision ']'
      { $$ = ast_make_array_literal($2); }
  | '[' element_list ']'
      { $$ = ast_make_array_literal($2); }
  | '[' element_list ',' ']'
      { $$ = ast_make_array_literal($2); }
  ;

elision
  : ','
      { $$ = ast_list_append(NULL, ast_make_array_hole()); }
  | elision ','
      { $$ = ast_list_append($1, ast_make_array_hole()); }
  ;

elision_opt
  : /* empty */
      { $$ = NULL; }
  | elision
      { $$ = $1; }
  ;

element_list
  : elision_opt el_item
      { $$ = ast_list_concat($1, ast_list_append(NULL, $2)); }
  | element_list ',' elision_opt el_item
      {
          ASTList *list = ast_list_concat($1, $3);
          $$ = ast_list_append(list, $4);
      }
  | element_list ',' elision
      { $$ = ast_list_concat($1, $3); }
  ;

el_item
  : assignment_expr
      { $$ = $1; }
  | spread_element
      { $$ = $1; }
  ;

spread_element
    : ELLIPSIS assignment_expr
            { $$ = ast_make_spread_element($2); }
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

object_literal_expr_no_obj
    : object_literal
            { $$ = $1; }
    ;

template_literal
  : TEMPLATE_NO_SUB
      {
          ASTList *quasis = NULL;
          quasis = ast_list_append(quasis, ast_make_template_element($1, true));
          $$ = ast_make_template_literal(quasis, NULL);
      }
  | TEMPLATE_HEAD template_part_list
      {
          ASTList *quasis = NULL;
          quasis = ast_list_append(quasis, ast_make_template_element($1, false));
          quasis = ast_list_concat(quasis, $2.quasis);
          $$ = ast_make_template_literal(quasis, $2.exprs);
      }
  ;

template_part_list
  : assignment_expr TEMPLATE_TAIL
      {
          ASTList *exprs = NULL;
          ASTList *quasis = NULL;
          exprs = ast_list_append(exprs, $1);
          quasis = ast_list_append(quasis, ast_make_template_element($2, true));
          $$.exprs = exprs;
          $$.quasis = quasis;
      }
  | assignment_expr TEMPLATE_MIDDLE template_part_list
      {
          ASTList *exprs = NULL;
          ASTList *quasis = NULL;
          exprs = ast_list_append(exprs, $1);
          exprs = ast_list_concat(exprs, $3.exprs);
          quasis = ast_list_append(quasis, ast_make_template_element($2, false));
          quasis = ast_list_concat(quasis, $3.quasis);
          $$.exprs = exprs;
          $$.quasis = quasis;
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
  | method_definition
      { $$ = $1; }
  | getter_definition
      { $$ = $1; }
  | setter_definition
      { $$ = $1; }
  | computed_property
      { $$ = $1; }
  | spread_element
      { $$ = $1; }
  ;

computed_property
  : '[' assignment_expr ']' ':' assignment_expr
      { $$ = ast_make_computed_property($2, $5); }
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
    | CLASS      { $$ = strdup("class"); }
    | EXTENDS    { $$ = strdup("extends"); }
    | SUPER      { $$ = strdup("super"); }
    | ASYNC      { $$ = strdup("async"); }
    | AWAIT      { $$ = strdup("await"); }
    ;

binding_initializer_opt
  : /* empty */
      { $$ = NULL; }
    | '=' assignment_expr_no_pattern
      { $$ = $2; }
  ;

binding_initializer_opt_no_in
    : /* empty */
            { $$ = NULL; }
    | '=' assignment_expr_no_pattern_no_in
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
  : '[' binding_elision_opt ']'
      { $$ = ast_make_array_binding($2); }
  | '[' binding_elision_opt binding_element_list opt_trailing_comma ']'
      { ASTList *list = ast_list_concat($2, $3); $$ = ast_make_array_binding(list); }
  | '[' binding_elision_opt binding_element_list ',' binding_elision_opt binding_rest_element opt_trailing_comma ']'
      { ASTList *list = ast_list_concat($2, $3); list = ast_list_concat(list, $5); $$ = ast_make_array_binding(ast_list_append(list, $6)); }
  | '[' binding_elision_opt binding_rest_element opt_trailing_comma ']'
      { ASTList *list = ast_list_concat($2, ast_list_append(NULL, $3)); $$ = ast_make_array_binding(list); }
  ;

binding_element_list
  : binding_element
      { $$ = ast_list_append(NULL, $1); }
  | binding_element_list ',' binding_elision_opt binding_element
      { ASTList *list = ast_list_concat($1, $3); $$ = ast_list_append(list, $4); }
  ;

binding_elision_opt
  : /* empty */
      { $$ = NULL; }
  | binding_elision
      { $$ = $1; }
  ;

binding_elision
  : ','
      { $$ = ast_list_append(NULL, ast_make_array_hole()); }
  | ',' binding_elision
      { ASTList *list = ast_list_append(NULL, ast_make_array_hole()); $$ = ast_list_concat(list, $2); }
  ;

binding_rest_element
  : ELLIPSIS IDENTIFIER
      { $$ = ast_make_rest_element(ast_make_identifier($2)); }
  ;

assignment_pattern
  : object_assignment_pattern
      { $$ = ast_make_binding_pattern($1, NULL); }
  | array_assignment_pattern
      { $$ = ast_make_binding_pattern($1, NULL); }
  ;

object_assignment_pattern
  : '{' '}'
      { $$ = ast_make_object_binding(NULL); }
  | '{' assignment_property_sequence '}'
      { $$ = ast_make_object_binding($2); }
  ;

assignment_property_sequence
  : assignment_property_list opt_trailing_comma
      { $$ = $1; }
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
  : '[' binding_elision_opt ']'
      { $$ = ast_make_array_binding($2); }
  | '[' binding_elision_opt assignment_element_list opt_trailing_comma ']'
      { ASTList *list = ast_list_concat($2, $3); $$ = ast_make_array_binding(list); }
  | '[' binding_elision_opt assignment_element_list ',' binding_elision_opt assignment_rest_element opt_trailing_comma ']'
      { ASTList *list = ast_list_concat($2, $3); list = ast_list_concat(list, $5); $$ = ast_make_array_binding(ast_list_append(list, $6)); }
  | '[' binding_elision_opt assignment_rest_element opt_trailing_comma ']'
      { ASTList *list = ast_list_concat($2, ast_list_append(NULL, $3)); $$ = ast_make_array_binding(list); }
  ;

assignment_element_list
  : assignment_element
      { $$ = ast_list_append(NULL, $1); }
  | assignment_element_list ',' binding_elision_opt assignment_element
      { ASTList *list = ast_list_concat($1, $3); $$ = ast_list_append(list, $4); }
  ;

assignment_element
  : assignment_target binding_initializer_opt
      { $$ = ast_make_binding_pattern($1, $2); }
  ;

destructuring_assignment_target
    : object_assignment_pattern %dprec 2
            { $$ = $1; }
    | array_assignment_pattern %dprec 2
            { $$ = $1; }
    ;

destructuring_assignment_target_no_obj
    : array_assignment_pattern %dprec 2
        { $$ = $1; }
    ;

assignment_target
  : postfix_expr %dprec 1
      { $$ = $1; }
  | object_assignment_pattern %dprec 2
      { $$ = $1; }
  | array_assignment_pattern %dprec 2
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

void parser_set_module_mode(int enabled) {
    g_parser_module_mode = enabled != 0;
}

int parser_is_module_mode(void) {
    return g_parser_module_mode ? 1 : 0;
}
