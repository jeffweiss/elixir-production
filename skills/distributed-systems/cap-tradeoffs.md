# CAP Tradeoffs and Consistency Models

## Fundamental Limits

Before choosing any distributed approach, understand what's theoretically impossible:

- **FLP impossibility**: Consensus cannot be guaranteed in a purely asynchronous system if even one node can fail. Every consensus protocol (Raft, Paxos) works around this with timeouts and leader election — they use partial synchrony assumptions. This is why leader election can stall and why there's no "perfect" consensus.
- **Failure detection is impossible in async systems**: You cannot distinguish a crashed node from a slow one. Practical systems use timeout heuristics — shorter timeouts mean faster detection but more false positives; longer timeouts mean fewer false positives but slower detection. Every `:net_kernel` heartbeat interval is a bet on this tradeoff.
- **End-to-end acknowledgment is required**: A message sent is not a message received. A message received is not a message read. A message read is not a message acted on. Never trust network-layer delivery guarantees — require explicit application-level confirmation that the operation was received, processed, and persisted.

```elixir
# ❌ Fire and forget — assumes delivery
GenServer.cast({:worker, remote_node}, {:process, item})

# ✅ End-to-end acknowledgment — confirms processing
case GenServer.call({:worker, remote_node}, {:process, item}, 5_000) do
  {:ok, result} -> {:ok, result}
  {:error, reason} -> handle_failure(item, reason)
end
```

## CAP Theorem Tradeoffs

**Consistency + Availability + Partition Tolerance** - Pick 2:

**CA (Consistency + Availability, no Partition Tolerance)**:
- Traditional RDBMS in single datacenter
- Example: PostgreSQL without replication
- Limitation: Network partition breaks system
- Use case: Single-datacenter applications

**CP (Consistency + Partition Tolerance)**:
- Prioritize correctness over availability
- Examples: Raft consensus (ra, raft libraries), etcd, ZooKeeper
- During partition: Minority partition becomes unavailable
- Use case: Financial systems, inventory management, leader election

**AP (Availability + Partition Tolerance)**:
- Prioritize availability over strong consistency
- Examples: CRDTs (lasp, delta_crdt), Cassandra, DynamoDB
- During partition: All nodes serve requests, reconcile later
- Use case: Social media, content delivery, collaborative editing

**Stop calling databases CP or AP** (Kleppmann, "Please stop calling databases CP or AP"): The CAP theorem is too simplistic for real systems. CAP "consistency" means specifically *linearizability* (not ACID consistency); CAP "availability" means *every* non-failing node responds (not "high uptime"). Many real systems are neither CP nor AP — a single-leader database with async replication fits neither category. Different operations within one system may have different consistency characteristics. Worse, vendors use these terms inconsistently: Oracle's "serializable" is actually snapshot isolation; "repeatable read" means different things across PostgreSQL, MySQL, and SQL Server. Don't trust labels — verify specific guarantees. Ask: What happens during a partition? What ordering is guaranteed? What does "consistent" actually mean *precisely*? Read the Jepsen analysis if one exists.

**Elixir-specific considerations**:
```elixir
# CP approach: Raft consensus via :ra
{:ok, _cluster} = :ra.start_cluster(
  :my_cluster,
  {:module, MyStateMachine, %{}},
  [node() | Node.list()]
)

# AP approach: CRDTs via delta_crdt
{:ok, crdt_pid} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap)
```

## When to Use Which Approach

### Use Raft (CP) when:
- Financial transactions
- Inventory management
- Configuration management
- Leader election
- Strong consistency required
- Can tolerate reduced availability during partitions

### Use CRDTs (AP) when:
- Social features (likes, follows)
- Collaborative editing
- Shopping carts
- Presence/status
- Offline-first apps
- Availability more important than consistency

### Use Distributed Erlang when:
- Small to medium cluster (<50 nodes)
- Trusted network
- Simple clustering needs
- Process distribution
- Transparent remote messaging

### Use Partisan when:
- Large clusters (>50 nodes)
- Need custom topology
- Multi-datacenter deployment
- Gossip protocols
- Peer-to-peer systems
