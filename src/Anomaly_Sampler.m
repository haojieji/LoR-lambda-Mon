function varargout = Anomaly_Sampler(operation, varargin)
% ANOMALY_SAMPLER Evaluate SCS-constrained anomaly occurrence probabilities.
%   Anomaly Sampler (Section 4.3). Composite_Sampler owns candidate timing,
%   random acceptance, anomaly detection, and event insertion; this component
%   computes the intensities and excitation state used by that sampler.
%
%   [lambda_current, lambda_max, G, Lambda, Lambda_normalize] = ...
%       Anomaly_Sampler('initial', metric_idx, enhanced_base_time, T, ...
%       w_size, w, events, Par, ...
%       anomaly_mu, anomaly_A, anomaly_beta, G, Lambda, Lambda_normalize, ...
%       original_window_times)
%   Return scalar base intensity and its bound; overwrite G entries for
%   parents with available events and store this time's intensity/probability.
%
%   [lambda_candidate, G, Lambda, Lambda_normalize] = ...
%       Anomaly_Sampler('candidate', metric_idx, enhanced_candidate_time, ...
%       interval_Y, T, w_size, w, ...
%       events, Par, anomaly_mu, anomaly_A, anomaly_beta, G, Lambda, ...
%       Lambda_normalize)
%   Return scalar candidate intensity, add new event contributions to G, and
%   store this time's intensity/probability. interval_Y is the candidate gap.
%
%   [lambda_candidate, G, Lambda, Lambda_normalize] = ...
%       Anomaly_Sampler('self', metric_idx, enhanced_candidate_time, T, ...
%       w_size, w, anomaly_A, ...
%       anomaly_beta, lambda_candidate, G, Lambda, Lambda_normalize)
%   After event insertion by the caller, add self-excitation to the scalar
%   candidate intensity and G(metric_idx,metric_idx), then store the result.
%
%   [Lambda, Lambda_normalize] = Anomaly_Sampler('history', M, ...
%       original_time_range, normalization_time_range, events, Par, ...
%       anomaly_mu, anomaly_A, ...
%       anomaly_beta, Lambda, Lambda_normalize)
%   Replace the selected original-time columns for all M metrics. The
%   normalization_time_range selects denominator columns; [] uses the full
%   metric row. Other operations also normalize using the full metric row.
%
%   Shared shapes: anomaly_mu is M-by-1; anomaly_A, anomaly_beta, and G are
%   M-by-M (target metric by parent). events and Par are M-by-1 cells holding
%   row vectors of original event times and allowed parent/self metric indices.
%   Lambda/Lambda_normalize are M-by-original_time_count arrays. Events,
%   parents, and parameters are read-only; only returned state is modified.
%   T is the segment length; w_size/w are enhanced/original window batch counts.
%   Enhanced times map to original times by subtracting w_size*T, then adding
%   w*T. Initial intensity retains a legacy mixed-coordinate lag (see below).
%   Candidate decay affects the evaluated intensity; G changes only when
%   event contributions are accumulated, and is not replaced by its decay.

switch operation
    case 'initial'
        [varargout{1:nargout}] = initialIntensity(varargin{:});
    case 'candidate'
        [varargout{1:nargout}] = candidateIntensity(varargin{:});
    case 'self'
        [varargout{1:nargout}] = selfExcitation(varargin{:});
    case 'history'
        [varargout{1:nargout}] = historyIntensity(varargin{:});
    otherwise
        error('Anomaly_Sampler:UnknownOperation', 'Unknown operation: %s', operation);
end
end

function [lambda_current, lambda_max, G, Lambda, Lambda_normalize] = ...
    initialIntensity(metric_idx, enhanced_base_time, T, w_size, w, events, Par, ...
    anomaly_mu, anomaly_A, anomaly_beta, G, Lambda, Lambda_normalize, original_window_times)
lambda_current = anomaly_mu(metric_idx);
for parent_metric_idx = Par{metric_idx}
    past_events = events{parent_metric_idx}(events{parent_metric_idx} <= ...
        enhanced_base_time-w_size*T+w*T);
    if ~isempty(past_events)
        % Legacy lag: enhanced base time minus original event times. Preserve
        % this expression even though the event cutoff uses original time.
        dt = enhanced_base_time - past_events;
        contrib = anomaly_A(metric_idx, parent_metric_idx) * ...
            anomaly_beta(metric_idx, parent_metric_idx) * ...
            exp(-anomaly_beta(metric_idx, parent_metric_idx) * dt);
        G(metric_idx, parent_metric_idx) = sum(contrib);
        lambda_current = lambda_current + G(metric_idx, parent_metric_idx);
    end
