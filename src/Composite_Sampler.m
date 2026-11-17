function [Omega_t_m, Omega_t_m_r, Omega_t_m_L, Omega_t_m_Anomalies, Omega_Anomalies, events, ...
    new_events, Lambda, Lambda_normalize] = ...
    Composite_Sampler(metric_idx, sample_budget, T, param, X_t_m, X, Omega, ...
    Omega_Anomalies, events, new_events, Par, Cauchy_MEDIANs, Cauchy_MADs, Cauchy_Trans, ...
    W_idx, w_size, w, anomaly_mu, anomaly_A, anomaly_beta, Lambda, Lambda_normalize)
% COMPOSITE_SAMPLER Combine base and anomaly-guided samples for one metric.
%   Section IV-D: Composite Sampler.
%   sample_budget is the base sample count for the 1-by-T vector X_t_m.
%   The first four outputs mark normal, base, additional, and anomalous samples
%   within this batch. events/new_events use original time; X uses enhanced time.
%   W_idx contains enhanced batch indices; w_size/w count enhanced/original
%   training batches.
%   Candidate acceptance uses ten random levels and a historical intensity maximum.
%   Base and candidate writes to Omega_Anomalies retain different coordinates;
%   see ../README.md#sampling-ratio for the sampling-count limitation.

%% 1. Base sampling from the Low-Rank Sampler budget
Omega_t_m = generate_base_schedule(T, sample_budget)';
Omega_t_m_r = Omega_t_m;
Omega_t_m_L = zeros(size(Omega_t_m));
base_interval = ceil(T/sample_budget);

%% 2. Anomaly-guided sampling between base samples
Omega_t_m_Anomalies = zeros(size(Omega_t_m));
base_local_times = find(Omega_t_m==1);
reconstructed_prefix_times = (1 : W_idx(w_size)*T);
original_batch_end = W_idx(w_size)-w_size+w;
original_window_times = ((original_batch_end-w)*T+1 : original_batch_end*T);

% Accumulated excitation from permitted parent/self events.
G = zeros(size(X,1),size(X,1));
for base_local_time = base_local_times
    enhanced_base_time = W_idx(w_size-1)*T+base_local_time;

    % Refresh median/MAD from the full reconstructed prefix through the
    % current enhanced batch, including any still-unfilled values in X.
    reconstructed_prefix = X(metric_idx, reconstructed_prefix_times);
    Cauchy_MEDIANs(metric_idx) = median( reconstructed_prefix );
    Cauchy_MADs(metric_idx) = median(abs(reconstructed_prefix - Cauchy_MEDIANs(metric_idx)));

    x = Cauchy_Trans( X_t_m(base_local_time), Cauchy_MEDIANs(metric_idx) );
    cdf_value = (1/pi) * atan( (x - Cauchy_MEDIANs(metric_idx)) / ...
        (eps+Cauchy_MADs(metric_idx)) ) + 0.5;

    if cdf_value >= param.SPIKE_LIMIT || cdf_value <= param.DIP_LIMIT
        events{metric_idx}(end+1) = enhanced_base_time-w_size*T+w*T;
        new_events{metric_idx}(end+1) = enhanced_base_time-w_size*T+w*T;
        Omega_Anomalies(metric_idx, enhanced_base_time) = 1;
        Omega_t_m_Anomalies(base_local_time) = 1;
        Omega_t_m(base_local_time) = 0;
        Omega_t_m_r(base_local_time) = 0;
    end

    % Initialize the anomaly intensity for this base-sampling interval.
    [lambda_current, lambda_max, G, Lambda, Lambda_normalize] = ...
        Anomaly_Sampler('initial', metric_idx, enhanced_base_time, T, w_size, w, events, Par, ...
        anomaly_mu, anomaly_A, anomaly_beta, G, Lambda, Lambda_normalize, original_window_times);

    candidate_local_time = base_local_time;
    enhanced_candidate_time = W_idx(w_size-1)*T+candidate_local_time;
    while candidate_local_time <= min(base_local_time+base_interval,T)
        % Advance to the next candidate time.
        lambda_max = max(lambda_max, lambda_current);
        interval_Y = max( floor(1/max(lambda_max,eps)), 1 );

        candidate_local_time = candidate_local_time + interval_Y;
        enhanced_candidate_time = enhanced_candidate_time + interval_Y;
        if candidate_local_time > min(base_local_time+base_interval,T)
            break;
        end
        % Evaluate the decayed excitation at this candidate time.
        [lambda_candidate, G, Lambda, Lambda_normalize] = ...
            Anomaly_Sampler('candidate', metric_idx, enhanced_candidate_time, interval_Y, ...
            T, w_size, w, events, Par, anomaly_mu, anomaly_A, anomaly_beta, G, ...
            Lambda, Lambda_normalize);
        % Accept using one of ten random levels and the historical maximum.
        if lambda_candidate>0 && (randi([0,9])*0.1) < lambda_candidate/max(Lambda(metric_idx,:))
            Omega_t_m(candidate_local_time) = 1;
            Omega_t_m_L(candidate_local_time) = 1;

            % Detect newly sampled anomalies and update the event history.
            x = Cauchy_Trans( X_t_m(candidate_local_time), Cauchy_MEDIANs(metric_idx) );
            cdf_value = (1/pi) * atan( (x - Cauchy_MEDIANs(metric_idx)) / ...
                (Cauchy_MADs(metric_idx)+eps) ) + 0.5;
            if cdf_value >= param.SPIKE_LIMIT || cdf_value <= param.DIP_LIMIT
                events{metric_idx}(end+1) = enhanced_candidate_time-w_size*T+w*T;
                new_events{metric_idx}(end+1) = enhanced_candidate_time-w_size*T+w*T;
                Omega_Anomalies(metric_idx, enhanced_candidate_time-w_size*T+w*T) = 1;
                Omega_t_m_Anomalies(candidate_local_time) = 1;
                Omega_t_m(candidate_local_time) = 0;
                Omega_t_m_L(candidate_local_time) = 0;

                % Add self-excitation from the newly detected anomaly.
                [lambda_candidate, G, Lambda, Lambda_normalize] = ...
                    Anomaly_Sampler('self', metric_idx, enhanced_candidate_time, T, ...
                    w_size, w, anomaly_A, anomaly_beta, lambda_candidate, G, ...
                    Lambda, Lambda_normalize);
            end
        end
        lambda_current = lambda_candidate;
    end
end

% Retain at least one sample for the normal-data representation.
if isempty(find(Omega_t_m==1))
    Omega_t_m(base_local_times(1)) = 1;
end
