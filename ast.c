#include "ast.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static ASTNode *ast_alloc(ASTNodeType type) {
    ASTNode *node = (ASTNode *)calloc(1, sizeof(ASTNode));
    if (!node) {
        fprintf(stderr, "Out of memory while constructing AST\n");
        exit(EXIT_FAILURE);
    }
    node->type = type;
    return node;
}

static char *strip_quotes(char *text) {
    if (!text) {
        return NULL;
    }
    size_t len = strlen(text);
    if (len >= 2 && (text[0] == '"' || text[0] == '\'')) {
        memmove(text, text + 1, len - 2);
        text[len - 2] = '\0';
    }
    return text;
}

ASTList *ast_list_append(ASTList *list, ASTNode *node) {
    if (!node) {
        return list;
    }
    ASTList *item = (ASTList *)calloc(1, sizeof(ASTList));
    if (!item) {
        fprintf(stderr, "Out of memory while constructing AST list\n");
        exit(EXIT_FAILURE);
    }
    item->node = node;
    if (!list) {
        return item;
    }
    ASTList *tail = list;
    while (tail->next) {
        tail = tail->next;
    }
    tail->next = item;
    return list;
}

ASTList *ast_list_concat(ASTList *head, ASTList *tail) {
    if (!head) {
        return tail;
    }
    ASTList *iter = head;
    while (iter->next) {
        iter = iter->next;
    }
    iter->next = tail;
    return head;
}

void ast_list_free(ASTList *list) {
    while (list) {
        ASTList *next = list->next;
        if (list->node) {
            ast_free(list->node);
        }
        free(list);
        list = next;
    }
}

ASTNode *ast_make_program(ASTList *body) {
    ASTNode *node = ast_alloc(AST_PROGRAM);
    node->data.program.body = body;
    return node;
}

ASTNode *ast_make_block(ASTList *body) {
    ASTNode *node = ast_alloc(AST_BLOCK);
    node->data.block.body = body;
    return node;
}

ASTNode *ast_make_var_decl(ASTNode *binding) {
    ASTNode *node = ast_alloc(AST_VAR_DECL);
    node->data.var_decl.binding = binding;
    return node;
}

ASTNode *ast_make_var_stmt(ASTVarKind kind, ASTList *decls) {
    ASTNode *node = ast_alloc(AST_VAR_STMT);
    node->data.var_stmt.kind = kind;
    node->data.var_stmt.decls = decls;
    return node;
}

ASTNode *ast_make_binding_pattern(ASTNode *target, ASTNode *initializer) {
    ASTNode *node = ast_alloc(AST_BINDING_PATTERN);
    node->data.binding_pattern.target = target;
    node->data.binding_pattern.initializer = initializer;
    return node;
}

ASTNode *ast_make_object_binding(ASTList *properties) {
    ASTNode *node = ast_alloc(AST_OBJECT_BINDING);
    node->data.object_binding.properties = properties;
    return node;
}

ASTNode *ast_make_array_binding(ASTList *elements) {
    ASTNode *node = ast_alloc(AST_ARRAY_BINDING);
    node->data.array_binding.elements = elements;
    return node;
}

ASTNode *ast_make_binding_property(char *key, bool is_identifier, ASTNode *value, bool is_shorthand) {
    ASTNode *node = ast_alloc(AST_BINDING_PROPERTY);
    if (is_identifier) {
        node->data.binding_property.key.name = key;
        node->data.binding_property.key.is_identifier = true;
    } else {
        if (key && (key[0] == '\'' || key[0] == '"')) {
            node->data.binding_property.key.name = strip_quotes(key);
        } else {
            node->data.binding_property.key.name = key;
        }
        node->data.binding_property.key.is_identifier = false;
    }
    node->data.binding_property.value = value;
    node->data.binding_property.is_shorthand = is_shorthand;
    return node;
}

ASTNode *ast_make_rest_element(ASTNode *argument) {
    ASTNode *node = ast_alloc(AST_REST_ELEMENT);
    node->data.rest_element.argument = argument;
    return node;
}

ASTNode *ast_make_array_hole(void) {
    return ast_alloc(AST_ARRAY_HOLE);
}

ASTNode *ast_make_function_decl(char *name, ASTList *params, ASTNode *body) {
    ASTNode *node = ast_alloc(AST_FUNCTION_DECL);
    node->data.function_decl.name = name;
    node->data.function_decl.params = params;
    node->data.function_decl.body = body;
    return node;
}

ASTNode *ast_make_function_expr(char *name, ASTList *params, ASTNode *body){
    ASTNode *node = ast_alloc(AST_FUNCTION_EXPR);
    node->data.function_expr.name = name;
    node->data.function_expr.params = params;
    node->data.function_expr.body = body;
    return node;
}

ASTNode *ast_make_arrow_function(ASTList *params, ASTNode *body, bool is_expression_body) {
    ASTNode *node = ast_alloc(AST_ARROW_FUNCTION);
    node->data.arrow_function.params = params;
    node->data.arrow_function.body = body;
    node->data.arrow_function.is_expression_body = is_expression_body;
    return node;
}

ASTNode *ast_make_return(ASTNode *argument) {
    ASTNode *node = ast_alloc(AST_RETURN_STMT);
    node->data.return_stmt.argument = argument;
    return node;
}

ASTNode *ast_make_if(ASTNode *test, ASTNode *consequent, ASTNode *alternate) {
    ASTNode *node = ast_alloc(AST_IF_STMT);
    node->data.if_stmt.test = test;
    node->data.if_stmt.consequent = consequent;
    node->data.if_stmt.alternate = alternate;
    return node;
}

