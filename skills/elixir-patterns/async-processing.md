# Async Processing: GenServer vs Oban vs Broadway

## Decision Framework

Choose based on **durability needs** and **data source**:

```
Where does the work come from?
  Internal event (user action, DB change)
    → Must survive crashes/deploys?
        NO  → GenServer / Task (ephemeral, fast)
        YES → Oban (DB-backed, transactional, retries)
  External stream (SQS, Kafka, RabbitMQ, PubSub)
    → Broadway (back-pressure, batching, acknowledgements)
```

| Need | GenServer/Task | Oban | Broadway |
|------|---------------|------|----------|
| Durability across restarts | No | Yes (DB-backed) | Depends on source |
| Transactional with DB writes | No | Yes (`Oban.insert` in `Ecto.Multi`) | No |
| Back-pressure from external source | No | No | Yes (GenStage) |
| Batching (SQS, S3, API calls) | Manual | Via Oban Pro | Built-in |
| Retry with backoff | Manual | Built-in (configurable) | Producer-dependent |
| Unique/deduplicated jobs | No | Built-in | No |
| Scheduled/cron jobs | Manual (`Process.send_after`) | Built-in | No |
| Observability | Manual | Telemetry + historic job data | Telemetry |
| Ordering guarantees | Per-process | Per-queue (FIFO) | Partition-based |
| Concurrency control | Manual | Per-queue limits | Processor/batcher concurrency |

**Rule of thumb**: If the work originates from your database or user actions, use Oban. If it originates from an external message broker, use Broadway. If it's ephemeral and losing it on crash is acceptable, use a GenServer or Task.

## Oban Patterns

### Transactional Job Insertion

Enqueue jobs atomically with other DB changes — if the transaction rolls back, the job is never enqueued:

```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(:user, User.changeset(%User{}, attrs))
|> Oban.insert(:welcome_email, fn %{user: user} ->
  WelcomeEmailWorker.new(%{user_id: user.id})
end)
|> Repo.transaction()
```

### Worker Design

```elixir
defmodule MyApp.Workers.ImportWorker do
  use Oban.Worker,
    queue: :imports,
    max_attempts: 5,
    unique: [period: 300, fields: [:args, :queue]]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"file_id" => file_id}}) do
    case MyApp.Imports.process_file(file_id) do
      {:ok, _result} -> :ok
      {:error, :rate_limited} -> {:snooze, 60}
      {:error, reason} -> {:error, reason}  # triggers retry
    end
  end
end
```

### Return Values

| Return | Effect |
|--------|--------|
| `:ok` | Job marked `completed` |
| `{:ok, result}` | Job marked `completed`, result recorded (Pro) |
| `{:error, reason}` | Job retried with backoff, or `discarded` if max attempts reached |
| `{:snooze, seconds}` | Job rescheduled, attempt count unchanged |
| `{:cancel, reason}` | Job marked `cancelled`, no retry |

### Queue Design at Scale

- **Isolate by latency**: Separate fast jobs (notifications) from slow jobs (imports) into different queues
- **Isolate by criticality**: Payment processing and email sending should never compete for the same workers
- **Limit concurrency per queue**: `queues: [payments: 5, imports: 2, notifications: 20]`
- **Monitor Postgres health**: At high volume (>1M jobs/day), watch for index bloat on the `oban_jobs` table. Configure `Oban.Plugins.Pruner` to clean completed jobs

### Unique Jobs

Prevent duplicate work:

```elixir
use Oban.Worker,
  unique: [
    period: :infinity,          # or specific seconds
    states: [:available, :scheduled, :executing, :retryable],
    fields: [:worker, :args],   # what constitutes "same job"
    keys: [:user_id]            # match on specific arg keys
  ]
```

### Testing

```elixir
# In config/test.exs
config :my_app, Oban, testing: :manual

# In tests
use Oban.Testing, repo: MyApp.Repo

test "enqueues welcome email on registration" do
  {:ok, user} = Accounts.register_user(%{email: "test@example.com"})
  assert_enqueued worker: WelcomeEmailWorker, args: %{user_id: user.id}
end

test "processes import successfully" do
  {:ok, job} = perform_job(ImportWorker, %{file_id: 123})
  assert job == :ok
end
```

## Broadway Patterns

### When to Use Broadway

Broadway is for **consuming external data sources** with back-pressure. Use it when:
- Data arrives from SQS, Kafka, RabbitMQ, Google PubSub, or similar
- You need automatic acknowledgements (messages are acked after processing)
- You need batching for efficiency (e.g., batch writes to S3)
- You need to control throughput via back-pressure rather than polling

### Pipeline Architecture

```elixir
defmodule MyApp.ImportPipeline do
  use Broadway

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwaySQS.Producer, queue_url: "https://sqs..."},
        concurrency: 2
      ],
      processors: [
        default: [concurrency: 10]
      ],
      batchers: [
        s3: [concurrency: 2, batch_size: 100, batch_timeout: 5_000]
      ]
    )
  end

  @impl true
  def handle_message(_processor, message, _context) do
    processed = process(message.data)

    message
    |> Broadway.Message.update_data(fn _ -> processed end)
    |> Broadway.Message.put_batcher(:s3)
  end

  @impl true
  def handle_batch(:s3, messages, _batch_info, _context) do
    data = Enum.map(messages, & &1.data)
    S3.put_batch(data)
    messages
  end
end
```

### Key Concepts

- **Producers** fetch data from external sources. Set `concurrency: 1` unless the source is slow (network-bound).
- **Processors** handle individual messages. Set concurrency based on CPU availability.
- **Batchers** group messages by size/time before batch processing. Use for bulk writes.
- **Partitioning** guarantees ordering — `partition_by: &(&1.data.user_id)` ensures same-user messages are processed sequentially.
- **Rate limiting** controls throughput at the producer level: `rate_limiting: [allowed_messages: 100, interval: 1_000]`

### Testing Broadway

```elixir
# In config/test.exs — swap producer for DummyProducer
config :my_app, producer_module: Broadway.DummyProducer

# In tests
test "processes message successfully" do
  ref = Broadway.test_message(MyApp.ImportPipeline, %{id: 1, data: "test"})
  assert_receive {:ack, ^ref, [%{data: _processed}], []}
end

test "handles batch" do
  ref = Broadway.test_batch(MyApp.ImportPipeline, [%{id: 1}, %{id: 2}])
  assert_receive {:ack, ^ref, [_, _], []}, 5_000
end
```

## Common Mistakes

- **Using Oban for external stream processing**: Oban polls a database. For SQS/Kafka/RabbitMQ, Broadway's push-based back-pressure is far more efficient.
- **Using Broadway for internal job scheduling**: Broadway has no persistence, no cron, no unique jobs. Use Oban for work that originates from your application.
- **Using GenServer for durable work**: A GenServer loses its state on crash. If the work matters, use Oban so it survives restarts and deploys.
- **Not isolating Oban queues**: Running everything in `:default` means a slow import blocks fast notifications. Always separate by latency and criticality.
- **Ignoring Postgres health with Oban**: At high volume, the `oban_jobs` table grows fast. Configure pruning, monitor index bloat, and consider splitting to multiple Oban instances if a single jobs table becomes a bottleneck.
- **Over-concurrency in Broadway**: More processor concurrency isn't always better. Measure actual throughput — excess concurrency creates internal queueing.

**See also**: `production-quality/deployment.md` for Oban shutdown configuration, `production-quality/observability.md` for Oban/Broadway telemetry events.
