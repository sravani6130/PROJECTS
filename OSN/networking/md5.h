#ifndef MD5_H
#define MD5_H

/*
 * Computes the MD5 checksum of a file using OpenSSL.
 * Writes 32 lowercase hex characters plus '\0' into `hex`.
 * Returns 0 on success, -1 if the file can't be read.
 */
int md5_file(const char *path, char hex[33]);

#endif /* MD5_H */
