#!/bin/bash
# Start RabbitMQ, then (once) join the seed node. Idempotent across restarts via
# a marker in the persistent data dir. All nodes must share the same Erlang
# cookie (RABBITMQ_ERLANG_COOKIE).
set -euo pipefail

SEED_NODENAME="${RABBITMQ_SEED_NODENAME:-rabbit@rabbitmq-1}"
MARKER="/var/lib/rabbitmq/.eventplatform_cluster_done"
LOG_DIR="/var/lib/rabbitmq"
MARKER_LOG="${LOG_DIR}/cluster-join.log"
mkdir -p "$LOG_DIR"

if ! command -v rabbitmq-server >/dev/null 2>&1; then
  echo "rabbitmq-server not in PATH" >&2
  exit 1
fi

# Prometheus plugin; align with the single-broker stack.
rabbitmq-plugins enable --offline rabbitmq_prometheus 2>/dev/null || \
  rabbitmq-plugins enable rabbitmq_prometheus 2>&1

echo "Starting broker (background)…" | tee -a "$MARKER_LOG"
rabbitmq-server &

echo "Waiting for local node…" | tee -a "$MARKER_LOG"
until rabbitmq-diagnostics -q check_running; do
  sleep 1
done

if [[ -f "$MARKER" ]]; then
  echo "Marker $MARKER present — already in cluster, skipping join_cluster." | tee -a "$MARKER_LOG"
  wait
  exit 0
fi

# Seed must be reachable; AMQP 5672 is a simple readiness signal.
echo "Waiting for AMQP on seed rabbitmq-1:5672…" | tee -a "$MARKER_LOG"
wait_for_seed() {
  local n
  for n in $(seq 1 90); do
    ( true 2>/dev/null </dev/tcp/rabbitmq-1/5672 ) && return 0
    sleep 1
  done
  return 1
}
if ! wait_for_seed; then
  echo "Seed broker not reachable in time" | tee -a "$MARKER_LOG" >&2
  exit 1
fi

# Extra settle time: seed must be up before Mnesia join.
sleep 5
rabbitmqctl await_startup 2>&1 | tee -a "$MARKER_LOG" || true

echo "Joining cluster $SEED_NODENAME …" | tee -a "$MARKER_LOG"
set +e
rabbitmqctl stop_app 2>&1 | tee -a "$MARKER_LOG"
rc_join=0
rabbitmqctl join_cluster "$SEED_NODENAME" 2>&1 | tee -a "$MARKER_LOG" || rc_join=$?
set -e
if (( rc_join != 0 )); then
  echo "join_cluster exited with $rc_join (will still try start_app; may be already-joined on retry)" | tee -a "$MARKER_LOG" >&2
fi

if ! rabbitmqctl start_app 2>&1 | tee -a "$MARKER_LOG"; then
  echo "start_app failed" | tee -a "$MARKER_LOG" >&2
  exit 1
fi

# Mark success (survives restarts; skip join on next start)
sleep 2
if rabbitmq-diagnostics -q check_running; then
  {
    date -Iseconds
    echo "Marking cluster join complete for this node."
  } | tee -a "$MARKER_LOG"
  date -Iseconds > "$MARKER"
else
  echo "Node not running after join" | tee -a "$MARKER_LOG" >&2
  exit 1
fi

wait
