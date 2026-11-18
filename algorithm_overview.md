# Algorithm overview

This guide summarizes the pipeline's offline and online stages and its main state variables. The [source guide](src/README.md#paper-to-code-map) maps the components to Sections IV-A--IV-F.

## Workflow

**Offline.** Learn the sparse causal structure (SCS) from training data, separate anomalies, initialize temporal representations, and fit the anomaly propagation model.

**Online.** Advance the data window, calculate base budgets, collect base and anomaly-guided samples, reconstruct missing values, and update the anomaly model from new events. When reconstruction needs additional observations, subsequent complete batches provide recovery data.

## Notation and state

| Code | Meaning |
| --- | --- |
| `M` | Metric count |
| `X`, `X_e`, `w_size` | Data matrices and embedded training-batch count; see [data timelines](data_format.md#preprocessing-and-timelines) |
| `W` | Data-window matrix in code, not the scalar paper window size |
| `B(m,p)`, `Stru`, `Ord` | Weight of parent `p` to child `m`, binary adjacency, and within-cluster order |
| `U_W`, `U_W_idx` | Historical temporal columns and their enhanced batch indices |
| `Omega_e`, `Omega_Anomalies_e` | Normal and anomaly sample indicators, respectively |
| `events`, `new_events`, `Lambda` | Original-time event histories, new events, and anomaly intensities |
| `pending_batch`, `recovery_batch_count` | Batch awaiting reconstruction and count of complete recovery batches |

See the README for [parameter settings](README.md#parameters) and [outputs and evaluation](README.md#outputs-and-evaluation).
