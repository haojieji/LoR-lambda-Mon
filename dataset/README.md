# Dataset inventory

| Dataset | Input | Contents |
| --- | --- | --- |
| TPC-C, labeled | [TPC_C_metrics_with_labels.csv.gz](TPC_C_metrics_with_labels.csv.gz) | 11,611 observations; timestamp, 76 metrics, `label1`, `label2` |
| TPC-C, unlabeled | [TPC_C_metrics.csv.gz](TPC_C_metrics.csv.gz) | 11,611 observations; timestamp and 77 metrics |
| TPC-C fault events | [TPC_C_fault_timeline.csv](TPC_C_fault_timeline.csv) | Fault-injection timeline |
| Online Boutique | [BARO_OB_w7T50.mat](BARO_OB_w7T50.mat) | Selected BARO trace; 54 retained metrics, 700 time steps |
| Sock Shop | [BARO_SS_w7T50.mat](BARO_SS_w7T50.mat) | Selected BARO trace; 54 retained metrics, 700 time steps |

The original [labeled CSV](TPC_C_metrics_with_labels.csv) and [unlabeled CSV](TPC_C_metrics.csv) are also retained. Each gzip decompresses to its corresponding CSV byte for byte. The labeled trace omits the unlabeled trace's `bussiness_time` metric; the runner uses the labeled trace.

Run `prepare_causample_data` from `src` to generate `TPC_C_metrics_with_labels.mat`, then use `CauSample('tpc_c')`. OB/SS are ready for `CauSample('online_boutique')` and `CauSample('sock_shop')`.

OB/SS originate from the [BARO artifact](https://github.com/phamquiluan/baro), not a release of every BARO experiment. Their saved settings are `T=50`, `W=7`, with thresholds 0.08/0.92. See [data preparation and labels](../data_format.md) for dimensions and evaluation details.

The earlier key `oltp` remains an alias for `tpc_c`. Current filenames use TPC-C; data contents are unchanged by this cleanup. Optional previews remain as [TPC_C_metrics.png](TPC_C_metrics.png) and [TPC_C_metrics_with_labels.png](TPC_C_metrics_with_labels.png).
