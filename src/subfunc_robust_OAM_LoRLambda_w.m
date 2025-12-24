% Lambda-sampling：sample metric by lambda_m(t)
% Inputs:
%   m:
%   num_sample: 
%   T: batc
%   param
%   X_t_m: 
%   X: 
%   Omega: 
%   Omega_Anomalies: 
%   events: cell
%   new_events: 
%   Cauchy_MEDIANs, Cauchy_MADs: 
%   W_idx: 
%   w:
% Outputs:
%   Omega_t_m: low-rank samples
%   Omega_t_m_Anomalies: lambda samples
%   Omega
%   Omega_Anomalies: 
%   events
%   new_events:  for m
function [Omega_t_m, Omega_t_m_r,Omega_t_m_L, Omega_t_m_Anomalies, Omega_Anomalies, events, new_events, Lambda,Lambda_normalize] = subfunc_robust_OAM_LoRLambda_w(m, num_sample_f, T, param, X_t_m,X, Omega, Omega_Anomalies, events,new_events, Par, Cauchy_MEDIANs,Cauchy_MADs,Cauchy_Trans, W_idx, w_size,w, OAM_mu,OAM_A,OAM_beta, Lambda,Lambda_normalize)
% 1. low-rank sampling
Omega_t_m = Get_Array_equalInterval(T, num_sample_f)';
Omega_t_m_r = Omega_t_m;
Omega_t_m_L = zeros(size(Omega_t_m));
interval = ceil(T/num_sample_f);

% 2. lambda sampling
Omega_t_m_Anomalies = zeros(size(Omega_t_m));
idx_Omega_t_m = find(Omega_t_m==1);
%range_w = ((W_idx(1)-1)*T+1 : W_idx(w)*T);
range_w = (1 : W_idx(w_size)*T);
W_end = W_idx(w_size)-w_size+w;
range_w_lambda = ((W_end-w)*T+1 : W_end*T);

% lambda parameters
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

    % 3.Lambda sampling for (i+1, i+interval)
    % 3.1 lambda_current, lambda_max, Y_m
    lambda_curt = OAM_mu(m);
    for m_prime = Par{m}
        past_events = events{m_prime}(events{m_prime} <= ti-w_size*T+w*T);
        if ~isempty(past_events)
            dt = ti - past_events;
            contrib = OAM_A(m, m_prime) * OAM_beta(m, m_prime) * exp(-OAM_beta(m, m_prime) * dt);
            G(m, m_prime) = sum(contrib);
            lambda_curt = lambda_curt + G(m, m_prime);
        end
    end
    lambda_curt = max(0,lambda_curt);
    Lambda(m,ti-w_size*T+w*T) = lambda_curt;
    lambda_max = max(Lambda(m,range_w_lambda));
    Lambda_normalize(m, ti-w_size*T+w*T) = lambda_curt/max(eps, max(Lambda(m,:)));

    j = i;
    tj = W_idx(w_size-1)*T+j;
    while j <= min(i+interval,T)
        % 3.2 i+Y_m
        lambda_max = max(lambda_max, lambda_curt);
        interval_Y = max( floor(1/max(lambda_max,eps)), 1 );
        
        j = j + interval_Y;
        tj = tj + interval_Y;
        if j > min(i+interval,T)
            break;
        end
        % lambda_candidate
        lambda_candidate = OAM_mu(m);
        for m_prime = Par{m}
            lambda_candidate = lambda_candidate + G(m,m_prime) * exp(-OAM_beta(m, m_prime) * interval_Y);
        end
        % 3.3 update lambda: excited from parents' new anomalies
        for m_prime = Par{m}
            add_events = events{m_prime}(events{m_prime}<=tj-w_size*T+w*T & events{m_prime}>tj-w_size*T+w*T-interval_Y);
            if ~isempty(add_events)
                dt = tj-w_size*T+w*T - add_events;
                contrib = OAM_A(m, m_prime)*OAM_beta(m, m_prime)*exp(-OAM_beta(m, m_prime).*dt);
                G(m, m_prime) = G(m, m_prime)+ sum(contrib);
                lambda_candidate = lambda_candidate + sum(contrib);
            end
        end
        Lambda(m,tj-w_size*T+w*T) = lambda_candidate;
        Lambda_normalize(m, tj-w_size*T+w*T) = Lambda(m,tj-w_size*T+w*T)/max(eps,max(Lambda(m, :)));
        % 3.4  Sampling Probability (normalized probability vs original probability)
        if lambda_candidate>0 && (randi([0,9])*0.1) < lambda_candidate/max(Lambda(m,:))
            Omega_t_m(j) = 1;
            Omega_t_m_L(j) = 1;

            % 3.5 update lambda
            x = Cauchy_Trans( X_t_m(j), Cauchy_MEDIANs(m) );
            cdf_value = (1/pi) * atan( (x - Cauchy_MEDIANs(m)) / (Cauchy_MADs(m)+eps) ) + 0.5;
            if cdf_value >= param.SPIKE_LIMIT || cdf_value <= param.DIP_LIMIT
                events{m}(end+1) = tj-w_size*T+w*T;
                new_events{m}(end+1) = tj-w_size*T+w*T;
                Omega_Anomalies(m, tj-w_size*T+w*T) = 1;
                Omega_t_m_Anomalies(j) = 1;
                Omega_t_m(j) = 0; 
                Omega_t_m_L(j) = 0;

                % excited from its past anomalies
                new_contrib = OAM_A(m,m)*OAM_beta(m,m);
                G(m,m) = G(m,m) + new_contrib;
                lambda_candidate = lambda_candidate + new_contrib;

                Lambda(m,tj-w_size*T+w*T) = lambda_candidate;
                Lambda_normalize(m, tj-w_size*T+w*T) = Lambda(m,tj-w_size*T+w*T)/max(eps,max(Lambda(m, :)));
            end
        end
        lambda_curt = lambda_candidate;
    end
end

% avoid Omega_t_m is full 0
if isempty(find(Omega_t_m==1))
    Omega_t_m(idx_Omega_t_m(1)) = 1;
end