ASTNode *ast_make_for(ASTNode *init, ASTNode *test, ASTNode *update, ASTNode *body) {
    ASTNode *node = ast_alloc(AST_FOR_STMT);
    node->data.for_stmt.init = init;
    node->data.for_stmt.test = test;
    node->data.for_stmt.update = update;
    node->data.for_stmt.body = body;
    return node;
}

ASTNode *ast_make_for_in(ASTNode *init, ASTNode *obj, ASTNode *body) {
    ASTNode *node = ast_alloc(AST_FOR_IN_STMT);
    node->data.for_in_stmt.init = init;
    node->data.for_in_stmt.obj = obj;
    node->data.for_in_stmt.body = body;
    return node;
}

ASTNode *ast_make_while(ASTNode *test, ASTNode *body) {
    ASTNode *node = ast_alloc(AST_WHILE_STMT);
    node->data.while_stmt.test = test;
    node->data.while_stmt.body = body;
    return node;
}

ASTNode *ast_make_do_while(ASTNode *body, ASTNode *test) {
    ASTNode *node = ast_alloc(AST_DO_WHILE_STMT);
    node->data.do_while_stmt.body = body;
    node->data.do_while_stmt.test = test;
    return node;
}

ASTNode *ast_make_switch(ASTNode *discriminant, ASTList *cases) {
    ASTNode *node = ast_alloc(AST_SWITCH_STMT);
    node->data.switch_stmt.discriminant = discriminant;
    node->data.switch_stmt.cases = cases;
    return node;
}

ASTNode *ast_make_switch_case(ASTNode *test, ASTList *consequent) {
    ASTNode *node = ast_alloc(AST_SWITCH_CASE);
    node->data.switch_case.test = test;
    node->data.switch_case.consequent = consequent;
    node->data.switch_case.is_default = false;
    return node;
}

ASTNode *ast_make_switch_default(ASTList *consequent) {
    ASTNode *node = ast_alloc(AST_SWITCH_CASE);
    node->data.switch_case.test = NULL;
    node->data.switch_case.consequent = consequent;
    node->data.switch_case.is_default = true;
    return node;
}

ASTNode *ast_make_try(ASTNode *block, ASTNode *handler, ASTNode *finalizer) {
    ASTNode *node = ast_alloc(AST_TRY_STMT);
    node->data.try_stmt.block = block;
    node->data.try_stmt.handler = handler;
    node->data.try_stmt.finalizer = finalizer;
    return node;
}

ASTNode *ast_make_catch(ASTNode *param, ASTNode *body) {
    ASTNode *node = ast_alloc(AST_CATCH_CLAUSE);
    node->data.catch_clause.param = param;
    node->data.catch_clause.body = body;
    return node;
}

ASTNode *ast_make_with(ASTNode *object, ASTNode *body) {
    ASTNode *node = ast_alloc(AST_WITH_STMT);
    node->data.with_stmt.object = object;
    node->data.with_stmt.body = body;
    return node;
}

ASTNode *ast_make_labeled(char *label, ASTNode *body) {
    ASTNode *node = ast_alloc(AST_LABELED_STMT);
    node->data.labeled_stmt.label = label;
    node->data.labeled_stmt.body = body;
    return node;
}

ASTNode *ast_make_break(char *label) {
    ASTNode *node = ast_alloc(AST_BREAK_STMT);
    node->data.break_stmt.label = label;
    return node;
}

ASTNode *ast_make_continue(char *label) {
    ASTNode *node = ast_alloc(AST_CONTINUE_STMT);
    node->data.continue_stmt.label = label;
    return node;
}

ASTNode *ast_make_throw(ASTNode *argument) {
    ASTNode *node = ast_alloc(AST_THROW_STMT);
    node->data.throw_stmt.argument = argument;
    return node;
}

ASTNode *ast_make_expression_stmt(ASTNode *expression) {
    ASTNode *node = ast_alloc(AST_EXPR_STMT);
    node->data.expr_stmt.expression = expression;
    return node;
}

ASTNode *ast_make_empty_statement(void) {
    return ast_alloc(AST_EMPTY_STMT);
}

ASTNode *ast_make_identifier(char *name) {
    ASTNode *node = ast_alloc(AST_IDENTIFIER);
    node->data.identifier.name = name;
    return node;
}

ASTNode *ast_make_this_expr(void)
{
    ASTNode *node = ast_alloc(AST_THIS);
    return node;
}

ASTNode *ast_make_number_literal(char *raw) {
    ASTNode *node = ast_alloc(AST_LITERAL);
    node->data.literal.literal_type = AST_LITERAL_NUMBER;
    if (raw) {
        node->data.literal.value.number = strtod(raw, NULL);
        free(raw);
    } else {
        node->data.literal.value.number = 0.0;
    }
    return node;
}

ASTNode *ast_make_string_literal(char *raw) {
    ASTNode *node = ast_alloc(AST_LITERAL);
    node->data.literal.literal_type = AST_LITERAL_STRING;
    node->data.literal.value.string = strip_quotes(raw);
    return node;
}

ASTNode *ast_make_string_literal_raw(char *raw) {
    ASTNode *node = ast_alloc(AST_LITERAL);
    node->data.literal.literal_type = AST_LITERAL_STRING;
    if (raw) {
        node->data.literal.value.string = raw;
    } else {
        node->data.literal.value.string = (char *)calloc(1, sizeof(char));
    }
    return node;
}

ASTNode *ast_make_regex_literal(char *raw) {
    ASTNode *node = ast_alloc(AST_LITERAL);
    node->data.literal.literal_type = AST_LITERAL_REGEX;
    node->data.literal.value.string = raw;
    return node;
}

ASTNode *ast_make_boolean_literal(bool value) {
    ASTNode *node = ast_alloc(AST_LITERAL);
    node->data.literal.literal_type = AST_LITERAL_BOOLEAN;
    node->data.literal.value.boolean = value;
    return node;
}

