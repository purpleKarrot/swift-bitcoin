#ifndef ecdsa_h
#define ecdsa_h

#include <secp256k1.h>

const secp256k1_context* get_static_context();

int secp256k1_ec_pubkey_combine2(const secp256k1_context* ctx, secp256k1_pubkey* out,
                                 const secp256k1_pubkey* in1, const secp256k1_pubkey* in2);

int ecdsa_signature_parse_der_lax(secp256k1_ecdsa_signature* sig, const unsigned char *input, size_t inputlen);

#endif /* ecdsa_h */
