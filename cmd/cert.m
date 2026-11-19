#import "cert.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <getopt.h>
#include <stdio.h>
#include <string.h>

typedef struct __SecTrustStore *SecTrustStoreRef;
extern SecTrustStoreRef SecTrustStoreForDomain(int domain);
extern OSStatus SecTrustStoreSetTrustSettings(SecTrustStoreRef store, SecCertificateRef cert, CFTypeRef trustSettings);
extern OSStatus SecTrustStoreRemoveCertificate(SecTrustStoreRef store, SecCertificateRef cert);
extern OSStatus SecTrustStoreCopyAll(SecTrustStoreRef store, CFArrayRef *allOut);

static const int kDefaultDomain = 2;

static NSData *loadCertificateData(NSString *path) {
    NSData *raw = [path isEqualToString:@"-"]
        ? [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile]
        : [NSData dataWithContentsOfFile:path];
    if (raw.length == 0) return nil;
    if (raw.length > 11 && memcmp(raw.bytes, "-----BEGIN", 10) == 0) {
        NSString *text = [[NSString alloc] initWithData:raw encoding:NSUTF8StringEncoding];
        if (!text) return nil;
        NSMutableString *body = [NSMutableString string];
        for (NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            if (![line hasPrefix:@"-"]) [body appendString:line];
        }
        return [[NSData alloc] initWithBase64EncodedString:body options:0];
    }
    return raw;
}

static SecCertificateRef loadCert(NSString *path) {
    NSData *data = loadCertificateData(path);
    if (!data) {
        fprintf(stderr, "[-] cannot read %s\n", path.UTF8String);
        return nil;
    }
    SecCertificateRef cert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)data);
    if (!cert) {
        fprintf(stderr, "[-] not a valid certificate (DER/PEM): %s\n", path.UTF8String);
        return nil;
    }
    return cert;
}

static void describe(SecCertificateRef cert) {
    CFStringRef s = SecCertificateCopySubjectSummary(cert);
    if (!s) { printf("[+] cert: (no summary)\n"); return; }
    printf("[+] cert: %s\n", [(__bridge_transfer NSString *)s UTF8String]);
}

int cert_add(NSString *path, int domain) {
    SecCertificateRef cert = loadCert(path);
    if (!cert) return 1;
    describe(cert);
    SecTrustStoreRef store = SecTrustStoreForDomain(domain);
    if (!store) { fprintf(stderr, "[-] SecTrustStoreForDomain(%d) returned NULL\n", domain); return 1; }
    OSStatus st = SecTrustStoreSetTrustSettings(store, cert, NULL);
    printf("[+] add: %d\n", (int)st);
    CFRelease(cert);
    return st == errSecSuccess ? 0 : 1;
}

int cert_remove(NSString *path, int domain) {
    SecCertificateRef cert = loadCert(path);
    if (!cert) return 1;
    describe(cert);
    SecTrustStoreRef store = SecTrustStoreForDomain(domain);
    if (!store) { fprintf(stderr, "[-] SecTrustStoreForDomain(%d) returned NULL\n", domain); return 1; }
    OSStatus st = SecTrustStoreRemoveCertificate(store, cert);
    printf("[+] del: %d\n", (int)st);
    CFRelease(cert);
    return st == errSecSuccess ? 0 : 1;
}

int cert_evaluate(NSString *path) {
    SecCertificateRef cert = loadCert(path);
    if (!cert) return 1;
    describe(cert);
    SecTrustRef trust = NULL;
    OSStatus st = SecTrustCreateWithCertificates(cert, SecPolicyCreateBasicX509(), &trust);
    if (st != errSecSuccess) {
        fprintf(stderr, "[-] SecTrustCreateWithCertificates: %d\n", (int)st);
        return 1;
    }
    CFErrorRef err = NULL;
    BOOL trusted = SecTrustEvaluateWithError(trust, &err);
    printf("[+] eval: %s\n", trusted ? "TRUSTED" : "NOT TRUSTED");
    if (err) {
        NSString *d = (__bridge_transfer NSString *)CFErrorCopyDescription(err);
        printf("    %s\n", d.UTF8String);
    }
    CFRelease(trust);
    CFRelease(cert);
    return trusted ? 0 : 2;
}