ASTNode *ast_make_null_literal(void) {
    ASTNode *node = ast_alloc(AST_LITERAL);
    node->data.literal.literal_type = AST_LITERAL_NULL;
    return node;
}

ASTNode *ast_make_undefined_literal(void) {
    ASTNode *node = ast_alloc(AST_LITERAL);
    node->data.literal.literal_type = AST_LITERAL_UNDEFINED;
    return node;
}

ASTNode *ast_make_assignment(const char *op, ASTNode *left, ASTNode *right) {
    ASTNode *node = ast_alloc(AST_ASSIGN_EXPR);
    node->data.assign.op = op;
    node->data.assign.left = left;
    node->data.assign.right = right;
    return node;
}

ASTNode *ast_make_binary(const char *op, ASTNode *left, ASTNode *right) {
    ASTNode *node = ast_alloc(AST_BINARY_EXPR);
    node->data.binary.op = op;
    node->data.binary.left = left;
    node->data.binary.right = right;
    return node;
}

ASTNode *ast_make_conditional(ASTNode *test, ASTNode *consequent, ASTNode *alternate) {
    ASTNode *node = ast_alloc(AST_CONDITIONAL_EXPR);
    node->data.conditional.test = test;
    node->data.conditional.consequent = consequent;
    node->data.conditional.alternate = alternate;
    return node;
}

ASTNode *ast_make_sequence(ASTNode *left, ASTNode *right) {
    if (!left) {
        return right;
    }
    ASTNode *node = left;
    if (left->type == AST_SEQUENCE_EXPR) {
        node->data.sequence.elements = ast_list_append(node->data.sequence.elements, right);
        return node;
    }
    node = ast_alloc(AST_SEQUENCE_EXPR);
    ASTList *items = NULL;
    items = ast_list_append(items, left);
    items = ast_list_append(items, right);
    node->data.sequence.elements = items;
    return node;
}

ASTNode *ast_make_unary(const char *op, ASTNode *argument) {
    ASTNode *node = ast_alloc(AST_UNARY_EXPR);
    node->data.unary.op = op;
    node->data.unary.argument = argument;
    return node;
}

ASTNode *ast_make_new_expr(ASTNode *callee, ASTList *arguments)
{
    ASTNode *node = ast_alloc(AST_NEW_EXPR);
    node->data.new_expr.callee = callee;
    node->data.new_expr.arguments = arguments;
    return node;
}

ASTNode *ast_make_update(const char *op, ASTNode *argument, bool prefix) {
    ASTNode *node = ast_alloc(AST_UPDATE_EXPR);
    node->data.update.op = op;
    node->data.update.argument = argument;
    node->data.update.prefix = prefix;
    return node;
}

ASTNode *ast_make_call(ASTNode *callee, ASTList *arguments) {
    ASTNode *node = ast_alloc(AST_CALL_EXPR);
    node->data.call_expr.callee = callee;
    node->data.call_expr.arguments = arguments;
    return node;
}

ASTNode *ast_make_member(ASTNode *object, ASTNode *property, bool computed) {
    ASTNode *node = ast_alloc(AST_MEMBER_EXPR);
    node->data.member_expr.object = object;
    node->data.member_expr.property = property;
    node->data.member_expr.computed = computed;
    return node;
}

ASTNode *ast_make_array_literal(ASTList *elements) {
    ASTNode *node = ast_alloc(AST_ARRAY_LITERAL);
    node->data.array_literal.elements = elements;
    return node;
}

ASTNode *ast_make_object_literal(ASTList *properties) {
    ASTNode *node = ast_alloc(AST_OBJECT_LITERAL);
    node->data.object_literal.properties = properties;
    return node;
}

ASTNode *ast_make_property(char *key, bool is_identifier, ASTNode *value) {
    ASTNode *node = ast_alloc(AST_PROPERTY);
    if (is_identifier) {
        node->data.property.key.name = key;
        node->data.property.key.is_identifier = true;
    } else {
        // 非标识符属性名（STRING 或 NUMBER）：
        // - STRING 类型：剥离引号（保持原有逻辑）
        // - NUMBER 类型：直接使用原 key
        if (key != NULL && (key[0] == '\'' || key[0] == '"')) {
            node->data.property.key.name = strip_quotes(key);
        } else {
            node->data.property.key.name = key;
        }
        node->data.property.key.is_identifier = false;
    }

    node->data.property.value = value;
    return node;
}

static void ast_traverse_list(ASTList *list, ASTVisitFn visitor, void *userdata) {
    for (ASTList *iter = list; iter; iter = iter->next) {
        if (iter->node) {
            ast_traverse(iter->node, visitor, userdata);
        }
    }
}

