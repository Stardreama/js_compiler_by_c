#ifndef AST_H
#define AST_H

#include <stdbool.h>
#include <stddef.h>

typedef enum
{
    AST_PROGRAM,
    AST_BLOCK,
    AST_VAR_DECL,
    AST_VAR_STMT,
    AST_FUNCTION_DECL,
    AST_FUNCTION_EXPR,
    AST_ARROW_FUNCTION,
    AST_RETURN_STMT,
    AST_IF_STMT,
    AST_FOR_STMT,
    AST_FOR_IN_STMT,
    AST_FOR_OF_STMT,
    AST_WHILE_STMT,
    AST_DO_WHILE_STMT,
    AST_SWITCH_STMT,
    AST_TRY_STMT,
    AST_WITH_STMT,
    AST_LABELED_STMT,
    AST_BREAK_STMT,
    AST_CONTINUE_STMT,
    AST_THROW_STMT,
    AST_EXPR_STMT,
    AST_EMPTY_STMT,
    AST_IDENTIFIER,
    AST_THIS,
    AST_LITERAL,
    AST_TEMPLATE_LITERAL,
    AST_TEMPLATE_ELEMENT,
    AST_TAGGED_TEMPLATE,
    AST_ASSIGN_EXPR,
    AST_BINARY_EXPR,
    AST_CONDITIONAL_EXPR,
    AST_SEQUENCE_EXPR,
    AST_UNARY_EXPR,
    AST_NEW_EXPR,
    AST_UPDATE_EXPR,
    AST_CALL_EXPR,
    AST_MEMBER_EXPR,
    AST_YIELD_EXPR,
    AST_AWAIT_EXPR,
    AST_ARRAY_LITERAL,
    AST_OBJECT_LITERAL,
    AST_PROPERTY,
    AST_SWITCH_CASE,
    AST_CATCH_CLAUSE,
    AST_BINDING_PATTERN,
    AST_OBJECT_BINDING,
    AST_ARRAY_BINDING,
    AST_BINDING_PROPERTY,
    AST_REST_ELEMENT,
    AST_SPREAD_ELEMENT,
    AST_ARRAY_HOLE,
    AST_CLASS_DECL,
    AST_CLASS_EXPR,
    AST_METHOD_DEF,
    AST_SUPER,
    AST_COMPUTED_PROP,
    AST_IMPORT_DECL,
    AST_IMPORT_SPECIFIER,
    AST_EXPORT_DECL,
    AST_EXPORT_SPECIFIER
} ASTNodeType;

typedef enum
{
    AST_METHOD_KIND_NORMAL,
    AST_METHOD_KIND_GET,
    AST_METHOD_KIND_SET,
    AST_METHOD_KIND_CONSTRUCTOR
} ASTMethodKind;

typedef enum
{
    AST_VAR_KIND_VAR,
    AST_VAR_KIND_LET,
    AST_VAR_KIND_CONST
} ASTVarKind;

typedef enum
{
    AST_LITERAL_NUMBER,
    AST_LITERAL_STRING,
    AST_LITERAL_REGEX,
    AST_LITERAL_BOOLEAN,
    AST_LITERAL_NULL,
    AST_LITERAL_UNDEFINED
} ASTLiteralType;

typedef struct ASTNode ASTNode;

typedef struct ASTList
{
    ASTNode *node;
    struct ASTList *next;
} ASTList;

typedef struct
{
    char *name;
    bool is_identifier;
} ASTPropertyKey;

