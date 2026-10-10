function [anomaly_mu, anomaly_A, anomaly_beta, S_mu, S_A, S_beta, events, Par] = ...
    Anomaly_Sampler_Training(Omega_Anomalies, total_T, M, max_iter, epsilon, prior_stru)
% ANOMALY_SAMPLER_TRAINING Initialize the SCS-constrained anomaly model.
%   Anomaly Sampler: offline parameter learning (Section 4.3).
%   Omega_Anomalies contains event indicators over total_T time steps.
%   prior_stru specifies permitted parent-to-child dependencies; diagonal
%   entries additionally permit self-excitation. EM returns background rates,
%   excitation/decay parameters, sufficient statistics, event times, and
%   parent sets Par (including the metric itself).

% Initialize parameters:
anomaly_mu = rand(M, 1); % Small initial background rate
anomaly_A = rand(M, M); % Initial influence coefficients
anomaly_beta = rand(M, M); % Initial decay rates
anomaly_A = anomaly_A.*(prior_stru + eye(M,M));  %
anomaly_beta = anomaly_beta.*(prior_stru + eye(M,M));
gamma = 1e-15; %
alpha = 1.5;

% Permitted parents from the SCS, including self-excitation.
Par = cell(M, 1);
events = cell(M,1);
for m = 1:M
    Par{m} = find(anomaly_A(m,:)~=0);
    %         Par{m} = m;
    events{m} = find(Omega_Anomalies(m, 1:total_T)~=0);
end

% Precompute number of events per metric
n = cellfun(@length, events);

S_mu = [];
S_A = [];
S_beta = [];

for iter = 1:max_iter
    % E-step: accumulate background and parent/self event responsibilities.
    S_mu = zeros(M, 1);
    S_A = zeros(M, M);
    S_beta = zeros(M, M);

    for m = 1:M
        for i = 1:length(events{m})
            ti = events{m}(i);
            lambda = anomaly_mu(m);
            contrib_par_and_itself = cell(M,1);

            % Contribution from parents (and itself, Par{m} contain m)
            for m_prime = Par{m}
                past_events = events{m_prime}(events{m_prime} < ti);
                if ~isempty(past_events)
                    dt = ti - past_events;
                    contrib = anomaly_A(m, m_prime) * anomaly_beta(m, m_prime) * exp(-anomaly_beta(m, m_prime) * dt);
                    if m_prime == m
                        contrib = alpha * contrib;
                    end
                    contrib_par_and_itself{m_prime} = contrib;
                    lambda = lambda + sum(contrib);
                end
            end

            % Compute p_ii and p_ij
            p_ii = anomaly_mu(m) / max(lambda,eps);
            S_mu(m) = S_mu(m) + p_ii;

            for m_prime = Par{m}
                past_events = events{m_prime}(events{m_prime} < ti);
                if ~isempty(past_events)
                    dt = ti - past_events;
                    if lambda > eps
                        p_ij_vector = contrib_par_and_itself{m_prime} / lambda;
                    else
                        p_ij_vector = zeros(size(contrib_par_and_itself{m_prime}));
                    end
                    if m_prime == m
                        p_ij_vector = p_ij_vector / alpha;
                    end
                    S_A(m, m_prime) = S_A(m, m_prime) + sum(p_ij_vector);
                    S_beta(m, m_prime) = S_beta(m, m_prime) + sum(p_ij_vector .* dt);
                end
            end
        end
    end


    % M-step: update background, excitation, and decay parameters.
    mu_new = S_mu / total_T;
    A_new = zeros(M, M);
    beta_new = zeros(M, M);

    for m = 1:M
        for m_prime = Par{m}
            if m_prime == m %正则化A_new
                reg_term = gamma / max(A_new(m, m), eps);
                A_new(m, m_prime) = (S_A(m, m_prime)+reg_term) / max(n(m_prime),1);
            else
                A_new(m, m_prime) = S_A(m, m_prime) / max(n(m_prime),1);
            end
            beta_new(m, m_prime) = S_A(m, m_prime) / (S_beta(m, m_prime)+eps);
        end
    end

    % Check convergence
    if max(abs(mu_new - anomaly_mu)) < epsilon && ...
            max(abs(A_new(:) - anomaly_A(:))) < epsilon && ...
            max(abs(beta_new(:) - anomaly_beta(:))) < epsilon
%         iter
        break;
    end

    anomaly_mu = mu_new;
    anomaly_A = A_new;
    anomaly_beta = beta_new;
end
end
