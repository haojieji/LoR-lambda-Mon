# Dataset inventory

| Dataset | Input | Contents |
| --- | --- | --- |
| TPC-C, labeled | [TPC_C_metrics_with_labels.csv.gz](TPC_C_metrics_with_labels.csv.gz) | Database metric trace with timestamp and label columns. |
| TPC-C, unlabeled | [TPC_C_metrics.csv.gz](TPC_C_metrics.csv.gz) | Database metric trace without label columns. |
| TPC-C fault events | [TPC_C_fault_timeline.csv](TPC_C_fault_timeline.csv) | Fault-injection timeline |
| Online Boutique | [BARO_OB_w7T50.mat](BARO_OB_w7T50.mat) | Metrics collected from the Online Boutique microservice application. |
| Sock Shop | [BARO_SS_w7T50.mat](BARO_SS_w7T50.mat) | Metrics collected from the Sock Shop microservice application. |

The original [labeled CSV](TPC_C_metrics_with_labels.csv) and [unlabeled CSV](TPC_C_metrics.csv) are also retained. Each gzip decompresses to its corresponding CSV byte for byte. File checksums are listed in [SHA256SUMS](../SHA256SUMS).

OB/SS originate from the [BARO artifact](https://github.com/phamquiluan/baro).

See the [quick start](../README.md#quick-start) for preparation and run commands, and [data format and preprocessing](../data_format.md) for schemas, saved MAT settings, and timelines.

Optional previews remain as [TPC_C_metrics.png](TPC_C_metrics.png) and [TPC_C_metrics_with_labels.png](TPC_C_metrics_with_labels.png).