struct ASTNode
{
    ASTNodeType type;
    union
    {
        struct
        {
            ASTList *body;
        } program;
        struct
        {
            ASTList *body;
        } block;
        struct
        {
            ASTList *quasis;
            ASTList *expressions;
        } template_literal;
        struct
        {
            char *raw;
            bool is_tail;
        } template_element;
        struct
        {
            ASTNode *tag;
            ASTNode *template_literal;
        } tagged_template;
        struct
        {
            ASTNode *binding;
        } var_decl;
        struct
        {
            ASTVarKind kind;
            ASTList *decls;
        } var_stmt;
        struct
        {
            char *name;
            ASTList *params;
            ASTNode *body;
            bool is_generator;
            bool is_async;
        } function_decl;
        struct
        {
            char *name;
            ASTList *params;
            ASTNode *body;
            bool is_generator;
            bool is_async;
        } function_expr;
        struct
        {
            ASTList *params;
            ASTNode *body;
            bool is_expression_body;
            bool is_async;
        } arrow_function;
        struct
        {
            ASTNode *argument;
        } return_stmt;
        struct
        {
            ASTNode *test;
            ASTNode *consequent;
            ASTNode *alternate;
        } if_stmt;
        struct
        {
            ASTNode *init;
            ASTNode *test;
            ASTNode *update;
            ASTNode *body;
        } for_stmt;
        struct
        {
            ASTNode *init;
            ASTNode *obj;
            ASTNode *body;
        } for_in_stmt;
        struct
        {
            ASTNode *init;
            ASTNode *iterable;
            ASTNode *body;
            bool is_async;
        } for_of_stmt;
        struct
        {
            ASTNode *test;
            ASTNode *body;
        } while_stmt;
        struct
        {
            bool is_async;
            ASTNode *body;
            ASTNode *test;
        } do_while_stmt;
        struct
        {
            ASTNode *discriminant;
            ASTList *cases;
            bool is_async;
        } switch_stmt;
        struct
        {
            ASTNode *block;
            ASTNode *handler;
            ASTNode *finalizer;
            bool is_async;
        } try_stmt;
        struct
        {
            ASTNode *object;
            ASTNode *body;
        } with_stmt;
        struct
        {
            char *label;
            ASTNode *body;
        } labeled_stmt;
        struct
        {
            char *label;
        } break_stmt;
        struct
        {
            char *label;
        } continue_stmt;
        struct
        {
            ASTNode *argument;
        } throw_stmt;
        struct
        {
            ASTNode *expression;
        } expr_stmt;
        struct
        {
            char *name;
        } identifier;
        struct
        {
        } this_expr;
        struct
        {
            ASTLiteralType literal_type;
            union
            {
                double number;
                bool boolean;
                char *string;
            } value;
        } literal;
        struct
        {
            const char *op;
            ASTNode *left;
            ASTNode *right;
        } binary;
        struct
        {
            ASTNode *test;
            ASTNode *consequent;
            ASTNode *alternate;
        } conditional;
        struct
        {
            ASTList *elements;
        } sequence;
        struct
        {
            const char *op;
            ASTNode *left;
            ASTNode *right;
        } assign;
        struct
        {
            const char *op;
            ASTNode *argument;
        } unary;
        struct
        {
            ASTNode *callee;
            ASTList *arguments;
        } new_expr;
        struct
        {
            const char *op;
            ASTNode *argument;
            bool prefix;
        } update;
        struct
        {
            ASTNode *callee;
            ASTList *arguments;
        } call_expr;
        struct
        {
            ASTNode *object;
            ASTNode *property;
            bool computed;
        } member_expr;
        struct
        {
            ASTNode *argument;
            bool is_delegate;
        } yield_expr;
        struct
        {
            ASTNode *argument;
        } await_expr;
        struct
        {
            ASTList *elements;
        } array_literal;
        struct
        {
            ASTList *properties;
        } object_literal;
        struct
        {
            ASTPropertyKey key;
            ASTNode *value;
        } property;
        struct
        {
            ASTNode *test;
            ASTList *consequent;
            bool is_default;
        } switch_case;
        struct
        {
            ASTNode *param;
            ASTNode *body;
        } catch_clause;
        struct
        {
            ASTNode *target;
            ASTNode *initializer;
        } binding_pattern;
        struct
        {
            ASTList *properties;
        } object_binding;
        struct
        {
            ASTList *elements;
        } array_binding;
        struct
        {
            ASTPropertyKey key;
            ASTNode *value;
            bool is_shorthand;
        } binding_property;
        struct
        {
            ASTNode *argument;
        } rest_element;
        struct
        {
            ASTNode *argument;
        } spread_element;
        struct
        {
        } array_hole;
        struct
        {
            char *name;
            ASTNode *super_class;
            ASTList *body;
        } class_decl;
        struct
        {
            char *name;
            ASTNode *super_class;
            ASTList *body;
        } class_expr;
        struct
        {
            char *name;
            ASTNode *computed_key;
            bool computed;
            bool is_static;
            bool is_generator;
            bool is_async;
            ASTMethodKind kind;
            ASTNode *function;
        } method_def;
        struct
        {
        } super_expr;
        struct
        {
            ASTNode *key;
            ASTNode *value;
        } computed_prop;
        struct
        {
            ASTList *specifiers;
            ASTNode *source;
        } import_decl;
        struct
        {
            char *local_name;
            char *imported_name;
            bool is_namespace;
            bool is_default;
        } import_specifier;
        struct
        {
            bool is_default;
            bool export_all;
            char *export_all_alias;
            ASTNode *declaration;
            ASTList *specifiers;
            ASTNode *source;
        } export_decl;
        struct
        {
            char *local_name;
            char *exported_name;
            bool is_namespace;
        } export_specifier;
    } data;
};

typedef void (*ASTVisitFn)(ASTNode *node, void *userdata);

ASTList *ast_list_append(ASTList *list, ASTNode *node);
ASTList *ast_list_concat(ASTList *head, ASTList *tail);
void ast_list_free(ASTList *list);

