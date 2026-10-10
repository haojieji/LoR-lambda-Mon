function [mu_updated, A_updated, beta_updated, S_mu, S_A, S_beta] = ...
    Model_Updater(mu, A, beta, events, new_events, w, T, M, max_iter, epsilon, S_mu_init, ...
    S_A_init, S_beta_init, Par, W_idx)
% MODEL_UPDATER Incorporate newly sampled anomaly events.
%   Model Updater (Section 4.6).
%
%   [mu_updated, A_updated, beta_updated, S_mu, S_A, S_beta] = ...
%       Model_Updater(mu, A, beta, events, new_events, w, T, M, max_iter, ...
%       epsilon, S_mu_init, S_A_init, S_beta_init, Par, W_idx)
%
%   mu/S_mu_init are M-by-1 background rates/responsibility totals; A/beta and
%   S_A_init/S_beta_init are M-by-M excitation strengths, decay rates, parent
%   responsibility totals, and lag-weighted totals (target metric by parent).
%   Empty initial statistics are allocated with these shapes. Returned
%   parameters/statistics have the same shapes; the fifth output S_A preserves
%   the excitation statistic formerly named S_a in this function.
%   events/new_events and Par are M-by-1 cells of original event times and
%   allowed parent/self metric indices. Only new_events contribute additional
%   responsibilities; events provides their earlier parent/self history.
%   Inputs are read-only; accumulated statistics and parameters are returned.
%
%   T is segment length; w is the original window's batch count. W_idx stores
%   enhanced batch indices. The event-count cutoff retains the existing
%   (W_idx(1)-1)*T expression even though events use original coordinates.
%   max_iter/epsilon set the iteration cap/absolute convergence tolerance.

total_T = w*T;

if size(S_mu_init)==0
    S_mu_init = zeros(M, 1);
end
if size(S_A_init)==0
    S_A_init = zeros(M, M);
end
if size(S_beta_init)==0
    S_beta_init = zeros(M, M);
end
% gamma disables the diagonal excitation regularizer for online updates.
gamma = 0;
% alpha boosts self-excitation in the intensity; dividing self-event
% responsibilities by alpha scales back their numerators before accumulation.
alpha = 1.5;

window_start_time = (W_idx(1)-1)*T;
n = cellfun(@(x) sum(x>window_start_time), events);

for iter = 1:max_iter
    % E-step: restart from the supplied statistics on each iteration, then
    % add responsibilities for the new events using the current parameters.
    S_mu = S_mu_init;
    S_A = S_A_init;
    S_beta = S_beta_init;

    for metric_idx = 1:M
        for event_idx = 1:length(new_events{metric_idx})
            original_event_time = new_events{metric_idx}(event_idx);
            lambda = mu(metric_idx);
            parent_event_contributions = cell(M,1);

            % Intensity: sum allowed parent/self contributions from strictly
            % earlier events, retaining each contribution for responsibilities.
            for parent_metric_idx = Par{metric_idx}
                past_events = events{parent_metric_idx}(events{parent_metric_idx} < ...
                    original_event_time);
                if ~isempty(past_events)
                    dt = original_event_time - past_events;
                    contrib = A(metric_idx, parent_metric_idx) * ...
                        beta(metric_idx, parent_metric_idx) * ...
                        exp(-beta(metric_idx, parent_metric_idx) * dt);
                    if parent_metric_idx == metric_idx
                        contrib = alpha * contrib;
                    end
                    parent_event_contributions{parent_metric_idx} = contrib;
                    lambda = lambda + sum(contrib);
                end
            end

            % Responsibilities: p_ii assigns this event to the background;
            % p_ij_vector assigns it to individual earlier parent/self events.
            p_ii = mu(metric_idx) / max(lambda,eps);
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

    % M-step: update parameter rows with new events; preserve other rows.
    mu_updated = S_mu / total_T;
    A_updated = A;
    beta_updated = beta;

    for metric_idx = 1:M
        if isempty(new_events{metric_idx})
            mu_updated(metric_idx) = mu(metric_idx);
            A_updated(metric_idx,:) = A(metric_idx,:);
            beta_updated(metric_idx,:) = beta(metric_idx,:);
        else
            for parent_metric_idx = Par{metric_idx}
                if parent_metric_idx == metric_idx
                    reg_term = gamma / max(A_updated(metric_idx, metric_idx), eps);
                    A_updated(metric_idx, parent_metric_idx) = ...
                        (S_A(metric_idx, parent_metric_idx)+reg_term) / max(n(parent_metric_idx),1);
                else
                    A_updated(metric_idx, parent_metric_idx) = ...
                        S_A(metric_idx, parent_metric_idx) / max(n(parent_metric_idx),1);
                end
                beta_updated(metric_idx, parent_metric_idx) = ...
                    S_A(metric_idx, parent_metric_idx) / (S_beta(metric_idx, parent_metric_idx)+eps);
            end
        end
    end

    % Check convergence
    if max(abs(mu_updated - mu)) < epsilon && ...
            max(abs(A_updated(:) - A(:))) < epsilon && ...
            max(abs(beta_updated(:) - beta(:))) < epsilon
        disp(["update iterations:", iter])
        break;
    end

    mu = mu_updated;
    A = A_updated;
    beta = beta_updated;
end
end
