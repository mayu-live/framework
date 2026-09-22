# Reading Mayu metrics

Mayu exposes Prometheus metrics at the configured `[*.metrics].listen` URL.
The example application exposes them at `http://localhost:9091/metrics` in
development. Import [mayu-overview.json](grafana/mayu-overview.json) into
Grafana and select the Prometheus datasource when prompted.

## Health and traffic

| Metric                        | Meaning                                              | Useful view                           |
| ----------------------------- | ---------------------------------------------------- | ------------------------------------- |
| `mayu_active_sessions`        | Sessions currently held by the server.               | Current total.                        |
| `mayu_session_starts_total`   | Sessions created from HTML requests.                 | Per-second rate.                      |
| `mayu_session_timeouts_total` | Sessions removed after losing contact.               | Per-second rate; compare with starts. |
| `mayu_session_pings_total`    | Browser liveness pings received.                     | Per-second rate.                      |
| `mayu_callback_events_total`  | Callbacks handled, labelled by component and method. | Per-second rate and top callbacks.    |
| `mayu_navigations_total`      | Client-side navigations handled.                     | Per-second rate.                      |

Navigation metrics intentionally have no raw `path` label. Dynamic URLs can
otherwise create unbounded Prometheus series.

## Server rendering and reconciliation

| Metric                                           | Meaning                                                                                     | Useful view                                              |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| `mayu_component_render_duration_milliseconds`    | Time inside a component's Ruby `render` method, labelled by component.                      | Average duration: `rate(..._sum) / rate(..._count)`.     |
| `mayu_component_reconcile_duration_milliseconds` | Time reconciling a component's rendered descriptor children, labelled by component.         | Average duration and top components.                     |
| `mayu_component_mounts_total`                    | Component instances mounted, labelled by component.                                         | Per-second rate.                                         |
| `mayu_reconcile_continuations_total`             | Reconciliation passes resumed after exceeding Mayu's update budget, labelled by parent tag. | Per-second rate; non-zero values identify large updates. |
| `mayu_replace_children_ids_total`                | DOM child IDs included in `ReplaceChildren` commands, labelled by parent tag.               | Per-second rate; a proxy for browser DOM reorder work.   |

`render_duration` is server-side Ruby time; it is not browser DOM-apply time.
`reconcile_duration` includes Mayu's server-side VDOM child reconciliation.
Use both with callback rate: a component that is slow but rarely used is a
different problem from a cheap component called thousands of times per minute.

## Callback latency and stream cost

| Metric                                        | Meaning                                                                                 | Useful view                                                           |
| --------------------------------------------- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `mayu_callback_queue_duration_milliseconds`   | Time a callback waits for its component's work queue, labelled by component and method. | Average duration; sustained growth means component work is backed up. |
| `mayu_callback_handler_duration_milliseconds` | Time spent running a callback handler, labelled by component and method.                | Average duration and slowest callback.                                |
| `mayu_command_batches_total`                  | Command batches written to open session streams.                                        | Per-second rate.                                                      |
| `mayu_command_batch_commands_total`           | Individual commands in those batches.                                                   | Commands per batch: `rate(commands) / rate(batches)`.                 |
| `mayu_command_batch_uncompressed_bytes_total` | MessagePack bytes before stream compression.                                            | Byte rate and compression ratio.                                      |
| `mayu_command_batch_compressed_bytes_total`   | Deflate bytes written to the session stream.                                            | Actual server-to-browser payload byte rate.                           |

Callback queue duration covers time from receiving an event until its component
starts handling it; handler duration excludes later rendering and reconciliation.
Command-batch byte counters cover server-to-browser commands, including each
batch's streaming compression flush, not request or asset traffic.

## Metric lifecycle

The old metric names were replaced rather than emitted in parallel. Update
existing dashboards and alerts to the names above when upgrading. Mayu's
metric labels are deliberately bounded: component module paths, callback
methods, and HTML tag names—not session IDs, user IDs, or concrete URLs.
