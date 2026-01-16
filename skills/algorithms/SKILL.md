---
name: algorithms
description: Use when researching algorithms, data structures, optimization, performance, or need modern alternatives to classic algorithms
---

# Modern Algorithms and Data Structures

## Overview

This skill provides guidance on modern algorithms and data structures from recent computer science research, with focus on practical Elixir implementations.

## When to Use

Use this skill when:
- Researching algorithmic approaches for a problem
- Need modern alternatives to classic algorithms
- Optimizing performance-critical code
- Evaluating data structure choices
- Assessing implementation complexity vs performance gains

## Core Concepts

### Modern Hash Functions

- **xxHash3**: Fast non-cryptographic hash
- **BLAKE3**: Cryptographic hash with excellent performance
- **HighwayHash**: SIMD-optimized hashing

### Probabilistic Data Structures

- **HyperLogLog**: Cardinality estimation
- **Cuckoo Filters**: Space-efficient membership testing
- **Count-Min Sketch**: Frequency estimation

### Cache-Efficient Algorithms

Focus on cache-oblivious algorithms that automatically adapt to cache hierarchy.

## Quick Reference

| Use Case | Modern Algorithm | Classic Alternative |
|----------|------------------|---------------------|
| Hashing | xxHash3, BLAKE3 | MD5, SHA1 |
| Cardinality | HyperLogLog | Exact count |
| Membership | Cuckoo Filter | Bloom filter |
| Sorting | BlockQuicksort | Quicksort |

## When to Research

Consider researching recent papers when:
- Existing solutions aren't performant enough
- Novel problem without established solutions
- Need cutting-edge optimization

Use the `algorithms-researcher` agent for deep research with paper citations.

[Content will be expanded with full details - this stub enables plugin loading]
