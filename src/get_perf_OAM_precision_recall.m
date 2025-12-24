% Anomaly Monitoring Performance: precision, recall, F1
% INPUT: X_hat: monitored results, Labels_anomalies_X: anomaly labels in groundtruth X
% OUTPUT: perf_Precision ,perf_Recall, perf_F1
function [perf_Precision, perf_Recall, perf_F1, perf_label_anomalies] = get_perf_OAM_precision_recall(X_hat, Labels_anomalies_X, M,w,T)
    
    SPIKE_LIMIT = 0.92;
    DIP_LIMIT = 0.08;
    Omega_Cauchy_large = zeros(size(X_hat));
    Omega_Cauchy_small = zeros(size(X_hat));
    Cauchy_Trans = @(x, m) (x >= m) .* x + (x < m) .* ( (2*m/pi) * tan( (pi*(x - m))/(2*m) ) + m );
    [~, Omega_Cauchy_large, Omega_Cauchy_small, ~, ~, ~, ~] = subfunc_robust_AnomalyDetect_Cauchy_w(X_hat, SPIKE_LIMIT, DIP_LIMIT, Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_Trans);
    perf_label_anomalies = double( Omega_Cauchy_large | Omega_Cauchy_small);
   
    % Precision = TP / (TP+FP)
    perf_TP = sum(sum( double(perf_label_anomalies(:, w*T+1:end) & Labels_anomalies_X(:,w*T+1:end))));
    perf_FP = sum(sum( double(perf_label_anomalies(:, w*T+1:end) & (ones(M,size(X_hat,2)-w*T)-Labels_anomalies_X(:, w*T+1:end)))));
    perf_FN = sum(sum( double( (ones(M,size(X_hat,2)-w*T)-perf_label_anomalies(:, w*T+1:end)) & Labels_anomalies_X(:, w*T+1:end))));
    perf_Precision = perf_TP / (perf_TP + perf_FP);
    perf_Recall = perf_TP / (perf_TP + perf_FN);

    perf_F1 = 2*(perf_Precision*perf_Recall)/(perf_Precision+perf_Recall);
    
end