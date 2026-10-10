function varargout = Anomaly_Sampler(operation, varargin)
% ANOMALY_SAMPLER Evaluate SCS-constrained anomaly occurrence probabilities.
%   Anomaly Sampler (Section 4.3). Composite_Sampler owns candidate timing,
%   random acceptance, anomaly detection, and event insertion; this component
%   computes the intensities and excitation state used by that sampler.
%
%   [lambda_curt, lambda_max, G, Lambda, Lambda_normalize] = ...
%       Anomaly_Sampler('initial', m, ti, T, w_size, w, events, Par, ...
%       anomaly_mu, anomaly_A, anomaly_beta, G, Lambda, Lambda_normalize, ...
%       range_w_lambda)
%   Initialize the intensity at a base sample and its candidate-time bound.
%
%   [lambda_candidate, G, Lambda, Lambda_normalize] = ...
%       Anomaly_Sampler('candidate', m, tj, interval_Y, T, w_size, w, ...
%       events, Par, anomaly_mu, anomaly_A, anomaly_beta, G, Lambda, ...
%       Lambda_normalize)
%   Evaluate a candidate using accumulated excitation and available events.
%
%   [lambda_candidate, G, Lambda, Lambda_normalize] = ...
%       Anomaly_Sampler('self', m, tj, T, w_size, w, anomaly_A, ...
%       anomaly_beta, lambda_candidate, G, Lambda, Lambda_normalize)
%   Add self-excitation after the caller inserts a sampled anomaly event.
%
%   [Lambda, Lambda_normalize] = Anomaly_Sampler('history', M, time_range, ...
%       normalization_range, events, Par, anomaly_mu, anomaly_A, ...
%       anomaly_beta, Lambda, Lambda_normalize)
%   Evaluate training or updated history. normalization_range selects the
%   denominator's columns; [] uses the entire metric row of Lambda.
%
%   ti/tj retain the composite sampler's enhanced-timeline coordinates;
%   event lookup and stored intensities use ti/tj-w_size*T+w*T. Calculations
%   preserve the existing time differences, normalization ranges, and event
%   boundaries. Candidate decay affects the evaluated intensity, while G
%   itself changes only when event contributions are accumulated.

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

function [lambda_curt, lambda_max, G, Lambda, Lambda_normalize] = ...
    initialIntensity(m, ti, T, w_size, w, events, Par, anomaly_mu, anomaly_A, ...
    anomaly_beta, G, Lambda, Lambda_normalize, range_w_lambda)
lambda_curt = anomaly_mu(m);
for m_prime = Par{m}
    past_events = events{m_prime}(events{m_prime} <= ti-w_size*T+w*T);
    if ~isempty(past_events)
        dt = ti - past_events;
        contrib = anomaly_A(m, m_prime) * anomaly_beta(m, m_prime) * exp(-anomaly_beta(m, m_prime) * dt);
        G(m, m_prime) = sum(contrib);
        lambda_curt = lambda_curt + G(m, m_prime);
    end
end
lambda_curt = max(0,lambda_curt);
Lambda(m,ti-w_size*T+w*T) = lambda_curt;
lambda_max = max(Lambda(m,range_w_lambda));
Lambda_normalize(m, ti-w_size*T+w*T) = lambda_curt/max(eps, max(Lambda(m,:)));
end

function [lambda_candidate, G, Lambda, Lambda_normalize] = ...
    candidateIntensity(m, tj, interval_Y, T, w_size, w, events, Par, ...
    anomaly_mu, anomaly_A, anomaly_beta, G, Lambda, Lambda_normalize)
lambda_candidate = anomaly_mu(m);
for m_prime = Par{m}
    lambda_candidate = lambda_candidate + G(m,m_prime) * exp(-anomaly_beta(m, m_prime) * interval_Y);
end
% Add contributions from newly available parent/self anomalies.
for m_prime = Par{m}
    add_events = events{m_prime}(events{m_prime}<=tj-w_size*T+w*T & events{m_prime}>tj-w_size*T+w*T-interval_Y);
    if ~isempty(add_events)
        dt = tj-w_size*T+w*T - add_events;
        contrib = anomaly_A(m, m_prime)*anomaly_beta(m, m_prime)*exp(-anomaly_beta(m, m_prime).*dt);
        G(m, m_prime) = G(m, m_prime)+ sum(contrib);
        lambda_candidate = lambda_candidate + sum(contrib);
    end
end
Lambda(m,tj-w_size*T+w*T) = lambda_candidate;
Lambda_normalize(m, tj-w_size*T+w*T) = Lambda(m,tj-w_size*T+w*T)/max(eps,max(Lambda(m, :)));
end

function [lambda_candidate, G, Lambda, Lambda_normalize] = ...
    selfExcitation(m, tj, T, w_size, w, anomaly_A, anomaly_beta, ...
    lambda_candidate, G, Lambda, Lambda_normalize)
new_contrib = anomaly_A(m,m)*anomaly_beta(m,m);
G(m,m) = G(m,m) + new_contrib;
lambda_candidate = lambda_candidate + new_contrib;

Lambda(m,tj-w_size*T+w*T) = lambda_candidate;
Lambda_normalize(m, tj-w_size*T+w*T) = Lambda(m,tj-w_size*T+w*T)/max(eps,max(Lambda(m, :)));
end

function [Lambda, Lambda_normalize] = historyIntensity(M, time_range, ...
    normalization_range, events, Par, anomaly_mu, anomaly_A, anomaly_beta, ...
    Lambda, Lambda_normalize)
for i = 1:M
    for j = time_range
        lambda_i_j = anomaly_mu(i);
        for m_prime = Par{i}
            past_events = events{m_prime}(events{m_prime}<=j);
            if ~isempty(past_events)
                dt = j-past_events;
                contrib = anomaly_A(i, m_prime) * anomaly_beta(i, m_prime) * exp(-anomaly_beta(i, m_prime)*dt);
                lambda_i_j = lambda_i_j + sum(contrib);
            end
        end
        Lambda(i,j) = lambda_i_j;
    end
    if isempty(normalization_range)
        Lambda_normalize(i,time_range) = Lambda(i,time_range)./max(Lambda(i,:));
    else
        Lambda_normalize(i,time_range) = Lambda(i,time_range)./max(Lambda(i,normalization_range));
    end
end
end