ASTNode *ast_make_program(ASTList *body);
ASTNode *ast_make_block(ASTList *body);
ASTNode *ast_make_var_decl(ASTNode *binding);
ASTNode *ast_make_var_stmt(ASTVarKind kind, ASTList *decls);
ASTNode *ast_make_function_decl(char *name, ASTList *params, ASTNode *body);
ASTNode *ast_make_function_expr(char *name, ASTList *params, ASTNode *body);
ASTNode *ast_make_arrow_function(ASTList *params, ASTNode *body, bool is_expression_body);
ASTNode *ast_make_return(ASTNode *argument);
ASTNode *ast_make_if(ASTNode *test, ASTNode *consequent, ASTNode *alternate);
ASTNode *ast_make_for(ASTNode *init, ASTNode *test, ASTNode *update, ASTNode *body);
ASTNode *ast_make_for_in(ASTNode *init, ASTNode *obj, ASTNode *body);
ASTNode *ast_make_for_of(ASTNode *init, ASTNode *iterable, ASTNode *body, bool is_async);
ASTNode *ast_make_while(ASTNode *test, ASTNode *body);
ASTNode *ast_make_do_while(ASTNode *body, ASTNode *test);
ASTNode *ast_make_switch(ASTNode *discriminant, ASTList *cases);
ASTNode *ast_make_switch_case(ASTNode *test, ASTList *consequent);
ASTNode *ast_make_switch_default(ASTList *consequent);
ASTNode *ast_make_try(ASTNode *block, ASTNode *handler, ASTNode *finalizer);
ASTNode *ast_make_catch(ASTNode *param, ASTNode *body);
ASTNode *ast_make_with(ASTNode *object, ASTNode *body);
ASTNode *ast_make_labeled(char *label, ASTNode *body);
ASTNode *ast_make_break(char *label);
ASTNode *ast_make_continue(char *label);
ASTNode *ast_make_throw(ASTNode *argument);
ASTNode *ast_make_expression_stmt(ASTNode *expression);
ASTNode *ast_make_empty_statement(void);
ASTNode *ast_make_identifier(char *name);
ASTNode *ast_make_this_expr(void);
ASTNode *ast_make_number_literal(char *raw);
ASTNode *ast_make_string_literal(char *raw);
ASTNode *ast_make_string_literal_raw(char *raw);
ASTNode *ast_make_regex_literal(char *raw);
ASTNode *ast_make_boolean_literal(bool value);
ASTNode *ast_make_null_literal(void);
ASTNode *ast_make_undefined_literal(void);
ASTNode *ast_make_template_literal(ASTList *quasis, ASTList *expressions);
ASTNode *ast_make_template_element(char *raw, bool is_tail);
ASTNode *ast_make_tagged_template(ASTNode *tag, ASTNode *template_literal);
ASTNode *ast_make_assignment(const char *op, ASTNode *left, ASTNode *right);
ASTNode *ast_make_binary(const char *op, ASTNode *left, ASTNode *right);
ASTNode *ast_make_conditional(ASTNode *test, ASTNode *consequent, ASTNode *alternate);
ASTNode *ast_make_sequence(ASTNode *left, ASTNode *right);
ASTNode *ast_make_unary(const char *op, ASTNode *argument);
ASTNode *ast_make_new_expr(ASTNode *callee, ASTList *arguments);
ASTNode *ast_make_update(const char *op, ASTNode *argument, bool prefix);
ASTNode *ast_make_call(ASTNode *callee, ASTList *arguments);
ASTNode *ast_make_member(ASTNode *object, ASTNode *property, bool computed);
ASTNode *ast_make_yield(ASTNode *argument, bool is_delegate);
ASTNode *ast_make_await(ASTNode *argument);
ASTNode *ast_make_array_literal(ASTList *elements);
ASTNode *ast_make_object_literal(ASTList *properties);
ASTNode *ast_make_property(char *key, bool is_identifier, ASTNode *value);
ASTNode *ast_make_computed_property(ASTNode *key, ASTNode *value);
ASTNode *ast_make_binding_pattern(ASTNode *target, ASTNode *initializer);
ASTNode *ast_make_object_binding(ASTList *properties);
ASTNode *ast_make_array_binding(ASTList *elements);
ASTNode *ast_make_binding_property(char *key, bool is_identifier, ASTNode *value, bool is_shorthand);
ASTNode *ast_make_rest_element(ASTNode *argument);
ASTNode *ast_make_spread_element(ASTNode *argument);
ASTNode *ast_make_array_hole(void);
ASTNode *ast_make_class_decl(char *name, ASTNode *super_class, ASTList *body);
ASTNode *ast_make_class_expr(char *name, ASTNode *super_class, ASTList *body);
ASTNode *ast_make_method_def(char *name, ASTNode *computed_key, bool computed, bool is_static, bool is_generator, bool is_async, ASTMethodKind kind, ASTNode *function);
ASTNode *ast_make_super_expr(void);
ASTNode *ast_make_import_decl(ASTList *specifiers, ASTNode *source);
ASTNode *ast_make_import_specifier(char *local_name, char *imported_name, bool is_namespace, bool is_default);
ASTNode *ast_make_export_decl(bool is_default, bool export_all, char *export_all_alias, ASTNode *declaration, ASTList *specifiers, ASTNode *source);
ASTNode *ast_make_export_specifier(char *local_name, char *exported_name, bool is_namespace);

void ast_traverse(ASTNode *node, ASTVisitFn visitor, void *userdata);
void ast_print(const ASTNode *node);
void ast_free(ASTNode *node);

#endif /* AST_H */
