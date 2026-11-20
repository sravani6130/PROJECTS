#include "md5.h"

#include <openssl/evp.h>
#include <stdio.h>

int md5_file(const char *path, char hex[33])
{
    FILE *f = fopen(path, "rb");
    if (f == NULL)
        return -1;

    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    if (ctx == NULL || EVP_DigestInit_ex(ctx, EVP_md5(), NULL) != 1) {
        EVP_MD_CTX_free(ctx);
        fclose(f);
        return -1;
    }

    unsigned char buf[8192];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), f)) > 0)
        EVP_DigestUpdate(ctx, buf, n);
    fclose(f);

    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int digest_len = 0;
    EVP_DigestFinal_ex(ctx, digest, &digest_len);
    EVP_MD_CTX_free(ctx);

    for (unsigned int i = 0; i < digest_len && i < 16; i++)
        snprintf(hex + 2 * i, 3, "%02x", digest[i]);
    hex[32] = '\0';
    return 0;
}
