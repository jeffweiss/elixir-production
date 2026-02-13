# Statistical Algorithms

## Decision Table

| Need | Approach | Tool | Use When |
|------|----------|------|----------|
| Descriptive stats (mean, median, std dev) | Postgres aggregates or Elixir | `AVG`, `PERCENTILE_CONT`, or `Statistics` lib | Dashboards, reports |
| Streaming aggregates | EMA, sliding window | Custom (see `streaming-algorithms.md`) | Real-time metrics, monitoring |
| Percentiles (P50/P95/P99) | t-digest or sorted window | `tdigest` library or Postgres | Latency analysis, SLA monitoring |
| A/B test significance | Chi-squared / t-test | Postgres or `Statistics` lib | Feature flag evaluation |
| Anomaly detection | Z-score or IQR | Custom Elixir | Alerting, fraud detection |
| Correlation analysis | Pearson/Spearman | Postgres or `Explorer` | Feature analysis, data exploration |
| Data exploration / DataFrames | Explorer | `explorer` library | Ad-hoc analysis, ETL pipelines |
| Numerical computing | Nx | `nx` library | Regression, matrix ops, ML preprocessing |

## Pushing Stats to Postgres

For most production statistics, Postgres is the right place to compute them — it's faster, avoids loading data into Elixir, and handles NULLs and edge cases correctly.

### Descriptive Statistics

```elixir
# Mean, count, sum — basic aggregates
from(o in Order,
  where: o.inserted_at > ago(30, "day"),
  select: %{
    count: count(o.id),
    total: sum(o.amount_cents),
    average: avg(o.amount_cents),
    min: min(o.amount_cents),
    max: max(o.amount_cents)
  }
) |> Repo.one()

# Standard deviation
from(o in Order,
  select: fragment("stddev(?)", o.amount_cents)
) |> Repo.one()

# Percentiles (P50, P95, P99)
from(o in Order,
  select: %{
    p50: fragment("percentile_cont(0.5) WITHIN GROUP (ORDER BY ?)", o.amount_cents),
    p95: fragment("percentile_cont(0.95) WITHIN GROUP (ORDER BY ?)", o.amount_cents),
    p99: fragment("percentile_cont(0.99) WITHIN GROUP (ORDER BY ?)", o.amount_cents)
  }
) |> Repo.one()
```

### Histograms and Distributions

```elixir
# Histogram: count orders by price bucket
from(o in Order,
  select: %{
    bucket: fragment("width_bucket(?, 0, 10000, 20)", o.amount_cents),
    count: count(o.id)
  },
  group_by: fragment("width_bucket(?, 0, 10000, 20)", o.amount_cents),
  order_by: fragment("width_bucket(?, 0, 10000, 20)", o.amount_cents)
) |> Repo.all()

# Time-series aggregation (orders per hour)
from(o in Order,
  select: %{
    hour: fragment("date_trunc('hour', ?)", o.inserted_at),
    count: count(o.id),
    total: sum(o.amount_cents)
  },
  where: o.inserted_at > ago(24, "hour"),
  group_by: fragment("date_trunc('hour', ?)", o.inserted_at),
  order_by: fragment("date_trunc('hour', ?)", o.inserted_at)
) |> Repo.all()
```

### Correlation

```elixir
# Pearson correlation between two columns
from(p in Product,
  select: fragment("corr(?, ?)", p.price, p.rating)
) |> Repo.one()
```

## Computing Stats in Elixir

When you need stats on data that's already in memory or doesn't come from a database:

### Descriptive Statistics (Pure Elixir)

```elixir
defmodule MyApp.Stats do
  def mean([]), do: 0
  def mean(values) do
    Enum.sum(values) / length(values)
  end

  def median(values) do
    sorted = Enum.sort(values)
    len = length(sorted)
    mid = div(len, 2)

    if rem(len, 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end

  def variance(values) do
    m = mean(values)
    values
    |> Enum.map(fn x -> (x - m) ** 2 end)
    |> mean()
  end

  def std_dev(values) do
    :math.sqrt(variance(values))
  end

  def percentile(values, p) when p >= 0 and p <= 1 do
    sorted = Enum.sort(values)
    index = round(p * (length(sorted) - 1))
    Enum.at(sorted, index)
  end
end
```

### Anomaly Detection

#### Z-Score (How Many Standard Deviations from Mean)

