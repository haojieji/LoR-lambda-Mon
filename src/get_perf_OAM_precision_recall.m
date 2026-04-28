function [perf_Precision, perf_Recall, perf_F1, perf_label_anomalies] = get_perf_OAM_precision_recall(X_hat, Labels_anomalies_X, M, w, T)
%GET_PERF_OAM_PRECISION_RECALL Compute global anomaly precision, recall, and F1.
%
% These metrics are the global/micro scores used by the experiment: TP, FP,
% and FN are counted over all metrics and all evaluation time points before
% precision, recall, and F1 are calculated.

SPIKE_LIMIT = 0.92;
DIP_LIMIT = 0.08;
Omega_Cauchy_large = zeros(size(X_hat));
Omega_Cauchy_small = zeros(size(X_hat));
Cauchy_Trans = @(x, m) (x >= m) .* x + ...
    (x < m) .* ((2*m/pi) * tan((pi*(x - m))/(2*m)) + m);
[~, Omega_Cauchy_large, Omega_Cauchy_small, ~, ~, ~, ~] = ...
    subfunc_robust_AnomalyDetect_Cauchy_w(X_hat, SPIKE_LIMIT, DIP_LIMIT, ...
    Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_Trans);
perf_label_anomalies = double(Omega_Cauchy_large | Omega_Cauchy_small);

pred = perf_label_anomalies(:, w*T+1:end) ~= 0;
truth = Labels_anomalies_X(:, w*T+1:end) ~= 0;

perf_TP = sum(sum(double(pred & truth)));
perf_FP = sum(sum(double(pred & ~truth)));
perf_FN = sum(sum(double(~pred & truth)));

perf_Precision = safeDivide(perf_TP, perf_TP + perf_FP);
perf_Recall = safeDivide(perf_TP, perf_TP + perf_FN);
perf_F1 = safeDivide(2 * (perf_Precision * perf_Recall), ...
    perf_Precision + perf_Recall);
end

function value = safeDivide(numerator, denominator)
% Return 0 for undefined 0/0 precision/recall cases instead of NaN.
if denominator == 0
    value = 0;
else
    value = numerator / denominator;
end
end
