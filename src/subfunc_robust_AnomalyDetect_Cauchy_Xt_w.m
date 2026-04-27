
function [W, U_W_union, Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_MEDIANs, Cauchy_MADs, events,new_events,Omega_Cauchy] = subfunc_robust_AnomalyDetect_Cauchy_Xt_w(W, U_W_union, U_W_union_idx, beta, SPIKE_LIMIT, DIP_LIMIT, Cauchy_MEDIANs, Cauchy_MADs, Cauchy_Trans, T,t,w_size,w, events,new_events, Omega,Omega_Anomalies, X, W_idx)
M = size(W,1);

% 1.
Cauchy_Trans_betaXt = zeros(M, beta*T);
Cauchy_CDF = zeros(M, beta*T);
Omega_Cauchy_large = zeros(M, beta*T);
Omega_Cauchy_small = zeros(M, beta*T);
%range_w = ((W_idx(1)-1)*T+1 : W_idx(w)*T);
range_w = (1 : W_idx(end)*T);

for j = 1:M

    X_range_w = X(j, range_w);
    
    Cauchy_MEDIANs(j) = median(X_range_w);
    Cauchy_MADs(j) = median(abs(X_range_w - Cauchy_MEDIANs(j)));
    
    Cauchy_Trans_betaXt = Cauchy_Trans( W(j, (w_size-beta)*T+1:w_size*T), Cauchy_MEDIANs(j) );

    Cauchy_CDF(j,:) = (1/pi) * atan( (Cauchy_Trans_betaXt-Cauchy_MEDIANs(j))/(Cauchy_MADs(j)+eps) ) + 0.5;

    Omega_Cauchy_large(j, Cauchy_CDF(j,:)>SPIKE_LIMIT) = 1; % spike
    Omega_Cauchy_small(j, Cauchy_CDF(j,:)<DIP_LIMIT) = 1; % dip

end

% 3.
Omega_Cauchy = double(Omega_Cauchy_large | Omega_Cauchy_small);
for j=1:M
    if sum(Omega_Cauchy(j,:)) == beta*T
        if sum(Omega_Cauchy_large(j,:)) < sum(Omega_Cauchy_small(j,:))
            Omega_Cauchy(j,:) = Omega_Cauchy_large(j,:);
        else
            Omega_Cauchy(j,:) = Omega_Cauchy_small(j,:);
        end
    end
end

% 4. GroundTruth = W(Omega_Cauchy==0) + Anomalies(Omega_Cauchy==1);
for j=1:M
    idx_anomalies = find( Omega_Cauchy(j, :)==1 );
    U_W_j = U_W_union(:,:,j);
    temp = length(find((U_W_union_idx(1,:)~=0)));
    idx_anomalies_U_W_union = (temp-beta)*T + idx_anomalies;
    U_W_j(idx_anomalies_U_W_union) = 0;
    if ~isempty(idx_anomalies_U_W_union)
        idx_nomalies = find( Omega_Cauchy(j, :)==0 );
        idx_nomalies_U_W_union = (temp-beta)*T + idx_nomalies;
        if length(idx_nomalies)>=2 
            val = interp1(idx_nomalies_U_W_union, U_W_j(idx_nomalies_U_W_union), idx_anomalies_U_W_union,'linear','extrap');
            W(j, (w_size-beta)*T+idx_anomalies) = val;
            U_W_j(idx_anomalies_U_W_union) = val;
            U_W_union(:,:,j) = U_W_j;
        else
            Omega_Cauchy(j,:) = ones(1,beta*T);
        end
    end



    idx_anomalies = find( Omega_Cauchy(j, :)==1 );
    idx_anomalies_X = (t-w_size+w-beta)*T + idx_anomalies;
    events{j} = [events{j} idx_anomalies_X];
    new_events{j} = [new_events{j} idx_anomalies_X];
end
