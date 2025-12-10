% 
%----------GroundTruth = W(Omega_Cauchy==0) + Anomalies(Omega_Cauchy==1);
function [W, U_W, Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_MEDIANs, Cauchy_MADs] = subfunc_robust_AnomalyDetect_Cauchy(W, U_W, SPIKE_LIMIT, DIP_LIMIT, Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_Trans)
M = size(W,1);

% 1
Cauchy_MEDIANs = median( W' );
Cauchy_MADs = median(abs(W' - Cauchy_MEDIANs));
Cauchy_Trans_W = zeros(size(W));
Cauchy_CDF = zeros(size(W));
for j = 1:M
    Cauchy_Trans_W(j,:) = Cauchy_Trans( W(j,:), Cauchy_MEDIANs(j) );
%     if Cauchy_MADs(j)>0
        Cauchy_CDF(j,:) = (1/pi) * atan( (Cauchy_Trans_W(j,:)-Cauchy_MEDIANs(j))/(Cauchy_MADs(j)+eps) ) + 0.5;

        % 2.
        Omega_Cauchy_large(j, Cauchy_CDF(j,:)>SPIKE_LIMIT) = 1; % spike
        Omega_Cauchy_small(j, Cauchy_CDF(j,:)<DIP_LIMIT) = 1; % dip
%     end
    
end

% 3.
Omega_Cauchy = double(Omega_Cauchy_large | Omega_Cauchy_small);
for j=1:M
    if sum(Omega_Cauchy(j,:)) == size(W,2)
        if sum(Omega_Cauchy_large(j,:)) < sum(Omega_Cauchy_small(j,:))
            Omega_Cauchy(j,:) = Omega_Cauchy_large(j,:);
        else
            Omega_Cauchy(j,:) = Omega_Cauchy_small(j,:);
        end
    end
end
W(Omega_Cauchy==1) = 0;

% 4. GroundTruth = W(Omega_Cauchy==0) + Anomalies(Omega_Cauchy==1);
for j=1:M
    idx_anomalies = find( Omega_Cauchy(j, 1:size(W,2))==1 );
    U_W_j = U_W(:,:,j);
    U_W_j(idx_anomalies) = 0;
    if ~isempty(idx_anomalies)
        idx_nomalies = find( Omega_Cauchy(j, 1:size(W,2))==0 );
        val = interp1(idx_nomalies, W(j,idx_nomalies), idx_anomalies,'linear','extrap');
        W(j, idx_anomalies) = val;
        U_W_j(idx_anomalies) = val;
        U_W(:,:,j) = U_W_j;
    end
end


