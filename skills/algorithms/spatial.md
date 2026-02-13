# Spatial Algorithms

## Decision Table

| Problem | Approach | Tool | Use When |
|---------|----------|------|----------|
| Point-in-radius queries | PostGIS `ST_DWithin` | Ecto + PostGIS | Location-based search, "nearby X" |
| Nearest neighbors | PostGIS `ST_Distance` + index | Ecto + PostGIS | "Find closest", delivery routing |
| Geofencing | PostGIS `ST_Contains` | Ecto + PostGIS | "Is user in zone?", regional rules |
| Lightweight lat/lng grouping | Geohash | `geohash` library | Proximity bucketing without PostGIS |
| Client-side distance calc | Haversine formula | Pure Elixir | Approximate distance between coordinates |

## PostGIS with Ecto

The standard approach for production spatial queries. PostGIS adds geographic types and spatial indexes to PostgreSQL.

### Setup

```elixir
# mix.exs
{:geo_postgis, "~> 3.4"}

# Migration
execute "CREATE EXTENSION IF NOT EXISTS postgis"

create table(:locations) do
  add :name, :string
  add :coordinates, :geometry  # or :geography for spherical math
  timestamps()
end

# Spatial index — critical for query performance
create index(:locations, [:coordinates], using: :gist)
```

### Schema

```elixir
defmodule MyApp.Location do
  use Ecto.Schema

  schema "locations" do
    field :name, :string
    field :coordinates, Geo.PostGIS.Geometry
    timestamps()
  end
end
```

### Common Queries

```elixir
# Find locations within 5km of a point
def nearby(lat, lng, radius_meters \\ 5000) do
  point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}

  from(l in Location,
    where: fragment(
      "ST_DWithin(?::geography, ?::geography, ?)",
      l.coordinates, ^point, ^radius_meters
    ),
    order_by: fragment(
      "ST_Distance(?::geography, ?::geography)",
      l.coordinates, ^point
    )
  )
  |> Repo.all()
end

# Check if point is inside a polygon (geofencing)
def in_zone?(lat, lng, zone_id) do
  point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}

  from(z in Zone,
    where: z.id == ^zone_id,
    where: fragment("ST_Contains(?, ?)", z.boundary, ^point),
    select: true
  )
  |> Repo.exists?()
end
```

## Geohashing

Encodes lat/lng into a string where shared prefixes indicate proximity. Useful for bucketing without PostGIS.

```elixir
# {:geohash, "~> 1.0"}
Geohash.encode(48.8566, 2.3522, 6)  # => "u09tvw" (Paris, ~1.2km precision)

# Precision vs area
# 1 char: ~5000km  |  4 chars: ~40km  |  6 chars: ~1.2km
# 7 chars: ~150m   |  8 chars: ~40m   |  9 chars: ~5m

# Find neighbors for search expansion
Geohash.neighbors("u09tvw")
# => %{n: "u09tyq", ne: "u09tyr", e: "u09tvx", ...}
```

### Database Pattern: Geohash Column for Fast Lookups

```elixir
# Store geohash alongside coordinates for prefix-based queries
alter table(:locations) do
  add :geohash, :string
end

create index(:locations, [:geohash])

# Query: find all locations in same ~1km area
def in_area(lat, lng) do
  hash = Geohash.encode(lat, lng, 6)
  from(l in Location, where: like(l.geohash, ^"#{hash}%"))
  |> Repo.all()
end
```

## Haversine Distance (Pure Elixir)

For simple distance calculations without PostGIS:

```elixir
defmodule MyApp.Geo do
  @earth_radius_km 6371.0

  def distance_km({lat1, lng1}, {lat2, lng2}) do
    dlat = deg_to_rad(lat2 - lat1)
    dlng = deg_to_rad(lng2 - lng1)

    a = :math.sin(dlat / 2) ** 2 +
        :math.cos(deg_to_rad(lat1)) *
        :math.cos(deg_to_rad(lat2)) *
        :math.sin(dlng / 2) ** 2

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    @earth_radius_km * c
  end

  defp deg_to_rad(deg), do: deg * :math.pi() / 180
end
```

## Common Mistakes

- **Calculating distance in Elixir when Postgres can do it**: PostGIS `ST_Distance` with a GiST index is orders of magnitude faster than loading all rows and computing Haversine in Elixir.
- **Using `:geometry` type when you need spherical math**: `:geometry` uses planar math (Cartesian). For lat/lng on Earth, cast to `::geography` or use `:geography` column type.
- **Forgetting the GiST index**: Without `CREATE INDEX ... USING GiST`, spatial queries do a full table scan.
- **Longitude/latitude order**: PostGIS and GeoJSON use `{longitude, latitude}` (x, y). Most human-facing APIs use `{latitude, longitude}`. Mix-ups cause bugs that are hard to spot.
- **Over-precision in geohash**: A 9-character geohash (~5m) is excessive for "nearby restaurants." Use 5-6 characters (~5-1km) for most proximity features.
