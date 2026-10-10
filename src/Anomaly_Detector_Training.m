function [W, U_W, Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_MEDIANs, Cauchy_MADs] = ...
    Anomaly_Detector_Training(W, U_W, SPIKE_LIMIT, DIP_LIMIT, Omega_Cauchy_large, ...
    Omega_Cauchy_small, Cauchy_Trans)
% ANOMALY_DETECTOR_TRAINING Separate anomalies from training representations.
%   Anomaly Detector (Section 4.1). W is M-by-N training data, N = T*H;
%   U_W is T-by-H-by-M history; its columns flatten chronologically to W(m,:).
%   SPIKE_LIMIT/DIP_LIMIT are scalar CDF cutoffs. Cauchy_Trans(values,median)
%   is a shape-preserving transform. Input/output spike/dip masks are
%   M-by-at-least-N state arrays: detected entries are set to 1, not cleared.
%   Return interpolated W/U_W, masks in the same order, and 1-by-M medians
%   and median absolute deviations computed from W before interpolation.
%   Mask columns beyond N must be zero. When all entries are flagged, interpolation uses the less frequent type
%   (dip on a tie); the two returned spike/dip masks retain their flags.

M = size(W,1);

% 1. Compute robust statistics and transform each metric.
Cauchy_MEDIANs = median( W' );
Cauchy_MADs = median(abs(W' - Cauchy_MEDIANs));
Cauchy_Trans_W = zeros(size(W));
Cauchy_CDF = zeros(size(W));
for metric_idx = 1:M
    Cauchy_Trans_W(metric_idx,:) = Cauchy_Trans( W(metric_idx,:), Cauchy_MEDIANs(metric_idx) );
    Cauchy_CDF(metric_idx,:) = (1/pi) * atan( (Cauchy_Trans_W(metric_idx,:)-Cauchy_MEDIANs(metric_idx))/(Cauchy_MADs(metric_idx)+eps) ) + 0.5;

    % 2. Mark tail events without clearing existing flags.
    Omega_Cauchy_large(metric_idx, Cauchy_CDF(metric_idx,:)>SPIKE_LIMIT) = 1; % spike
    Omega_Cauchy_small(metric_idx, Cauchy_CDF(metric_idx,:)<DIP_LIMIT) = 1; % dip

end

% 3. Keep one anomaly type if their union covers the entire row.
Omega_Cauchy = double(Omega_Cauchy_large | Omega_Cauchy_small);
for metric_idx=1:M
    if sum(Omega_Cauchy(metric_idx,:)) == size(W,2)
        if sum(Omega_Cauchy_large(metric_idx,:)) < sum(Omega_Cauchy_small(metric_idx,:))
            Omega_Cauchy(metric_idx,:) = Omega_Cauchy_large(metric_idx,:);
        else
            Omega_Cauchy(metric_idx,:) = Omega_Cauchy_small(metric_idx,:);
        end
    end
end
W(Omega_Cauchy==1) = 0;

% 4. Interpolate normal values at anomalous times (linear extrapolation at ends).
for metric_idx=1:M
    anomaly_indices = find( Omega_Cauchy(metric_idx, 1:size(W,2))==1 );
    % Column-major indexing follows the chronological T-sample history columns.
    metric_history = U_W(:,:,metric_idx);
    metric_history(anomaly_indices) = 0;
    if ~isempty(anomaly_indices)
        normal_indices = find( Omega_Cauchy(metric_idx, 1:size(W,2))==0 );
        interpolated_values = interp1(normal_indices, W(metric_idx,normal_indices), anomaly_indices,'linear','extrap');
        W(metric_idx, anomaly_indices) = interpolated_values;
        metric_history(anomaly_indices) = interpolated_values;
        U_W(:,:,metric_idx) = metric_history;
    end
end

