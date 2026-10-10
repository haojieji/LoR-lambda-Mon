function [anomaly_mu, anomaly_A, anomaly_beta, S_mu, S_A, S_beta, events, Par] = ...
    Anomaly_Sampler_Training(Omega_Anomalies, total_T, M, max_iter, epsilon, prior_stru)
% ANOMALY_SAMPLER_TRAINING Initialize the SCS-constrained anomaly model.
%   Anomaly Sampler: offline parameter learning (Section 4.3).
%
%   [anomaly_mu, anomaly_A, anomaly_beta, S_mu, S_A, S_beta, events, Par] = ...
%       Anomaly_Sampler_Training(Omega_Anomalies, total_T, M, max_iter, ...
%       epsilon, prior_stru)
%
%   Omega_Anomalies is an M-by-time_count mask; its first total_T columns
%   supply original-time events. prior_stru is an M-by-M dependency mask
%   (target metric by parent); the identity adds self-excitation. max_iter
%   and epsilon are the iteration cap and absolute convergence tolerance.
%   Inputs are read-only; all learned state is returned explicitly.
%
%   anomaly_mu/S_mu are M-by-1 background rates/responsibility totals.
%   anomaly_A/anomaly_beta and S_A/S_beta are M-by-M excitation strengths,
%   decay rates, parent-event responsibility totals, and lag-weighted totals.
%   events/Par are M-by-1 cells of original event times/allowed parent indices.
%   S_A is the same excitation statistic consumed by Model_Updater.

% Initialize parameters:
anomaly_mu = rand(M, 1); % Initial background rates
anomaly_A = rand(M, M); % Initial influence coefficients
anomaly_beta = rand(M, M); % Initial decay rates
anomaly_A = anomaly_A.*(prior_stru + eye(M,M));
anomaly_beta = anomaly_beta.*(prior_stru + eye(M,M));
% gamma controls the diagonal excitation regularizer in the M-step.
gamma = 1e-15;
% alpha boosts self-excitation in the event intensity; its responsibility
% is divided by alpha before it enters S_A and S_beta below.
alpha = 1.5;

% Permitted parents from the SCS, including self-excitation.
Par = cell(M, 1);
events = cell(M,1);
for metric_idx = 1:M
    Par{metric_idx} = find(anomaly_A(metric_idx,:)~=0);
    events{metric_idx} = find(Omega_Anomalies(metric_idx, 1:total_T)~=0);
end

% Precompute number of events per metric
n = cellfun(@length, events);

S_mu = [];
S_A = [];
S_beta = [];

for iter = 1:max_iter
    % E-step: recompute sufficient statistics from all training events.
    S_mu = zeros(M, 1);
    S_A = zeros(M, M);
    S_beta = zeros(M, M);

    for metric_idx = 1:M
        for event_idx = 1:length(events{metric_idx})
            original_event_time = events{metric_idx}(event_idx);
            lambda = anomaly_mu(metric_idx);
            parent_event_contributions = cell(M,1);

            % Intensity: sum allowed parent/self contributions from strictly
            % earlier events, retaining each contribution for responsibilities.
            for parent_metric_idx = Par{metric_idx}
                past_events = events{parent_metric_idx}(events{parent_metric_idx} < ...
                    original_event_time);
                if ~isempty(past_events)
                    dt = original_event_time - past_events;
                    contrib = anomaly_A(metric_idx, parent_metric_idx) * ...
                        anomaly_beta(metric_idx, parent_metric_idx) * ...
                        exp(-anomaly_beta(metric_idx, parent_metric_idx) * dt);
                    if parent_metric_idx == metric_idx
                        contrib = alpha * contrib;
                    end
                    parent_event_contributions{parent_metric_idx} = contrib;
                    lambda = lambda + sum(contrib);
                end
            end

            % Responsibilities: p_ii assigns this event to the background;
            % p_ij_vector assigns it to individual earlier parent/self events.
            p_ii = anomaly_mu(metric_idx) / max(lambda,eps);
            S_mu(metric_idx) = S_mu(metric_idx) + p_ii;

            for parent_metric_idx = Par{metric_idx}
                past_events = events{parent_metric_idx}(events{parent_metric_idx} < ...
                    original_event_time);
                if ~isempty(past_events)
                    dt = original_event_time - past_events;
                    if lambda > eps
                        p_ij_vector = parent_event_contributions{parent_metric_idx} / lambda;
                    else
                        p_ij_vector = zeros(size(parent_event_contributions{parent_metric_idx}));
                    end
                    if parent_metric_idx == metric_idx
                        p_ij_vector = p_ij_vector / alpha;
                    end
                    S_A(metric_idx, parent_metric_idx) = S_A(metric_idx, parent_metric_idx) + ...
                        sum(p_ij_vector);
                    S_beta(metric_idx, parent_metric_idx) = ...
                        S_beta(metric_idx, parent_metric_idx) + sum(p_ij_vector .* dt);
                end
            end
        end
    end

    % M-step: update background, excitation, and decay parameters.
    mu_new = S_mu / total_T;
    A_new = zeros(M, M);
    beta_new = zeros(M, M);

    for metric_idx = 1:M
        for parent_metric_idx = Par{metric_idx}
            if parent_metric_idx == metric_idx
                % Preserve the existing regularizer denominator: A_new was
                % initialized to zero at the start of this M-step.
                reg_term = gamma / max(A_new(metric_idx, metric_idx), eps);
                A_new(metric_idx, parent_metric_idx) = ...
                    (S_A(metric_idx, parent_metric_idx)+reg_term) / max(n(parent_metric_idx),1);
            else
                A_new(metric_idx, parent_metric_idx) = S_A(metric_idx, parent_metric_idx) / ...
                    max(n(parent_metric_idx),1);
            end
            beta_new(metric_idx, parent_metric_idx) = S_A(metric_idx, parent_metric_idx) / ...
                (S_beta(metric_idx, parent_metric_idx)+eps);
        end
    end

    % Preserve early-exit order: on convergence, statistics reflect this
    % E-step while returned parameters remain at the preceding iterate.
    if max(abs(mu_new - anomaly_mu)) < epsilon && ...
            max(abs(A_new(:) - anomaly_A(:))) < epsilon && ...
            max(abs(beta_new(:) - anomaly_beta(:))) < epsilon
        break;
    end

    anomaly_mu = mu_new;
    anomaly_A = A_new;
    anomaly_beta = beta_new;
end
end
