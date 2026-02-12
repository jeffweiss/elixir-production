# Database Practices

## Safe Ecto Migrations

Database migrations that acquire locks on large tables cause downtime during rolling deploys. Every migration must be evaluated for lock safety (Bernheisel, "Safe Ecto Migrations"):

| Operation | Danger | Safe Alternative |
|-----------|--------|-----------------|
| Add index | ShareLock blocks writes | `create index(..., concurrently: true)` with `@disable_ddl_transaction true` and `@disable_migration_lock true` |
| Add column with default | Table rewrite (pre-PG11) | Add column nullable first, add default in separate migration |
| Add foreign key | Validates entire table under lock | Add with `validate: false`, validate in separate migration |
| Change column type | Blocks reads and writes | Create new column → write to both → backfill → migrate reads → drop old |
| Remove column | Breaks running instances | Remove from Ecto schema first deploy, drop column in next migration |
| Add NOT NULL | Full table scan under lock | Add check constraint unvalidated → backfill → validate → apply NOT NULL |

**Core principle**: Separate dangerous operations into distinct migrations. Each migration should be safe to run while the application is serving traffic.

## Isolation Level Warnings

**Database isolation levels lie** (Kleppmann, "Hermitage: Testing the 'I' in ACID"): Systematic testing reveals that databases implement isolation levels differently despite the same SQL standard names. Oracle's "serializable" actually provides snapshot isolation (not true serializability). "Repeatable read" has different semantics in PostgreSQL, MySQL, and SQL Server. Don't trust vendor documentation — test actual concurrent behavior with your specific database. For Ecto applications using PostgreSQL, the default `:read_committed` is well-defined and consistent, but if you rely on stronger isolation (`:repeatable_read` or `:serializable`), verify the actual guarantees with concurrent tests, especially if you ever migrate databases.

## Dependency SLAs

If your service depends on another service, that dependency must meet the same SLA as your service — or you need a degraded-mode path that doesn't require it (Hamilton, "On Designing and Deploying Internet-Scale Services"). A 99.99% service that hard-depends on a 99.9% service is a 99.9% service. Audit all external dependencies and design fallbacks for each.

## Performance Guidelines

```elixir
# ✅ Preload associations to avoid N+1
products = Repo.all(from p in Product, preload: [:category, :vendor])

# ❌ N+1 query problem
products = Repo.all(Product)  # 1 query
Enum.map(products, & &1.category)  # N more queries

# ✅ Use indexes for frequent queries
create index(:products, [:user_id])
create index(:products, [:category_id, :status])

# ✅ Select only needed fields
from(u in User, select: [:id, :name, :email])
```

## Caching

```elixir
# ETS for process-local cache
:ets.new(:cache, [:named_table, :public, read_concurrency: true])

# Cachex for more features
{:ok, _} = Cachex.start_link(:my_cache)
Cachex.get(:my_cache, key)
Cachex.put(:my_cache, key, value, ttl: :timer.hours(1))
```
