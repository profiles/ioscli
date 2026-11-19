#import <Foundation/Foundation.h>
#import <unistd.h>
#import "cmd/cert.h"
#import "cmd/profile.h"
#include <string.h>

static const int kDefaultDomain = 2;

static void usage(const char *prog) {
    printf("usage: %s cert -a|--add <cert.der|pem|-> [-D|--domain N]\n", prog);
    printf("       %s cert -d|--remove <cert.der|pem|-> [-D|--domain N]\n", prog);
    printf("       %s cert -e|--evaluate <cert.der|pem|->\n", prog);
    printf("       %s cert -l|--list [-D|--domain N]\n", prog);
    printf("       %s profile -a|--add <mobileconfig|->\n", prog);
    printf("       %s profile -d|--remove <payload-identifier>\n", prog);
    printf("       %s profile -l|--list\n", prog);
    printf("\n");
    printf("  legacy aliases: %s -a/-d/-e/-l [-D domain]\n", prog);
    printf("  roothide note: paths differ per process context. The ssh shell's\n");
    printf("  /tmp is inside the jail, so a file copied there is NOT visible here.\n");
    printf("  Copy via the real filesystem instead:\n");
    printf("      cp ca.der /rootfs/tmp/ca.der   (from ssh shell)\n");
    printf("      %s cert -a /tmp/ca.der    (this tool sees the real /tmp)\n", prog);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc >= 2 && strcmp(argv[1], "cert") == 0) {
            return cert_main(argc - 1, argv + 1, argv[0]);
        }
        if (argc >= 2 && strcmp(argv[1], "profile") == 0) {
            return profile_main(argc - 1, argv + 1, argv[0]);
        }
        if (argc == 2 && (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0)) {
            usage(argv[0]);
            return 0;
        }
        int domain = kDefaultDomain;
        NSString *certPath = nil;
        int action = 0;
        int opt;
        while ((opt = getopt(argc, argv, "a:d:e:lD:h")) != -1) {
            switch (opt) {
                case 'a':
                case 'd':
                case 'e':
                    action = opt;
                    certPath = @(optarg);
                    break;
                case 'l': action = 'l'; break;
                case 'D': domain = atoi(optarg); break;
                case 'h': usage(argv[0]); return 0;
                default:  usage(argv[0]); return 2;
            }
        }
        switch (action) {
            case 'a': return cert_add(certPath, domain);
            case 'd': return cert_remove(certPath, domain);
            case 'e': return cert_evaluate(certPath);
            case 'l': return cert_list(domain);
            default:  usage(argv[0]); return 2;
        }
    }
}