void ast_traverse(ASTNode *node, ASTVisitFn visitor, void *userdata) {
    if (!node || !visitor) {
        return;
    }
    visitor(node, userdata);
    switch (node->type) {
        case AST_PROGRAM:
            ast_traverse_list(node->data.program.body, visitor, userdata);
            break;
        case AST_BLOCK:
            ast_traverse_list(node->data.block.body, visitor, userdata);
            break;
        case AST_VAR_DECL:
            ast_traverse(node->data.var_decl.binding, visitor, userdata);
            break;
        case AST_VAR_STMT:
            ast_traverse_list(node->data.var_stmt.decls, visitor, userdata);
            break;
        case AST_FUNCTION_DECL:
            ast_traverse_list(node->data.function_decl.params, visitor, userdata);
            ast_traverse(node->data.function_decl.body, visitor, userdata);
            break;
        case AST_FUNCTION_EXPR:
            ast_traverse_list(node->data.function_expr.params, visitor, userdata);
            ast_traverse(node->data.function_expr.body, visitor, userdata);
            break;
        case AST_ARROW_FUNCTION:
            ast_traverse_list(node->data.arrow_function.params, visitor, userdata);
            ast_traverse(node->data.arrow_function.body, visitor, userdata);
            break;
        case AST_RETURN_STMT:
            ast_traverse(node->data.return_stmt.argument, visitor, userdata);
            break;
        case AST_IF_STMT:
            ast_traverse(node->data.if_stmt.test, visitor, userdata);
            ast_traverse(node->data.if_stmt.consequent, visitor, userdata);
            ast_traverse(node->data.if_stmt.alternate, visitor, userdata);
            break;
        case AST_FOR_STMT:
            ast_traverse(node->data.for_stmt.init, visitor, userdata);
            ast_traverse(node->data.for_stmt.test, visitor, userdata);
            ast_traverse(node->data.for_stmt.update, visitor, userdata);
            ast_traverse(node->data.for_stmt.body, visitor, userdata);
            break;
        case AST_FOR_IN_STMT:
            ast_traverse(node->data.for_in_stmt.init, visitor, userdata);
            ast_traverse(node->data.for_in_stmt.obj, visitor, userdata);
            ast_traverse(node->data.for_in_stmt.body, visitor, userdata);
            break;
        case AST_WHILE_STMT:
            ast_traverse(node->data.while_stmt.test, visitor, userdata);
            ast_traverse(node->data.while_stmt.body, visitor, userdata);
            break;
        case AST_DO_WHILE_STMT:
            ast_traverse(node->data.do_while_stmt.body, visitor, userdata);
            ast_traverse(node->data.do_while_stmt.test, visitor, userdata);
            break;
        case AST_SWITCH_STMT:
            ast_traverse(node->data.switch_stmt.discriminant, visitor, userdata);
            ast_traverse_list(node->data.switch_stmt.cases, visitor, userdata);
            break;
        case AST_TRY_STMT:
            ast_traverse(node->data.try_stmt.block, visitor, userdata);
            ast_traverse(node->data.try_stmt.handler, visitor, userdata);
            ast_traverse(node->data.try_stmt.finalizer, visitor, userdata);
            break;
        case AST_WITH_STMT:
            ast_traverse(node->data.with_stmt.object, visitor, userdata);
            ast_traverse(node->data.with_stmt.body, visitor, userdata);
            break;
        case AST_LABELED_STMT:
            ast_traverse(node->data.labeled_stmt.body, visitor, userdata);
            break;
        case AST_BREAK_STMT:
        case AST_CONTINUE_STMT:
            break;
        case AST_THROW_STMT:
            ast_traverse(node->data.throw_stmt.argument, visitor, userdata);
            break;
        case AST_EXPR_STMT:
            ast_traverse(node->data.expr_stmt.expression, visitor, userdata);
            break;
        case AST_ASSIGN_EXPR:
            ast_traverse(node->data.assign.left, visitor, userdata);
            ast_traverse(node->data.assign.right, visitor, userdata);
            break;
        case AST_BINARY_EXPR:
            ast_traverse(node->data.binary.left, visitor, userdata);
            ast_traverse(node->data.binary.right, visitor, userdata);
            break;
        case AST_CONDITIONAL_EXPR:
            ast_traverse(node->data.conditional.test, visitor, userdata);
            ast_traverse(node->data.conditional.consequent, visitor, userdata);
            ast_traverse(node->data.conditional.alternate, visitor, userdata);
            break;
        case AST_SEQUENCE_EXPR:
            ast_traverse_list(node->data.sequence.elements, visitor, userdata);
            break;
        case AST_UNARY_EXPR:
            ast_traverse(node->data.unary.argument, visitor, userdata);
            break;
        case AST_NEW_EXPR:
            ast_traverse(node->data.new_expr.callee, visitor, userdata);
            ast_traverse_list(node->data.new_expr.arguments, visitor, userdata);
            break;
        case AST_UPDATE_EXPR:
            ast_traverse(node->data.update.argument, visitor, userdata);
            break;
        case AST_CALL_EXPR:
            ast_traverse(node->data.call_expr.callee, visitor, userdata);
            ast_traverse_list(node->data.call_expr.arguments, visitor, userdata);
            break;
        case AST_MEMBER_EXPR:
            ast_traverse(node->data.member_expr.object, visitor, userdata);
            ast_traverse(node->data.member_expr.property, visitor, userdata);
            break;
        case AST_ARRAY_LITERAL:
            ast_traverse_list(node->data.array_literal.elements, visitor, userdata);
            break;
        case AST_OBJECT_LITERAL:
            ast_traverse_list(node->data.object_literal.properties, visitor, userdata);
            break;
        case AST_PROPERTY:
            ast_traverse(node->data.property.value, visitor, userdata);
            break;
        case AST_SWITCH_CASE:
            ast_traverse(node->data.switch_case.test, visitor, userdata);
            ast_traverse_list(node->data.switch_case.consequent, visitor, userdata);
            break;
        case AST_CATCH_CLAUSE:
            ast_traverse(node->data.catch_clause.param, visitor, userdata);
            ast_traverse(node->data.catch_clause.body, visitor, userdata);
            break;
        case AST_BINDING_PATTERN:
            ast_traverse(node->data.binding_pattern.target, visitor, userdata);
            ast_traverse(node->data.binding_pattern.initializer, visitor, userdata);
            break;
        case AST_OBJECT_BINDING:
            ast_traverse_list(node->data.object_binding.properties, visitor, userdata);
            break;
        case AST_ARRAY_BINDING:
            ast_traverse_list(node->data.array_binding.elements, visitor, userdata);
            break;
        case AST_BINDING_PROPERTY:
            ast_traverse(node->data.binding_property.value, visitor, userdata);
            break;
        case AST_REST_ELEMENT:
            ast_traverse(node->data.rest_element.argument, visitor, userdata);
            break;
        case AST_ARRAY_HOLE:
            break;
        case AST_EMPTY_STMT:
        case AST_IDENTIFIER:
        case AST_THIS:
        case AST_LITERAL:
            break;
    }
}

