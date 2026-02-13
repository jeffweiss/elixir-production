# Compression

## Decision Table

| Scenario | Algorithm | Tool | Ratio | Speed |
|----------|-----------|------|-------|-------|
| HTTP response bodies | gzip/deflate | `:zlib` (built-in) | ~70% | Good |
| Large payload storage | Zstandard (Zstd) | `ezstd` | ~75% | Excellent |
| Real-time wire protocol | LZ4 | `lz4` | ~60% | Fastest |
| Archival / backups | gzip level 9 | `:zlib` | ~80% | Slow |
| Ecto term serialization | `:erlang.term_to_binary` compressed | Built-in | Varies | Good |

## :zlib (Built-In)

Erlang ships zlib — no external dependency needed.

```elixir
# Compress
compressed = :zlib.compress("large data string here")

# Decompress
original = :zlib.uncompress(compressed)

# Gzip (compatible with HTTP Content-Encoding: gzip)
gzipped = :zlib.gzip("response body")
original = :zlib.gunzip(gzipped)

# Streaming compression (for large data)
z = :zlib.open()
:zlib.deflateInit(z)
chunks = :zlib.deflate(z, data, :finish)
:zlib.deflateEnd(z)
:zlib.close(z)
```

### Plug/Phoenix — Automatic Response Compression

Phoenix compresses responses automatically when the client sends `Accept-Encoding: gzip`:

```elixir
# In endpoint.ex — already included by default
plug Plug.Parsers, ...
```

For custom compression of specific responses:

```elixir
def show(conn, %{"id" => id}) do
  data = get_large_dataset(id)

  conn
  |> put_resp_header("content-encoding", "gzip")
  |> put_resp_header("content-type", "application/json")
  |> send_resp(200, :zlib.gzip(Jason.encode!(data)))
end
```

## :erlang.term_to_binary Compression

For storing Elixir terms in the database or cache with optional compression:

```elixir
# Uncompressed
binary = :erlang.term_to_binary(%{key: "value", list: Enum.to_list(1..1000)})
byte_size(binary)  # => ~5000 bytes

# Compressed (level 1-9, 6 is default when enabled)
compressed = :erlang.term_to_binary(%{key: "value", list: Enum.to_list(1..1000)}, compressed: 6)
byte_size(compressed)  # => ~100 bytes

# Decompress — same function regardless of compression
term = :erlang.binary_to_term(compressed)
```

**Use for**: ETS storage, binary columns in Ecto, message passing of large terms.

## Zstandard (Zstd)

Better compression ratio than gzip at higher speed. Used by Facebook, Linux kernel, and many databases.

```elixir
# {:ezstd, "~> 1.0"}
compressed = :ezstd.compress("data to compress")
original = :ezstd.decompress(compressed)

# With compression level (1-22, default 3)
compressed = :ezstd.compress("data", 9)  # Higher = smaller, slower
```

| Level | Ratio | Speed | Use Case |
|-------|-------|-------|----------|
| 1 | ~60% | 500 MB/s | Real-time, low latency |
| 3 (default) | ~65% | 350 MB/s | General purpose |
| 9 | ~70% | 100 MB/s | Storage optimization |
| 19+ | ~75% | 10 MB/s | Archival |

## LZ4

Fastest compression/decompression. Lower ratio but minimal CPU cost.

```elixir
# {:lz4, "~> 0.2"}
{:ok, compressed} = :lz4.compress("high-throughput data")
{:ok, original} = :lz4.decompress(compressed, original_size)
```

**Use for**: Real-time protocols, message queues, in-memory caches where CPU matters more than space.

## Common Mistakes

- **Compressing already-compressed data**: JPEG, PNG, MP4, and encrypted data don't compress. Compressing them wastes CPU and may increase size.
- **Using gzip level 9 for real-time responses**: Level 1-3 gives 80% of the compression at 5x the speed. Level 9 is for archival.
- **Not using `:erlang.term_to_binary` compressed option**: When storing large terms in ETS or Ecto binary columns, the `compressed: 6` option often reduces size by 90%+ for structured data.
- **Compressing small payloads**: Compression has overhead. For payloads under ~150 bytes, compressed output may be larger than input.
- **Forgetting `Content-Encoding` header**: If you manually gzip a response, the client needs the header to know to decompress it.
