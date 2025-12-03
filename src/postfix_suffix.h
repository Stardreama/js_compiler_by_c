#ifndef POSTFIX_SUFFIX_H
#define POSTFIX_SUFFIX_H

#include "ast.h"

typedef enum
{
    POSTFIX_SUFFIX_PROP,
    POSTFIX_SUFFIX_COMPUTED,
    POSTFIX_SUFFIX_CALL,
    POSTFIX_SUFFIX_TEMPLATE
} PostfixSuffixKind;

typedef struct PostfixSuffix PostfixSuffix;

struct PostfixSuffix
{
    PostfixSuffixKind kind;
    union
    {
        char *property_name;
        ASTNode *computed_expr;
        ASTList *arguments;
        ASTNode *template_literal;
    } data;
    PostfixSuffix *next;
};

#endif /* POSTFIX_SUFFIX_H */