static void print_indent(int indent) {
    for (int i = 0; i < indent; ++i) {
        putchar(' ');
    }
}

static const char *var_kind_to_string(ASTVarKind kind) {
    switch (kind) {
        case AST_VAR_KIND_VAR:   return "var";
        case AST_VAR_KIND_LET:   return "let";
        case AST_VAR_KIND_CONST: return "const";
        default:                 return "unknown";
    }
}

static void ast_print_internal(const ASTNode *node, int indent);

static void ast_print_list(const ASTList *list, int indent) {
    for (const ASTList *iter = list; iter; iter = iter->next) {
        ast_print_internal(iter->node, indent);
    }
}

static void ast_print_internal(const ASTNode *node, int indent) {
    if (!node) {
        return;
    }
    switch (node->type) {
        case AST_PROGRAM:
            print_indent(indent);
            printf("Program\n");
            ast_print_list(node->data.program.body, indent + 2);
            break;
        case AST_BLOCK:
            print_indent(indent);
            printf("BlockStatement\n");
            ast_print_list(node->data.block.body, indent + 2);
            break;
        case AST_VAR_DECL:
            print_indent(indent);
            printf("VariableDeclaration\n");
            ast_print_internal(node->data.var_decl.binding, indent + 2);
            break;
        case AST_VAR_STMT:
            print_indent(indent);
            printf("VariableStatement kind=%s\n",
                var_kind_to_string(node->data.var_stmt.kind));
            ast_print_list(node->data.var_stmt.decls, indent + 2);
            break;
        case AST_FUNCTION_DECL:
            print_indent(indent);
            printf("FunctionDeclaration name=%s\n",
                   node->data.function_decl.name ? node->data.function_decl.name : "<anonymous>");
            if (node->data.function_decl.params) {
                print_indent(indent + 2);
                printf("Params\n");
                ast_print_list(node->data.function_decl.params, indent + 4);
            }
            print_indent(indent + 2);
            printf("Body\n");
            ast_print_internal(node->data.function_decl.body, indent + 4);
            break;
        case AST_FUNCTION_EXPR:
            print_indent(indent);
            printf("FunctionExpression name=%s\n",
                   node->data.function_expr.name ? node->data.function_expr.name : "<anonymous>");
            if (node->data.function_expr.params) {
                print_indent(indent + 2);
                printf("Params\n");
                ast_print_list(node->data.function_expr.params, indent + 4);
            }
            print_indent(indent + 2);
            printf("Body\n");
            ast_print_internal(node->data.function_expr.body, indent + 4);
            break;
        case AST_ARROW_FUNCTION:
            print_indent(indent);
            printf("ArrowFunction expressionBody=%s\n",
                   node->data.arrow_function.is_expression_body ? "true" : "false");
            if (node->data.arrow_function.params) {
                print_indent(indent + 2);
                printf("Params\n");
                ast_print_list(node->data.arrow_function.params, indent + 4);
            }
            print_indent(indent + 2);
            printf("Body\n");
            ast_print_internal(node->data.arrow_function.body, indent + 4);
            break;
        case AST_RETURN_STMT:
            print_indent(indent);
            printf("ReturnStatement\n");
            ast_print_internal(node->data.return_stmt.argument, indent + 2);
            break;
        case AST_IF_STMT:
            print_indent(indent);
            printf("IfStatement\n");
            print_indent(indent + 2);
            printf("Test\n");
            ast_print_internal(node->data.if_stmt.test, indent + 4);
            print_indent(indent + 2);
            printf("Consequent\n");
            ast_print_internal(node->data.if_stmt.consequent, indent + 4);
            if (node->data.if_stmt.alternate) {
                print_indent(indent + 2);
                printf("Alternate\n");
                ast_print_internal(node->data.if_stmt.alternate, indent + 4);
            }
            break;
        case AST_FOR_STMT:
            print_indent(indent);
            printf("ForStatement\n");
            print_indent(indent + 2);
            printf("Init\n");
            ast_print_internal(node->data.for_stmt.init, indent + 4);
            print_indent(indent + 2);
            printf("Test\n");
            ast_print_internal(node->data.for_stmt.test, indent + 4);
            print_indent(indent + 2);
            printf("Update\n");
            ast_print_internal(node->data.for_stmt.update, indent + 4);
            print_indent(indent + 2);
            printf("Body\n");
            ast_print_internal(node->data.for_stmt.body, indent + 4);
            break;
        case AST_FOR_IN_STMT:
            print_indent(indent);
            printf("ForStatement\n");
            print_indent(indent + 2);
            printf("Init\n");
            ast_print_internal(node->data.for_in_stmt.init, indent + 4);
            print_indent(indent + 2);
            printf("Object\n");
            ast_print_internal(node->data.for_in_stmt.obj, indent + 4);
            print_indent(indent + 2);
            printf("Body\n");
            ast_print_internal(node->data.for_in_stmt.body, indent + 4);
            break;
        case AST_WHILE_STMT:
            print_indent(indent);
            printf("WhileStatement\n");
            print_indent(indent + 2);
            printf("Test\n");
            ast_print_internal(node->data.while_stmt.test, indent + 4);
            print_indent(indent + 2);
            printf("Body\n");
            ast_print_internal(node->data.while_stmt.body, indent + 4);
            break;
        case AST_DO_WHILE_STMT:
            print_indent(indent);
            printf("DoWhileStatement\n");
            print_indent(indent + 2);
            printf("Body\n");
            ast_print_internal(node->data.do_while_stmt.body, indent + 4);
            print_indent(indent + 2);
            printf("Test\n");
            ast_print_internal(node->data.do_while_stmt.test, indent + 4);
            break;
        case AST_SWITCH_STMT:
            print_indent(indent);
            printf("SwitchStatement\n");
            print_indent(indent + 2);
            printf("Discriminant\n");
            ast_print_internal(node->data.switch_stmt.discriminant, indent + 4);
            if (node->data.switch_stmt.cases) {
                print_indent(indent + 2);
                printf("Cases\n");
                ast_print_list(node->data.switch_stmt.cases, indent + 4);
            }
            break;
        case AST_TRY_STMT:
            print_indent(indent);
            printf("TryStatement\n");
            print_indent(indent + 2);
            printf("Block\n");
            ast_print_internal(node->data.try_stmt.block, indent + 4);
            if (node->data.try_stmt.handler) {
                print_indent(indent + 2);
                printf("Handler\n");
                ast_print_internal(node->data.try_stmt.handler, indent + 4);
            }
            if (node->data.try_stmt.finalizer) {
                print_indent(indent + 2);
                printf("Finalizer\n");
                ast_print_internal(node->data.try_stmt.finalizer, indent + 4);
            }
            break;
        case AST_WITH_STMT:
            print_indent(indent);
            printf("WithStatement\n");
            print_indent(indent + 2);
            printf("Object\n");
            ast_print_internal(node->data.with_stmt.object, indent + 4);
            print_indent(indent + 2);
            printf("Body\n");
            ast_print_internal(node->data.with_stmt.body, indent + 4);
            break;
        case AST_LABELED_STMT:
            print_indent(indent);
            printf("LabeledStatement label=%s\n", node->data.labeled_stmt.label ? node->data.labeled_stmt.label : "");
            ast_print_internal(node->data.labeled_stmt.body, indent + 2);
            break;
        case AST_BREAK_STMT:
            print_indent(indent);
            printf("BreakStatement label=%s\n", node->data.break_stmt.label ? node->data.break_stmt.label : "<none>");
            break;
        case AST_CONTINUE_STMT:
            print_indent(indent);
            printf("ContinueStatement label=%s\n", node->data.continue_stmt.label ? node->data.continue_stmt.label : "<none>");
            break;
        case AST_THROW_STMT:
            print_indent(indent);
            printf("ThrowStatement\n");
            ast_print_internal(node->data.throw_stmt.argument, indent + 2);
            break;
        case AST_EXPR_STMT:
            print_indent(indent);
            printf("ExpressionStatement\n");
            ast_print_internal(node->data.expr_stmt.expression, indent + 2);
            break;
        case AST_EMPTY_STMT:
            print_indent(indent);
            printf("EmptyStatement\n");
            break;
        case AST_IDENTIFIER:
            print_indent(indent);
            printf("Identifier name=%s\n", node->data.identifier.name ? node->data.identifier.name : "<unnamed>");
            break;
        case AST_THIS:
            print_indent(indent);
            printf("ThisExpression\n");
            break;
        case AST_LITERAL:
            print_indent(indent);
            switch (node->data.literal.literal_type) {
                case AST_LITERAL_NUMBER:
                    printf("NumericLiteral value=%g\n", node->data.literal.value.number);
                    break;
                case AST_LITERAL_STRING:
                    printf("StringLiteral value=\"%s\"\n", node->data.literal.value.string ? node->data.literal.value.string : "");
                    break;
                case AST_LITERAL_REGEX:
                    printf("RegexLiteral value=\"%s\"\n", node->data.literal.value.string ? node->data.literal.value.string : "");
                    break;
                case AST_LITERAL_BOOLEAN:
                    printf("BooleanLiteral value=%s\n", node->data.literal.value.boolean ? "true" : "false");
                    break;
                case AST_LITERAL_NULL:
                    printf("NullLiteral\n");
                    break;
                case AST_LITERAL_UNDEFINED:
                    printf("UndefinedLiteral\n");
                    break;
            }
            break;
        case AST_ASSIGN_EXPR:
            print_indent(indent);
            printf("AssignmentExpression op=%s\n", node->data.assign.op ? node->data.assign.op : "=");
            print_indent(indent + 2);
            printf("Left\n");
            ast_print_internal(node->data.assign.left, indent + 4);
            print_indent(indent + 2);
            printf("Right\n");
            ast_print_internal(node->data.assign.right, indent + 4);
            break;
        case AST_BINARY_EXPR:
            print_indent(indent);
            printf("BinaryExpression op=%s\n", node->data.binary.op ? node->data.binary.op : "");
            print_indent(indent + 2);
            printf("Left\n");
            ast_print_internal(node->data.binary.left, indent + 4);
            print_indent(indent + 2);
            printf("Right\n");
            ast_print_internal(node->data.binary.right, indent + 4);
            break;
        case AST_CONDITIONAL_EXPR:
            print_indent(indent);
            printf("ConditionalExpression\n");
            print_indent(indent + 2);
            printf("Test\n");
            ast_print_internal(node->data.conditional.test, indent + 4);
            print_indent(indent + 2);
            printf("Consequent\n");
            ast_print_internal(node->data.conditional.consequent, indent + 4);
            print_indent(indent + 2);
            printf("Alternate\n");
            ast_print_internal(node->data.conditional.alternate, indent + 4);
            break;
        case AST_SEQUENCE_EXPR:
            print_indent(indent);
            printf("SequenceExpression\n");
            if (node->data.sequence.elements) {
                ast_print_list(node->data.sequence.elements, indent + 2);
            }
            break;
        case AST_UNARY_EXPR:
            print_indent(indent);
            printf("UnaryExpression op=%s\n", node->data.unary.op ? node->data.unary.op : "");
            ast_print_internal(node->data.unary.argument, indent + 2);
            break;
        case AST_NEW_EXPR:
            print_indent(indent);
            printf("NewExpression\n");
            print_indent(indent + 2);
            printf("Callee\n");
            ast_print_internal(node->data.new_expr.callee, indent + 4);
            if (node->data.new_expr.arguments) {
                print_indent(indent + 2);
                printf("Arguments\n");
                ast_print_list(node->data.new_expr.arguments, indent + 4);
            }
            break;
        case AST_UPDATE_EXPR:
            print_indent(indent);
            printf("UpdateExpression op=%s %s\n",
                   node->data.update.op ? node->data.update.op : "",
                   node->data.update.prefix ? "(prefix)" : "(postfix)");
            ast_print_internal(node->data.update.argument, indent + 2);
            break;
        case AST_CALL_EXPR:
            print_indent(indent);
            printf("CallExpression\n");
            print_indent(indent + 2);
            printf("Callee\n");
            ast_print_internal(node->data.call_expr.callee, indent + 4);
            if (node->data.call_expr.arguments) {
                print_indent(indent + 2);
                printf("Arguments\n");
                ast_print_list(node->data.call_expr.arguments, indent + 4);
            }
            break;
        case AST_MEMBER_EXPR:
            print_indent(indent);
            if (node->data.member_expr.computed) {
                printf("MemberExpression (computed)\n");
                print_indent(indent + 2);
                printf("Property (index expression)\n");
                ast_print_internal(node->data.member_expr.property, indent + 4);
            } else {
                printf("MemberExpression (property)\n");
                print_indent(indent + 2);
                printf("Property (identifier) ");
                if (node->data.member_expr.property && node->data.member_expr.property->type == AST_IDENTIFIER) {
                    printf("name=%s\n", node->data.member_expr.property->data.identifier.name);
                } else {
                    printf("<invalid>\n");
                }
            }
            print_indent(indent + 2);
            printf("Object\n");
            ast_print_internal(node->data.member_expr.object, indent + 4);
            break;
        case AST_ARRAY_LITERAL:
            print_indent(indent);
            printf("ArrayLiteral\n");
            if (node->data.array_literal.elements) {
                print_indent(indent + 2);
                printf("Elements\n");
                ast_print_list(node->data.array_literal.elements, indent + 4);
            }
            break;
        case AST_OBJECT_LITERAL:
            print_indent(indent);
            printf("ObjectLiteral\n");
            if (node->data.object_literal.properties) {
                print_indent(indent + 2);
                printf("Properties\n");
                ast_print_list(node->data.object_literal.properties, indent + 4);
            }
            break;
        case AST_PROPERTY:
            print_indent(indent);
            printf("Property key=%s%s\n",
                   node->data.property.key.name ? node->data.property.key.name : "<unknown>",
                   node->data.property.key.is_identifier ? " (identifier)" : "");
            ast_print_internal(node->data.property.value, indent + 2);
            break;
        case AST_SWITCH_CASE:
            print_indent(indent);
            printf("SwitchCase %s\n", node->data.switch_case.is_default ? "<default>" : "<case>");
            if (!node->data.switch_case.is_default) {
                print_indent(indent + 2);
                printf("Test\n");
                ast_print_internal(node->data.switch_case.test, indent + 4);
            }
            if (node->data.switch_case.consequent) {
                print_indent(indent + 2);
                printf("Consequent\n");
                ast_print_list(node->data.switch_case.consequent, indent + 4);
            }
            break;
        case AST_CATCH_CLAUSE:
            print_indent(indent);
            printf("CatchClause\n");
            if (node->data.catch_clause.param) {
                print_indent(indent + 2);
                printf("Param\n");
                ast_print_internal(node->data.catch_clause.param, indent + 4);
            }
            print_indent(indent + 2);
            printf("Body\n");
            ast_print_internal(node->data.catch_clause.body, indent + 4);
            break;
        case AST_BINDING_PATTERN:
            print_indent(indent);
            printf("BindingPattern\n");
            print_indent(indent + 2);
            printf("Target\n");
            ast_print_internal(node->data.binding_pattern.target, indent + 4);
            if (node->data.binding_pattern.initializer) {
                print_indent(indent + 2);
                printf("Initializer\n");
                ast_print_internal(node->data.binding_pattern.initializer, indent + 4);
            }
            break;
        case AST_OBJECT_BINDING:
            print_indent(indent);
            printf("ObjectBindingPattern\n");
            if (node->data.object_binding.properties) {
                print_indent(indent + 2);
                printf("Properties\n");
                ast_print_list(node->data.object_binding.properties, indent + 4);
            }
            break;
        case AST_ARRAY_BINDING:
            print_indent(indent);
            printf("ArrayBindingPattern\n");
            if (node->data.array_binding.elements) {
                print_indent(indent + 2);
                printf("Elements\n");
                ast_print_list(node->data.array_binding.elements, indent + 4);
            }
            break;
        case AST_BINDING_PROPERTY:
            print_indent(indent);
            printf("BindingProperty key=%s%s%s\n",
                   node->data.binding_property.key.name ? node->data.binding_property.key.name : "<unknown>",
                   node->data.binding_property.key.is_identifier ? " (identifier)" : "",
                   node->data.binding_property.is_shorthand ? " [shorthand]" : "");
            ast_print_internal(node->data.binding_property.value, indent + 2);
            break;
        case AST_REST_ELEMENT:
            print_indent(indent);
            printf("RestElement\n");
            ast_print_internal(node->data.rest_element.argument, indent + 2);
            break;
        case AST_ARRAY_HOLE:
            print_indent(indent);
            printf("ArrayHole\n");
            break;
    }
}

