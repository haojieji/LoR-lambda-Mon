function varargout = Anomaly_Sampler(operation, varargin)
% ANOMALY_SAMPLER Evaluate anomaly intensities for additional sampling.
%   Section IV-C: Anomaly Sampler.
%   initial: evaluate intensity at a base sample and initialize excitation.
%   candidate: evaluate a candidate using decay and intervening events.
%   self: add the contribution of a newly detected anomaly in this metric.
%   history: evaluate intensity over a specified original-time range.
%
%   events/Par contain original event times and permitted parent/self indices.
%   anomaly_mu is M-by-1; anomaly_A/anomaly_beta/G are M-by-M (target by parent).
%   Lambda stores intensities; Lambda_normalize divides by historical maxima.
%   Composite_Sampler schedules and accepts candidates and records events.
%   This snapshot retains the mixed-coordinate initial lag and the candidate
%   update that decays intensity without replacing G with its decayed value;
%   see ../algorithm_overview.md for the retained implementation details.

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
