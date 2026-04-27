
function [OAM_mu, OAM_A, OAM_beta,S_mu,S_A,S_beta, events, Par] = subfunc_robust_OAM_learn_mbp(Omega_Anomalies, total_T, M, max_iter, epsilon, prior_stru)

% Initialize parameters: 
OAM_mu = rand(M, 1); % Small initial background rate
OAM_A = rand(M, M); % Initial influence coefficients
OAM_beta = rand(M, M); % Initial decay rates
OAM_A = OAM_A.*(prior_stru + eye(M,M));  % 
OAM_beta = OAM_beta.*(prior_stru + eye(M,M));
gamma = 1e-15; % 
alpha = 1.5;

% Parent metrics (all metrics can influence each other)
Par = cell(M, 1);
events = cell(M,1);
for m = 1:M
    Par{m} = find(OAM_A(m,:)~=0);
    %         Par{m} = m;
    events{m} = find(Omega_Anomalies(m, 1:total_T)~=0);
end

% Precompute number of events per metric
n = cellfun(@length, events);

S_mu = [];
S_A = [];
S_beta = [];

for iter = 1:max_iter
    % E-step: Compute statistics
    S_mu = zeros(M, 1);
    S_A = zeros(M, M);
    S_beta = zeros(M, M);

    for m = 1:M
        for i = 1:length(events{m})
            ti = events{m}(i);
            lambda = OAM_mu(m);
            contrib_par_and_itself = cell(M,1);

            % Contribution from parents (and itself, Par{m} contain m)
            for m_prime = Par{m}
                past_events = events{m_prime}(events{m_prime} < ti);
                if ~isempty(past_events)
                    dt = ti - past_events;
                    contrib = OAM_A(m, m_prime) * OAM_beta(m, m_prime) * exp(-OAM_beta(m, m_prime) * dt);
                    if m_prime == m
                        contrib = alpha * contrib;
                    end
                    contrib_par_and_itself{m_prime} = contrib;
                    lambda = lambda + sum(contrib);
                end
            end

            % Compute p_ii and p_ij
            p_ii = OAM_mu(m) / max(lambda,eps);
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


    % M-step: Update parameters
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
    if max(abs(mu_new - OAM_mu)) < epsilon && ...
            max(abs(A_new(:) - OAM_A(:))) < epsilon && ...
            max(abs(beta_new(:) - OAM_beta(:))) < epsilon
        iter
        break;
    end

    OAM_mu = mu_new;
    OAM_A = A_new;
    OAM_beta = beta_new;
end
end
