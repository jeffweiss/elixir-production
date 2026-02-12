# Hash Function Selection

Modern hash functions significantly outperform classic algorithms for non-cryptographic use cases.

## xxHash3 (2020) — Non-Cryptographic

Extremely fast, optimized for modern CPUs with SIMD instructions.

- **Speed**: 31.5 GB/s (vs 0.5 GB/s for MD5)
- **Quality**: Excellent hash distribution, low collision rates

```elixir
# {:exhash, "~> 0.2"}
:exhash.xxh3_64("data")   # 64-bit hash
:exhash.xxh3_128("data")  # 128-bit hash
```

**Use cases**: Hash tables, data deduplication, checksums, Bloom/Cuckoo filters.

**Paper**: Collet, 2020

## BLAKE3 (2020) — Cryptographic

Cryptographic hash that's significantly faster than SHA-2/SHA-3 while maintaining security.

- **Speed**: 2.5 GB/s (vs 0.4 GB/s for SHA-256)
- **Properties**: Parallelizable, SIMD-optimized, cryptographically secure

```elixir
# {:b3, "~> 0.2"}
B3.hash("data to hash")
```

**Use cases**: Content-addressed storage, file integrity, digital signatures.

**Paper**: O'Connor et al., 2020

## HighwayHash (2017)

SIMD-optimized keyed hash with strong security properties (Google).

- **Speed**: 10 GB/s
- **Properties**: Keyed hash for authentication, uses AES-NI/AVX2

**Use cases**: Message authentication codes (MAC), fingerprinting.

**Note**: Limited Elixir library support; prefer xxHash3 for most non-crypto cases.

**Paper**: Pike & Alakuijala, 2017

## Selection Decision

```
Need cryptographic security?
  YES → BLAKE3 (2.5 GB/s, secure)
  NO  → Need keyed authentication?
          YES → HMAC-SHA256 or HighwayHash
          NO  → xxHash3 (31.5 GB/s)
```

## Quick Reference

```elixir
# Non-cryptographic (hash tables, checksums, deduplication)
:exhash.xxh3_64("data")

# Cryptographic (integrity, signatures)
B3.hash("sensitive data")

# Message authentication
:crypto.mac(:hmac, :sha256, key, message)
```

## Common Mistake

```elixir
# ❌ SLOW — cryptographic hash for non-security use
:crypto.hash(:md5, data)  # ~0.5 GB/s

# ✅ FAST — modern non-crypto hash (60× faster)
:exhash.xxh3_64(data)  # ~31 GB/s
```
