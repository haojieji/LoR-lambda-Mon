# Algorithm overview

CauSample uses the same learned sparse causal structure (SCS) for two tasks: local parent representations guide reconstruction and base sampling, while directed dependencies constrain anomaly propagation and additional sampling. The [source guide](src/README.md#paper-to-code-map) maps these components to Sections IV-A--IV-F.

## Workflow

**Offline.** Learn the SCS from original training data, then separate anomalies. Prepare temporal histories and ranks for reconstruction, and learn the anomaly model from original-time events. Root metrics use temporal rank; child metrics use their parent count in the base-budget calculation.

**Online.** Advance the data window and estimate base budgets. The Composite Sampler collects base samples and accepts additional candidates using anomaly intensities. Detected anomalies enter the event history. The Reconstructor estimates missing values and restores collected values; the Model Updater uses new events to update the anomaly model. If reconstruction is unavailable, subsequent complete batches supply recovery history.

## Notation and state

| Code | Meaning |
| --- | --- |
| `M`, `T`, `w` | Metric count, batch length, and training-window batch count; `w` is the paper's `W` |
| `X`, `X_e`, `w_size` | Data matrices and embedded training-batch count; see [data timelines](data_format.md#preprocessing-and-timelines) |
| `W` | Data-window matrix in code, not the scalar paper window size |
| `B(m,p)`, `Stru`, `Ord` | Weight of parent `p` to child `m`, binary adjacency, and within-cluster order |
| `U_W`, `U_W_idx` | Historical temporal columns and their enhanced batch indices |
| `events`, `new_events`, `Lambda` | Original-time event histories, new events, and anomaly intensities |
| `pending_batch`, `recovery_batch_count` | Batch awaiting reconstruction and count of complete recovery batches |

Time coordinates and embedding are defined in the [data format guide](data_format.md#preprocessing-and-timelines). `_r` and `_L` distinguish base and additional normal-sample indicators; sampled anomalies are recorded separately.

## Implementation conventions and retained limitations

These details describe the current implementation. Unlike commit `e13087b`, child reconstruction does not append the child's own history to the initial parent dictionary; that history is supplied separately to ALS when needed.

- **Budgets (IV-B/IV-D).** Both metric types use `max(theta*q*log(q),1)`, with temporal rank or parent count as `q`. This scaled local-rank budget does not explicitly evaluate the joint bound's `K`, `l`, and failure probability. Base intervals use `ceil(T/sample_budget)`. Additional acceptance uses ten random levels and historical maximum intensity.
- **Reconstruction (IV-E).** For a child with reconstructed parents and available history, the initial fit uses parent data. If its sampled residual is at least `yita`, ALS combines that parent dictionary with a separate child-history block. `U_W` receives fully collected training/recovery batches, not ordinary reconstructed batches. Delayed recovery processes children by metric index.
- **Parameter learning (IV-C/IV-F).** EM includes self-event weighting (`alpha=1.5`) and an offline diagonal adjustment (`gamma/eps` at the point of use). Online updates retain accumulated statistics but use window-based denominators; they are approximate incremental updates.
- **Intensity evaluation.** Initial intensity subtracts original-time event indices from an enhanced-time current index. Candidate evaluation applies decay without saving the decayed excitation back to `G`. These retained calculations can affect anomaly predictions; documentation cleanup does not correct them.

Output fields and evaluation metrics are defined in the [README](README.md#outputs-and-evaluation).
