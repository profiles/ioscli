#ifndef IOSCLI_CERT_H
#define IOSCLI_CERT_H

@class NSString;

int cert_main(int argc, char **argv, const char *prog);
int cert_add(NSString *path, int domain);
int cert_remove(NSString *path, int domain);
int cert_evaluate(NSString *path);
int cert_list(int domain);

#endif
