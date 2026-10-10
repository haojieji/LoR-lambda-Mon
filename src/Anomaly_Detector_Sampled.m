function [W, U_W_union, Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_MEDIANs, Cauchy_MADs, ...
    events, new_events, Omega_Cauchy] = ...
    Anomaly_Detector_Sampled(W, U_W_union, U_W_union_idx, beta, SPIKE_LIMIT, DIP_LIMIT, ...
    Cauchy_MEDIANs, Cauchy_MADs, Cauchy_Trans, T, t, w_size, w, events, new_events, Omega, ...
    Omega_Anomalies, X, W_idx)
% ANOMALY_DETECTOR_SAMPLED Update anomaly events after recovery collection.
%   Anomaly Detector (Section 4.1). W is M-by-(w_size*T), and its last beta
%   batches are newly collected recovery data, 1 <= beta <= min(w_size,H).
%   T is the number of samples per batch. U_W_union is T-by-H-by-M;
%   nonzero entries of row-vector U_W_union_idx identify its packed columns.
%   W_idx lists the w_size batch indices of W on the self-embedded timeline;
%   t is the current batch index. w is the original training length in batches.
%   X is M-by-N_e data on that timeline, available through W_idx(end)*T.
%   Each metric's median/MAD is recomputed over X(:,1:W_idx(end)*T), including
%   reconstructed values. SPIKE_LIMIT/DIP_LIMIT are scalar CDF cutoffs;
%   Cauchy_Trans(values,median) is a shape-preserving transform.
%   Omega and Omega_Anomalies are unused compatibility inputs; they do not
%   filter statistics or detection. Incoming 1-by-M median/MAD state is replaced.
%
%   Return updated W/U_W_union, M-by-(beta*T) spike/dip masks, 1-by-M updated
%   medians/MADs, events/new_events, and an M-by-(beta*T) combined mask. The
%   combined mask can differ from the spike/dip union after fallback handling.
%   W/history interpolation uses normal points only within the beta batches.
%   With fewer than two such points, values stay unchanged and the combined
%   row is set to all anomalies. The M-cell event arrays append original-time
%   sample indices (t-w_size+w-beta)*T + local_index; existing entries persist.

M = size(W,1);

% 1. Refit robust statistics on the available prefix and detect recent tails.
transformed_recent_values = zeros(M, beta*T);
Cauchy_CDF = zeros(M, beta*T);
Omega_Cauchy_large = zeros(M, beta*T);
Omega_Cauchy_small = zeros(M, beta*T);
statistics_time_indices = (1 : W_idx(end)*T);

for metric_idx = 1:M

    statistics_values = X(metric_idx, statistics_time_indices);

    Cauchy_MEDIANs(metric_idx) = median(statistics_values);
    Cauchy_MADs(metric_idx) = median(abs(statistics_values - Cauchy_MEDIANs(metric_idx)));

    transformed_recent_values = Cauchy_Trans( W(metric_idx, (w_size-beta)*T+1:w_size*T), Cauchy_MEDIANs(metric_idx) );

    Cauchy_CDF(metric_idx,:) = (1/pi) * atan( (transformed_recent_values-Cauchy_MEDIANs(metric_idx))/(Cauchy_MADs(metric_idx)+eps) ) + 0.5;

    Omega_Cauchy_large(metric_idx, Cauchy_CDF(metric_idx,:)>SPIKE_LIMIT) = 1; % spike
    Omega_Cauchy_small(metric_idx, Cauchy_CDF(metric_idx,:)<DIP_LIMIT) = 1; % dip

end

% 2. Keep one anomaly type if their union covers the whole recovery interval.
Omega_Cauchy = double(Omega_Cauchy_large | Omega_Cauchy_small);
for metric_idx=1:M
    if sum(Omega_Cauchy(metric_idx,:)) == beta*T
        if sum(Omega_Cauchy_large(metric_idx,:)) < sum(Omega_Cauchy_small(metric_idx,:))
            Omega_Cauchy(metric_idx,:) = Omega_Cauchy_large(metric_idx,:);
        else
            Omega_Cauchy(metric_idx,:) = Omega_Cauchy_small(metric_idx,:);
        end
    end
end

% 3. Interpolate recent anomalies using the matching history-column positions.
for metric_idx=1:M
    anomaly_indices = find( Omega_Cauchy(metric_idx, :)==1 );
    metric_history = U_W_union(:,:,metric_idx);
    history_count = length(find((U_W_union_idx(1,:)~=0)));
    % Linear indices span the final beta columns of this metric's T-by-H history.
    history_anomaly_indices = (history_count-beta)*T + anomaly_indices;
    metric_history(history_anomaly_indices) = 0;
    if ~isempty(history_anomaly_indices)
        normal_indices = find( Omega_Cauchy(metric_idx, :)==0 );
        history_normal_indices = (history_count-beta)*T + normal_indices;
        if length(normal_indices)>=2
            interpolated_values = interp1(history_normal_indices, metric_history(history_normal_indices), history_anomaly_indices,'linear','extrap');
            W(metric_idx, (w_size-beta)*T+anomaly_indices) = interpolated_values;
            metric_history(history_anomaly_indices) = interpolated_values;
            U_W_union(:,:,metric_idx) = metric_history;
        else
            Omega_Cauchy(metric_idx,:) = ones(1,beta*T);
        end
    end

    anomaly_indices = find( Omega_Cauchy(metric_idx, :)==1 );
    % 4. Convert local recovery positions to the original, unembedded timeline.
    original_anomaly_times = (t-w_size+w-beta)*T + anomaly_indices;
    events{metric_idx} = [events{metric_idx} original_anomaly_times];
    new_events{metric_idx} = [new_events{metric_idx} original_anomaly_times];
end
