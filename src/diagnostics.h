#ifndef DIAGNOSTICS_H
#define DIAGNOSTICS_H

void diag_reset(void);
void diag_set_current_file(const char *filename);
void diag_set_error_log_path(const char *path);
void diag_set_last_token_location(int line, int column);
void diag_record_error(const char *message);
int diag_last_line(void);
int diag_last_column(void);

#endif // DIAGNOSTICS_H
