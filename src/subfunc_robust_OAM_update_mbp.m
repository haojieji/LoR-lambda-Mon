function [mu_updated, A_updated, beta_updated, S_mu,S_a,S_beta] = subfunc_robust_OAM_update_mbp(mu, A, beta, events, new_events, w,T, M, max_iter, epsilon, S_mu_init,S_a_init,S_beta_init, Par, W_idx)

total_T = w*T;

if size(S_mu_init)==0
    S_mu_init = zeros(M, 1);
end
if size(S_a_init)==0
    S_a_init = zeros(M, M);
end
if size(S_beta_init)==0
    S_beta_init = zeros(M, M);
end
gamma = 0; % 
alpha = 1.5;

%n = cellfun(@length, events);
range_W = (W_idx(1)-1)*T;
n = cellfun(@(x) sum(x>range_W), events);

for iter = 1:max_iter
    iter
    % Compute statistics for new events
    S_mu = S_mu_init;
    S_a = S_a_init;
    S_beta = S_beta_init;

    for m = 1:M
        for i = 1:length(new_events{m})
            ti = new_events{m}(i);
            lambda = mu(m);
            contrib_par_and_itself = cell(M,1);

            % Contribution from all parents
            for m_prime = Par{m}
                past_events = events{m_prime}(events{m_prime} < ti);
                if ~isempty(past_events)
                    dt = ti - past_events;
                    contrib = A(m, m_prime) * beta(m, m_prime) * exp(-beta(m, m_prime) * dt);
                    if m_prime == m
                        contrib = alpha * contrib;
                    end
                    contrib_par_and_itself{m_prime} = contrib;
                    lambda = lambda + sum(contrib);
                end
            end

            % Compute p_ii and p_ij
            p_ii = mu(m) / max(lambda,eps);
            S_mu(m) = S_mu(m) + p_ii;

            for m_prime = Par{m}
                past_events = events{m_prime}(events{m_prime} < ti);
                if ~isempty(past_events)
                    dt = ti - past_events;
                    if lambda > eps
                        p_ij = contrib_par_and_itself{m_prime} / lambda;
                    else
                        p_ij = zeros(size(contrib_par_and_itself{m_prime}));
                    end
                    if m_prime == m
                        p_ij = p_ij / alpha;
                    end
                    S_a(m, m_prime) = S_a(m, m_prime) + sum(p_ij);
                    S_beta(m, m_prime) = S_beta(m, m_prime) + sum(p_ij .* dt);
                end
            end
        end
    end

    % Update parameters
    mu_updated = S_mu / total_T;
    A_updated = A;
    beta_updated = beta;

    for m = 1:M
        if isempty(new_events{m})
            mu_updated(m) = mu(m);
            A_updated(m,:) = A(m,:);
            beta_updated(m,:) = beta(m,:);
        else
            for m_prime = Par{m}
                if m_prime == m %A_new
                    reg_term = gamma / max(A_updated(m, m), eps);
                    A_updated(m, m_prime) = (S_a(m, m_prime)+reg_term) / max(n(m_prime),1);
                else
                    A_updated(m, m_prime) = S_a(m, m_prime) / max(n(m_prime),1);
                end
                beta_updated(m, m_prime) = S_a(m, m_prime) / (S_beta(m, m_prime)+eps);
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