#include "diagnostics.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *g_current_file = NULL;
static char *g_log_path = NULL;
static int g_last_line = 1;
static int g_last_column = 1;

static char *dup_string(const char *src) {
    if (!src) {
        return NULL;
    }
    size_t len = strlen(src);
    char *copy = (char *)malloc(len + 1);
    if (!copy) {
        return NULL;
    }
    memcpy(copy, src, len + 1);
    return copy;
}

static void assign_string(char **target, const char *value) {
    if (*target) {
        free(*target);
        *target = NULL;
    }
    if (value) {
        *target = dup_string(value);
    }
}

void diag_reset(void) {
    g_last_line = 1;
    g_last_column = 1;
}

void diag_set_current_file(const char *filename) {
    assign_string(&g_current_file, filename);
}

void diag_set_error_log_path(const char *path) {
    assign_string(&g_log_path, path);
}

void diag_set_last_token_location(int line, int column) {
    if (line > 0) {
        g_last_line = line;
    }
    if (column > 0) {
        g_last_column = column;
    }
}

int diag_last_line(void) {
    return g_last_line;
}

int diag_last_column(void) {
    return g_last_column;
}

void diag_record_error(const char *message) {
    if (!g_log_path || !message) {
        return;
    }

    FILE *fp = fopen(g_log_path, "a");
    if (!fp) {
        return;
    }

    const char *file_label = g_current_file ? g_current_file : "<unknown>";
    fprintf(fp, "%s:%d:%d: %s\n", file_label, g_last_line, g_last_column, message);
    fclose(fp);
}