int cert_list(int domain) {
    SecTrustStoreRef store = SecTrustStoreForDomain(domain);
    if (!store) { fprintf(stderr, "[-] SecTrustStoreForDomain(%d) returned NULL\n", domain); return 1; }
    CFArrayRef allRef = NULL;
    OSStatus st = SecTrustStoreCopyAll(store, &allRef);
    if (st != errSecSuccess || !allRef) {
        printf("[+] list: (empty, %d)\n", (int)st);
        return st == errSecSuccess ? 0 : 1;
    }
    NSArray *all = (__bridge_transfer NSArray *)allRef;
    printf("[+] list: %ld entries (domain %d)\n", (long)all.count, domain);
    NSUInteger idx = 0;
    for (NSArray *entry in all) {
        idx++;
        SecCertificateRef cert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)entry[0]);
        if (!cert) continue;
        CFStringRef s = SecCertificateCopySubjectSummary(cert);
        NSArray *settings = entry.count > 1 ? entry[1] : nil;
        printf("    %lu. %s%s\n", (unsigned long)idx,
               s ? [(__bridge_transfer NSString *)s UTF8String] : "(no summary)",
               settings.count == 0 ? " (full trust)" : "");
        CFRelease(cert);
    }
    return 0;
}

static void certUsage(const char *prog) {
    printf("usage: %s cert -a|--add <cert.der|pem|-> [-D|--domain N]      trust certificate as root CA\n", prog);
    printf("       %s cert -d|--remove <cert.der|pem|-> [-D|--domain N]   remove certificate from trust store\n", prog);
    printf("       %s cert -e|--evaluate <cert.der|pem|->                 evaluate system trust\n", prog);
    printf("       %s cert -l|--list [-D|--domain N]                      list certificates in trust store\n", prog);
    printf("\n");
    printf("  stdin: cat ca.der | %s cert -a -\n", prog);
}

int cert_main(int argc, char **argv, const char *prog) {
    @autoreleasepool {
        int domain = kDefaultDomain;
        NSString *certPath = nil;
        int action = 0;
        int opt;
        enum {
            OPT_ADD = 1000,
            OPT_REMOVE,
            OPT_EVALUATE,
            OPT_LIST,
            OPT_DOMAIN,
        };
        static struct option longOptions[] = {
            {"add", required_argument, NULL, OPT_ADD},
            {"remove", required_argument, NULL, OPT_REMOVE},
            {"delete", required_argument, NULL, OPT_REMOVE},
            {"evaluate", required_argument, NULL, OPT_EVALUATE},
            {"eval", required_argument, NULL, OPT_EVALUATE},
            {"list", no_argument, NULL, OPT_LIST},
            {"domain", required_argument, NULL, OPT_DOMAIN},
            {"help", no_argument, NULL, 'h'},
            {NULL, 0, NULL, 0},
        };
        optind = 1;
        while ((opt = getopt_long(argc, argv, "a:d:e:lD:h", longOptions, NULL)) != -1) {
            switch (opt) {
                case 'a':
                case OPT_ADD:
                    action = 'a';
                    certPath = @(optarg);
                    break;
                case 'd':
                case OPT_REMOVE:
                    action = 'd';
                    certPath = @(optarg);
                    break;
                case 'e':
                case OPT_EVALUATE:
                    action = 'e';
                    certPath = @(optarg);
                    break;
                case 'l':
                case OPT_LIST:
                    action = 'l';
                    break;
                case 'D':
                case OPT_DOMAIN:
                    domain = atoi(optarg);
                    break;
                case 'h':
                    certUsage(prog);
                    return 0;
                default:
                    certUsage(prog);
                    return 2;
            }
        }
        switch (action) {
            case 'a': return cert_add(certPath, domain);
            case 'd': return cert_remove(certPath, domain);
            case 'e': return cert_evaluate(certPath);
            case 'l': return cert_list(domain);
            default:  certUsage(prog); return 2;
        }
    }
}
