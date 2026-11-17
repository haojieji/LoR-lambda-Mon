# Algorithm overview

CauSample uses the same learned sparse causal structure (SCS) for two tasks: local parent representations guide reconstruction and base sampling, while directed dependencies constrain anomaly propagation and additional sampling. The [source guide](src/README.md#paper-to-code-map) maps these components to Sections IV-A--IV-F.

## Workflow

**Offline.** Learn the SCS from original training data, then separate anomalies. Prepare temporal histories and ranks for reconstruction, and learn the anomaly model from original-time events. Root metrics use temporal rank; child metrics use their parent count in the base-budget calculation.

**Online.** Advance the data window and estimate base budgets. The Composite Sampler collects base samples and accepts additional candidates using anomaly intensities. Detected anomalies enter the event history. The Reconstructor estimates missing values and restores collected values; the Model Updater uses new events to update the anomaly model. If reconstruction is unavailable, subsequent complete batches supply recovery history.

## Notation and state

| Code | Meaning |
| --- | --- |
| `M`, `T`, `w` | Metric count, batch length, and training-window batch count; `w` is the paper's `W` |
| `X`, `X_e` | Original-time normalized data; embedded training data followed by online batches |
| `w_size` | Embedded training-batch count, `T*w-T+1` |
| `W` | Data-window matrix in code, not the scalar paper window size |
| `B(m,p)`, `Stru`, `Ord` | Weight of parent `p` to child `m`, binary adjacency, and within-cluster order |
| `U_W`, `U_W_idx` | Historical temporal columns and their enhanced batch indices |
| `events`, `new_events`, `Lambda` | Original-time event histories, new events, and anomaly intensities |
| `pending_batch`, `recovery_batch_count` | Batch awaiting reconstruction and count of complete recovery batches |

For online data, original time equals enhanced time minus `(w_size-w)*T`; batch-local positions range from 1 to `T`. `_r` and `_L` distinguish base and additional normal-sample indicators. Sampled anomalies are recorded separately. Recovery indicators can overlap, so their counts must not simply be added.

## Implementation conventions and retained limitations

These details describe the current implementation. Unlike commit `e13087b`, child reconstruction does not append the child's own history to the initial parent dictionary; that history is supplied separately to ALS when needed.

- **Budgets (IV-B/IV-D).** Both metric types use `max(theta*q*log(q),1)`, with temporal rank or parent count as `q`. This scaled local-rank budget does not explicitly evaluate the joint bound's `K`, `l`, and failure probability. Base intervals use `ceil(T/sample_budget)`. Additional acceptance uses ten random levels and historical maximum intensity.
- **Reconstruction (IV-E).** For a child with reconstructed parents and available history, the initial fit uses parent data. If its sampled residual is at least `yita`, ALS combines that parent dictionary with a separate child-history block. `U_W` receives fully collected training/recovery batches, not ordinary reconstructed batches. Delayed recovery processes children by metric index.
- **Parameter learning (IV-C/IV-F).** EM includes self-event weighting (`alpha=1.5`) and an offline diagonal adjustment (`gamma/eps` at the point of use). Online updates retain accumulated statistics but use window-based denominators; they are approximate incremental updates.
- **Sampling accounting.** Base anomaly positions use enhanced time, but additional anomaly positions use original time in the same returned matrix. Because evaluation excludes enhanced training columns, the reported sampling ratio can omit acquired anomaly samples. This cleanup leaves that known limitation unchanged; the reported ratio is not a validated count of all acquired entries.
- **Intensity evaluation.** Initial intensity subtracts original-time event indices from an enhanced-time current index. Candidate evaluation applies decay without saving the decayed excitation back to `G`. These retained calculations can affect anomaly predictions; documentation cleanup does not correct them.

## Evaluation outputs

`CauSample` evaluates after training. Its reported sampling ratio uses the union of recorded normal/anomaly indicators. NMAE is the mean across metrics of absolute reconstruction error divided by the absolute reference sum, on the original metric scale. Precision, recall, and F1 pool counts across online metric entries against per-metric Cauchy labels; see [data format](data_format.md#evaluation-labels).

`avg_cpu_decision`, `avg_cpu_sampling`, `avg_cpu_reconstruction`, and `avg_cpu_modelupdate` report per-batch CPU seconds for their code regions. Budget calculation is inside the sampling timer, so the decision timer alone does not include every frequency-related calculation. `time_sample_permetric` reports elapsed sampling time. CPU and elapsed time are not interchangeable; these fields alone do not establish a paper figure's timing provenance.
