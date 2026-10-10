function [Omega_t_m, Omega_t_m_r, Omega_t_m_L, Omega_t_m_Anomalies, Omega_Anomalies, events, ...
    new_events, Lambda, Lambda_normalize] = ...
    Composite_Sampler(m, num_sample_f, T, param, X_t_m, X, Omega, Omega_Anomalies, events, ...
    new_events, Par, Cauchy_MEDIANs, Cauchy_MADs, Cauchy_Trans, W_idx, w_size, w, anomaly_mu, ...
    anomaly_A, anomaly_beta, Lambda, Lambda_normalize)
% COMPOSITE_SAMPLER Collect base and anomaly-guided samples for one metric.
%   Composite Sampler (Section 4.4).
%   num_sample_f specifies the base sample budget for the length-T segment
%   X_t_m. Build an equal-interval schedule, evaluate anomaly-guided candidate
%   times, and update events when a sampled value is anomalous.
%   Anomaly_Sampler computes occurrence rates Lambda and normalized anomaly
%   probabilities Lambda_normalize. The detector uses the supplied robust
%   statistics; candidate timing, random acceptance, and event updates remain
%   in this component.
%
%   Output sampling matrices distinguish retained normal values (Omega_t_m),
%   base samples (_r), additional samples (_L), and sampled anomalies
%   (Omega_t_m_Anomalies). Their union identifies collected values.

%% 1. Base sampling from the Low-Rank Sampler budget
Omega_t_m = generate_base_schedule(T, num_sample_f)';
Omega_t_m_r = Omega_t_m;
Omega_t_m_L = zeros(size(Omega_t_m));
interval = ceil(T/num_sample_f);

%% 2. Anomaly-guided sampling between base samples
Omega_t_m_Anomalies = zeros(size(Omega_t_m));
idx_Omega_t_m = find(Omega_t_m==1);
%range_w = ((W_idx(1)-1)*T+1 : W_idx(w)*T);
range_w = (1 : W_idx(w_size)*T);
W_end = W_idx(w_size)-w_size+w;
range_w_lambda = ((W_end-w)*T+1 : W_end*T);

% Accumulated excitation from permitted parent/self events.
G = zeros(size(X,1),size(X,1));
for i = idx_Omega_t_m
    ti = W_idx(w_size-1)*T+i;

    % update Cauchy with samples in current window
    Omega_range_w = Omega(m, range_w);
    Omega_Anomalies_range_w = Omega_Anomalies(m, range_w);
    Omega_range_w = (Omega_range_w | Omega_Anomalies_range_w);
    %X_range_w = X(m, Omega_range_w);
    X_range_w = X(m, range_w);
    Cauchy_MEDIANs(m) = median( X_range_w );
    Cauchy_MADs(m) = median(abs(X_range_w - Cauchy_MEDIANs(m)));

    x = Cauchy_Trans( X_t_m(i), Cauchy_MEDIANs(m) );
    cdf_value = (1/pi) * atan( (x - Cauchy_MEDIANs(m)) / (eps+Cauchy_MADs(m)) ) + 0.5;

    if cdf_value >= param.SPIKE_LIMIT || cdf_value <= param.DIP_LIMIT
    %if X_t_m(i) >= param.epsilon_delta*mean(X_range_w) || X_t_m(i) <= param.epsilon_gamma*mean(X_range_w)
        events{m}(end+1) = ti-w_size*T+w*T;
        new_events{m}(end+1) = ti-w_size*T+w*T;
        Omega_Anomalies(m, ti) = 1;
        Omega_t_m_Anomalies(i) = 1;
        Omega_t_m(i) = 0;
        Omega_t_m_r(i) = 0;
    end

    % Predict candidate times before the next base sample.
    % Compute the current anomaly occurrence rate and its normalization.
    [lambda_curt, lambda_max, G, Lambda, Lambda_normalize] = ...
        Anomaly_Sampler('initial', m, ti, T, w_size, w, events, Par, ...
        anomaly_mu, anomaly_A, anomaly_beta, G, Lambda, Lambda_normalize, range_w_lambda);

    j = i;
    tj = W_idx(w_size-1)*T+j;
    while j <= min(i+interval,T)
        % Advance to the next candidate time.
        lambda_max = max(lambda_max, lambda_curt);
        interval_Y = max( floor(1/max(lambda_max,eps)), 1 );

        j = j + interval_Y;
        tj = tj + interval_Y;
        if j > min(i+interval,T)
            break;
        end
        % Decay the accumulated excitation to this candidate time.
        [lambda_candidate, G, Lambda, Lambda_normalize] = ...
            Anomaly_Sampler('candidate', m, tj, interval_Y, T, w_size, w, ...
            events, Par, anomaly_mu, anomaly_A, anomaly_beta, G, Lambda, Lambda_normalize);
        % Accept a candidate according to its normalized anomaly probability.
        if lambda_candidate>0 && (randi([0,9])*0.1) < lambda_candidate/max(Lambda(m,:))
            Omega_t_m(j) = 1;
            Omega_t_m_L(j) = 1;

            % Detect newly sampled anomalies and update the event history.
            x = Cauchy_Trans( X_t_m(j), Cauchy_MEDIANs(m) );
            cdf_value = (1/pi) * atan( (x - Cauchy_MEDIANs(m)) / (Cauchy_MADs(m)+eps) ) + 0.5;
            if cdf_value >= param.SPIKE_LIMIT || cdf_value <= param.DIP_LIMIT
                events{m}(end+1) = tj-w_size*T+w*T;
                new_events{m}(end+1) = tj-w_size*T+w*T;
                Omega_Anomalies(m, tj-w_size*T+w*T) = 1;
                Omega_t_m_Anomalies(j) = 1;
                Omega_t_m(j) = 0;
                Omega_t_m_L(j) = 0;

                % Add self-excitation from the newly detected anomaly.
                [lambda_candidate, G, Lambda, Lambda_normalize] = ...
                    Anomaly_Sampler('self', m, tj, T, w_size, w, anomaly_A, ...
                    anomaly_beta, lambda_candidate, G, Lambda, Lambda_normalize);
            end
        end
        lambda_curt = lambda_candidate;
    end
end

% Retain at least one sample for the normal-data representation.
if isempty(find(Omega_t_m==1))
    Omega_t_m(idx_Omega_t_m(1)) = 1;
end