```elixir
defmodule MyApp.AnomalyDetector do
  @threshold 3.0  # Values > 3 std devs from mean are anomalies

  def detect(values) do
    m = MyApp.Stats.mean(values)
    sd = MyApp.Stats.std_dev(values)

    if sd == 0 do
      []  # No variance, no anomalies
    else
      values
      |> Enum.with_index()
      |> Enum.filter(fn {value, _} ->
        z_score = abs(value - m) / sd
        z_score > @threshold
      end)
    end
  end
end

# Example: detect unusual response times
response_times = [42, 38, 45, 41, 39, 850, 43, 40]
MyApp.AnomalyDetector.detect(response_times)
# => [{850, 5}] — index 5 is an anomaly
```

#### IQR (Interquartile Range) — Robust to Outliers

```elixir
def detect_iqr(values, factor \\ 1.5) do
  sorted = Enum.sort(values)
  q1 = percentile(sorted, 0.25)
  q3 = percentile(sorted, 0.75)
  iqr = q3 - q1

  lower = q1 - factor * iqr
  upper = q3 + factor * iqr

  Enum.filter(values, fn v -> v < lower or v > upper end)
end
```

### A/B Test Significance

Simple chi-squared test for comparing conversion rates:

```elixir
defmodule MyApp.ABTest do
  @doc """
  Tests whether two conversion rates are significantly different.
  Returns {:significant, p_value} or {:not_significant, p_value}.
  """
  def chi_squared_test(control_conversions, control_total, variant_conversions, variant_total) do
    # Observed values
    observed = [
      control_conversions, control_total - control_conversions,
      variant_conversions, variant_total - variant_conversions
    ]

    # Expected values under null hypothesis (same conversion rate)
    total = control_total + variant_total
    total_conversions = control_conversions + variant_conversions
    expected_rate = total_conversions / total

    expected = [
      expected_rate * control_total, (1 - expected_rate) * control_total,
      expected_rate * variant_total, (1 - expected_rate) * variant_total
    ]

    # Chi-squared statistic
    chi2 =
      Enum.zip(observed, expected)
      |> Enum.map(fn {o, e} -> (o - e) ** 2 / e end)
      |> Enum.sum()

    # For 1 degree of freedom: chi2 > 3.841 → p < 0.05
    if chi2 > 3.841 do
      {:significant, chi2}
    else
      {:not_significant, chi2}
    end
  end
end

# Example: is the new checkout better?
MyApp.ABTest.chi_squared_test(
  120, 1000,   # Control: 120 conversions out of 1000
  145, 1000    # Variant: 145 conversions out of 1000
)
# => {:significant, 4.23}
```

## Explorer for Data Analysis

Explorer provides DataFrames for Elixir — similar to Python's pandas:

```elixir
# {:explorer, "~> 0.9"}
alias Explorer.DataFrame, as: DF
alias Explorer.Series

# Load and analyze
df = DF.from_csv!("sales.csv")

df
|> DF.group_by("region")
|> DF.summarise(
  total_revenue: sum(col("revenue")),
  avg_order: mean(col("order_value")),
  order_count: count(col("id")),
  p95_value: quantile(col("order_value"), 0.95)
)
|> DF.sort_by(desc: col("total_revenue"))
```

**Use Explorer when**: Ad-hoc data analysis, ETL pipelines, CSV/Parquet processing, data exploration in Livebook. For production queries, prefer Postgres.

## Common Mistakes

- **Computing stats in Elixir when Postgres can do it**: Loading 1M rows into Elixir to compute an average is wasteful. Use `AVG`, `PERCENTILE_CONT`, `STDDEV` in SQL.
- **Using mean for skewed data**: Response time distributions are typically skewed right. Median and percentiles (P95, P99) are more meaningful than mean for latency data.
- **A/B testing without sufficient sample size**: Statistical significance requires adequate samples. 50 visitors per variant is not enough — you need thousands for small effect sizes.
- **Z-score anomaly detection on non-normal data**: Z-scores assume normal distribution. For skewed data (response times, revenue), use IQR or percentile-based detection.
- **Not accounting for multiple comparisons**: Testing 20 metrics simultaneously means one will appear significant by chance at p < 0.05. Apply Bonferroni correction or use a lower threshold.
- **Confusing correlation with causation**: `corr(price, rating) = 0.7` means they move together, not that one causes the other. Be explicit in how you present correlations.

**See also**: `streaming-algorithms.md` for real-time metrics (sliding windows, EMA, streaming percentiles).
