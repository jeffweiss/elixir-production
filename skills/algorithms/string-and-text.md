# String and Text Algorithms

## Decision Table

| Problem | Approach | Library/Tool | Use When |
|---------|----------|-------------|----------|
| Exact substring search | `String.contains?/2` | Built-in | Simple checks |
| Fuzzy matching | Levenshtein / Jaro-Winkler | `simetric`, `the_fuzz` | Typo tolerance, "did you mean?" |
| Autocomplete / prefix search | Trie | `trie` library or Map-based | Prefix completion, command palettes |
| Multi-pattern search | Aho-Corasick | `aho_corasaki` | Content filtering, keyword detection |
| Full-text search | PostgreSQL tsvector / pg_trgm | Ecto + Postgres | Search features with ranking |
| Regex matching | `Regex` / `~r//` | Built-in | Pattern extraction, validation |

## Fuzzy Matching

### Levenshtein Distance

Minimum edits (insert, delete, substitute) to transform one string into another. Good for typo detection.

```elixir
# {:simetric, "~> 0.2"}
Simetric.Levenshtein.compare("kitten", "sitting")  # => 3

# Use for "did you mean?" suggestions
def suggest(input, candidates, max_distance \\ 2) do
  candidates
  |> Enum.map(fn c -> {c, Simetric.Levenshtein.compare(input, c)} end)
  |> Enum.filter(fn {_, d} -> d <= max_distance end)
  |> Enum.sort_by(fn {_, d} -> d end)
  |> Enum.map(fn {c, _} -> c end)
end

suggest("pheonix", ["phoenix", "elixir", "ecto"])
# => ["phoenix"]
```

### Jaro-Winkler Similarity

Returns 0.0–1.0 similarity score. Better for short strings (names, identifiers) where early characters matter more.

```elixir
Simetric.Jaro.compare("martha", "marhta")     # => 0.944
Simetric.JaroWinkler.compare("martha", "marhta")  # => 0.961 (prefix bonus)

# Use for name matching, deduplication
def similar?(a, b, threshold \\ 0.85) do
  Simetric.JaroWinkler.compare(
    String.downcase(a),
    String.downcase(b)
  ) >= threshold
end
```

### Choosing a Distance Metric

| Metric | Best For | Weakness |
|--------|---------|----------|
| Levenshtein | Typo detection, spell checking | Slow for long strings O(n×m) |
| Jaro-Winkler | Short string matching (names) | Less meaningful for long strings |
| Hamming | Fixed-length strings (hashes) | Only works on equal-length strings |
| Trigram (pg_trgm) | Database-level fuzzy search | Requires Postgres extension |

## Full-Text Search with PostgreSQL

For search features, use Postgres's built-in text search rather than implementing in Elixir:

```elixir
# Migration: add tsvector column and GIN index
alter table(:articles) do
  add :search_vector, :tsvector
end

create index(:articles, [:search_vector], using: :gin)

execute """
CREATE TRIGGER articles_search_update
BEFORE INSERT OR UPDATE ON articles
FOR EACH ROW EXECUTE FUNCTION
tsvector_update_trigger(search_vector, 'pg_catalog.english', title, body);
"""
```

```elixir
# Query with ranking
def search(query) do
  from(a in Article,
    where: fragment("? @@ websearch_to_tsquery('english', ?)", a.search_vector, ^query),
    order_by: fragment("ts_rank(?, websearch_to_tsquery('english', ?)) DESC", a.search_vector, ^query)
  )
  |> Repo.all()
end
```

### Trigram Matching (pg_trgm)

For fuzzy search without exact word boundaries:

```elixir
# Requires: CREATE EXTENSION pg_trgm;
# Migration: CREATE INDEX articles_title_trgm ON articles USING GIN (title gin_trgm_ops);

def fuzzy_search(query) do
  from(a in Article,
    where: fragment("? % ?", a.title, ^query),
    order_by: fragment("similarity(?, ?) DESC", a.title, ^query)
  )
  |> Repo.all()
end
```

## Common Mistakes

- **Implementing search in Elixir when Postgres handles it**: `tsvector`, `pg_trgm`, and `websearch_to_tsquery` are battle-tested and index-backed. Don't load all records and filter in Elixir.
- **Using Levenshtein for long texts**: O(n×m) complexity. For documents, use Postgres full-text search or trigram matching.
- **Case-sensitive matching**: Always normalize with `String.downcase/1` before comparing.
- **Not indexing search columns**: Fuzzy search without a GIN index does a full table scan.