end
lambda_current = max(0,lambda_current);
Lambda(metric_idx,enhanced_base_time-w_size*T+w*T) = lambda_current;
lambda_max = max(Lambda(metric_idx,original_window_times));
Lambda_normalize(metric_idx, enhanced_base_time-w_size*T+w*T) = lambda_current/max(eps, ...
    max(Lambda(metric_idx,:)));
end

function [lambda_candidate, G, Lambda, Lambda_normalize] = ...
    candidateIntensity(metric_idx, enhanced_candidate_time, interval_Y, T, w_size, w, ...
    events, Par, anomaly_mu, anomaly_A, anomaly_beta, G, Lambda, Lambda_normalize)
lambda_candidate = anomaly_mu(metric_idx);
for parent_metric_idx = Par{metric_idx}
    lambda_candidate = lambda_candidate + G(metric_idx,parent_metric_idx) * ...
        exp(-anomaly_beta(metric_idx, parent_metric_idx) * interval_Y);
end
% Select new parent/self events in the original-time interval (start, end].
for parent_metric_idx = Par{metric_idx}
    add_events = events{parent_metric_idx}( ...
        events{parent_metric_idx}<=enhanced_candidate_time-w_size*T+w*T & ...
        events{parent_metric_idx}>enhanced_candidate_time-w_size*T+w*T-interval_Y);
    if ~isempty(add_events)
        dt = enhanced_candidate_time-w_size*T+w*T - add_events;
        contrib = anomaly_A(metric_idx, parent_metric_idx)* ...
            anomaly_beta(metric_idx, parent_metric_idx)* ...
            exp(-anomaly_beta(metric_idx, parent_metric_idx).*dt);
        G(metric_idx, parent_metric_idx) = G(metric_idx, parent_metric_idx)+ sum(contrib);
        lambda_candidate = lambda_candidate + sum(contrib);
    end
end
Lambda(metric_idx,enhanced_candidate_time-w_size*T+w*T) = lambda_candidate;
Lambda_normalize(metric_idx, enhanced_candidate_time-w_size*T+w*T) = ...
    Lambda(metric_idx,enhanced_candidate_time-w_size*T+w*T)/max(eps,max(Lambda(metric_idx, :)));
end

function [lambda_candidate, G, Lambda, Lambda_normalize] = ...
    selfExcitation(metric_idx, enhanced_candidate_time, T, w_size, w, anomaly_A, anomaly_beta, ...
    lambda_candidate, G, Lambda, Lambda_normalize)
new_contrib = anomaly_A(metric_idx,metric_idx)*anomaly_beta(metric_idx,metric_idx);
G(metric_idx,metric_idx) = G(metric_idx,metric_idx) + new_contrib;
lambda_candidate = lambda_candidate + new_contrib;

Lambda(metric_idx,enhanced_candidate_time-w_size*T+w*T) = lambda_candidate;
Lambda_normalize(metric_idx, enhanced_candidate_time-w_size*T+w*T) = ...
    Lambda(metric_idx,enhanced_candidate_time-w_size*T+w*T)/max(eps,max(Lambda(metric_idx, :)));
end

function [Lambda, Lambda_normalize] = historyIntensity(M, original_time_range, ...
    normalization_time_range, events, Par, anomaly_mu, anomaly_A, anomaly_beta, ...
    Lambda, Lambda_normalize)
for metric_idx = 1:M
    for original_time = original_time_range
        lambda_i_j = anomaly_mu(metric_idx);
        for parent_metric_idx = Par{metric_idx}
            past_events = events{parent_metric_idx}(events{parent_metric_idx}<=original_time);
            if ~isempty(past_events)
                dt = original_time-past_events;
                contrib = anomaly_A(metric_idx, parent_metric_idx) * ...
                    anomaly_beta(metric_idx, parent_metric_idx) * ...
                    exp(-anomaly_beta(metric_idx, parent_metric_idx)*dt);
                lambda_i_j = lambda_i_j + sum(contrib);
            end
        end
        Lambda(metric_idx,original_time) = lambda_i_j;
    end
    if isempty(normalization_time_range)
        Lambda_normalize(metric_idx,original_time_range) = ...
            Lambda(metric_idx,original_time_range)./max(Lambda(metric_idx,:));
    else
        Lambda_normalize(metric_idx,original_time_range) = ...
            Lambda(metric_idx,original_time_range)./max(Lambda(metric_idx,normalization_time_range));
    end
end
end