void ast_print(const ASTNode *node) {
    ast_print_internal(node, 0);
}

void ast_free(ASTNode *node) {
    if (!node) {
        return;
    }
    switch (node->type) {
        case AST_PROGRAM:
            ast_list_free(node->data.program.body);
            break;
        case AST_BLOCK:
            ast_list_free(node->data.block.body);
            break;
        case AST_VAR_DECL:
            ast_free(node->data.var_decl.binding);
            break;
        case AST_VAR_STMT:
            ast_list_free(node->data.var_stmt.decls);
            break;
        case AST_FUNCTION_DECL:
            free(node->data.function_decl.name);
            ast_list_free(node->data.function_decl.params);
            ast_free(node->data.function_decl.body);
            break;
        case AST_FUNCTION_EXPR:
            free(node->data.function_expr.name);
            ast_list_free(node->data.function_expr.params);
            ast_free(node->data.function_expr.body);
            break;
        case AST_ARROW_FUNCTION:
            ast_list_free(node->data.arrow_function.params);
            ast_free(node->data.arrow_function.body);
            break;
        case AST_RETURN_STMT:
            ast_free(node->data.return_stmt.argument);
            break;
        case AST_IF_STMT:
            ast_free(node->data.if_stmt.test);
            ast_free(node->data.if_stmt.consequent);
            ast_free(node->data.if_stmt.alternate);
            break;
        case AST_FOR_STMT:
            ast_free(node->data.for_stmt.init);
            ast_free(node->data.for_stmt.test);
            ast_free(node->data.for_stmt.update);
            ast_free(node->data.for_stmt.body);
            break;
        case AST_FOR_IN_STMT:
            ast_free(node->data.for_in_stmt.init);
            ast_free(node->data.for_in_stmt.obj);
            ast_free(node->data.for_in_stmt.body);
            break;
        case AST_WHILE_STMT:
            ast_free(node->data.while_stmt.test);
            ast_free(node->data.while_stmt.body);
            break;
        case AST_DO_WHILE_STMT:
            ast_free(node->data.do_while_stmt.body);
            ast_free(node->data.do_while_stmt.test);
            break;
        case AST_SWITCH_STMT:
            ast_free(node->data.switch_stmt.discriminant);
            ast_list_free(node->data.switch_stmt.cases);
            break;
        case AST_TRY_STMT:
            ast_free(node->data.try_stmt.block);
            ast_free(node->data.try_stmt.handler);
            ast_free(node->data.try_stmt.finalizer);
            break;
        case AST_WITH_STMT:
            ast_free(node->data.with_stmt.object);
            ast_free(node->data.with_stmt.body);
            break;
        case AST_LABELED_STMT:
            free(node->data.labeled_stmt.label);
            ast_free(node->data.labeled_stmt.body);
            break;
        case AST_BREAK_STMT:
            free(node->data.break_stmt.label);
            break;
        case AST_CONTINUE_STMT:
            free(node->data.continue_stmt.label);
            break;
        case AST_THROW_STMT:
            ast_free(node->data.throw_stmt.argument);
            break;
        case AST_EXPR_STMT:
            ast_free(node->data.expr_stmt.expression);
            break;
        case AST_EMPTY_STMT:
            break;
        case AST_IDENTIFIER:
            free(node->data.identifier.name);
            break;
        case AST_THIS:
            break;
        case AST_LITERAL:
            if (node->data.literal.literal_type == AST_LITERAL_STRING
                || node->data.literal.literal_type == AST_LITERAL_REGEX) {
                free(node->data.literal.value.string);
            }
            break;
        case AST_ASSIGN_EXPR:
            ast_free(node->data.assign.left);
            ast_free(node->data.assign.right);
            break;
        case AST_BINARY_EXPR:
            ast_free(node->data.binary.left);
            ast_free(node->data.binary.right);
            break;
        case AST_CONDITIONAL_EXPR:
            ast_free(node->data.conditional.test);
            ast_free(node->data.conditional.consequent);
            ast_free(node->data.conditional.alternate);
            break;
        case AST_SEQUENCE_EXPR:
            ast_list_free(node->data.sequence.elements);
            break;
        case AST_UNARY_EXPR:
            ast_free(node->data.unary.argument);
            break;
        case AST_NEW_EXPR:
            ast_free(node->data.new_expr.callee);
            ast_list_free(node->data.new_expr.arguments);
            break;
        case AST_UPDATE_EXPR:
            ast_free(node->data.update.argument);
            break;
        case AST_CALL_EXPR:
            ast_free(node->data.call_expr.callee);
            ast_list_free(node->data.call_expr.arguments);
            break;
        case AST_MEMBER_EXPR:
            ast_free(node->data.member_expr.object);
            ast_free(node->data.member_expr.property);
            break;
        case AST_ARRAY_LITERAL:
            ast_list_free(node->data.array_literal.elements);
            break;
        case AST_OBJECT_LITERAL:
            ast_list_free(node->data.object_literal.properties);
            break;
        case AST_PROPERTY:
            free(node->data.property.key.name);
            ast_free(node->data.property.value);
            break;
        case AST_SWITCH_CASE:
            ast_free(node->data.switch_case.test);
            ast_list_free(node->data.switch_case.consequent);
            break;
        case AST_CATCH_CLAUSE:
            ast_free(node->data.catch_clause.param);
            ast_free(node->data.catch_clause.body);
            break;
        case AST_BINDING_PATTERN:
            ast_free(node->data.binding_pattern.target);
            ast_free(node->data.binding_pattern.initializer);
            break;
        case AST_OBJECT_BINDING:
            ast_list_free(node->data.object_binding.properties);
            break;
        case AST_ARRAY_BINDING:
            ast_list_free(node->data.array_binding.elements);
            break;
        case AST_BINDING_PROPERTY:
            free(node->data.binding_property.key.name);
            ast_free(node->data.binding_property.value);
            break;
        case AST_REST_ELEMENT:
            ast_free(node->data.rest_element.argument);
            break;
        case AST_ARRAY_HOLE:
            break;
    }
    free(node);
}
