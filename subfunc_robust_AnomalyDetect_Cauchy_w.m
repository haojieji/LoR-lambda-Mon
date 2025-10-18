
function [W, Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_MEDIANs, Cauchy_MADs, Cauchy_thresh_SPIKE, Cauchy_thresh_DIP] = subfunc_robust_AnomalyDetect_Cauchy_w(W, SPIKE_LIMIT, DIP_LIMIT, Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_Trans)
M = size(W,1);

% 1.
Cauchy_MEDIANs = median( W' );
Cauchy_MADs = median(abs(W' - Cauchy_MEDIANs));
Cauchy_Trans_W = zeros(size(W));
Cauchy_CDF = zeros(size(W));
Cauchy_thresh_SPIKE = zeros(1,M);
Cauchy_thresh_DIP = zeros(1,M);
for j = 1:M
    Cauchy_Trans_W(j,:) = Cauchy_Trans( W(j,:), Cauchy_MEDIANs(j) );
%     if Cauchy_MADs(j)>0
        Cauchy_CDF(j,:) = (1/pi) * atan( (Cauchy_Trans_W(j,:)-Cauchy_MEDIANs(j))/(Cauchy_MADs(j)+eps) ) + 0.5;

        % 2.
        Omega_Cauchy_large(j, Cauchy_CDF(j,:)>SPIKE_LIMIT) = 1; % spike
        Omega_Cauchy_small(j, Cauchy_CDF(j,:)<DIP_LIMIT) = 1; % dip
%     end
    Cauchy_thresh_SPIKE(j) = tan(pi*(SPIKE_LIMIT-0.5)) * Cauchy_MADs(j) + Cauchy_MEDIANs(j);
    if Cauchy_thresh_SPIKE(j) < Cauchy_MEDIANs(j)
        Cauchy_thresh_SPIKE(j) = atan( (Cauchy_thresh_SPIKE(j) - Cauchy_MEDIANs(j)) * (pi/(2*Cauchy_MEDIANs(j))) ) *(2*Cauchy_MEDIANs(j)/pi) +Cauchy_MEDIANs(j);
    end
    Cauchy_thresh_DIP(j) = tan(pi*(DIP_LIMIT-0.5)) * Cauchy_MADs(j) + Cauchy_MEDIANs(j);
    if Cauchy_thresh_DIP(j) < Cauchy_MEDIANs(j)
        Cauchy_thresh_DIP(j) = atan( (Cauchy_thresh_DIP(j) - Cauchy_MEDIANs(j)) * (pi/(2*Cauchy_MEDIANs(j))) ) *(2*Cauchy_MEDIANs(j)/pi) + Cauchy_MEDIANs(j);
    end
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

    if ~isempty(idx_anomalies)
        idx_nomalies = find( Omega_Cauchy(j, 1:size(W,2))==0 );
        val = interp1(idx_nomalies, W(j,idx_nomalies), idx_anomalies,'linear','extrap');
        W(j, idx_anomalies) = val;
    end
end


