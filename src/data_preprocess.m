% normalize for each metric
%  x = (x-min)/(max-min)
% input: is a matrix time × metric
X=[];
% remove all 0，NaN
columnNames = columnNames(1, 2:end-2); %remove timestam,label_1,label_2
columnIDX=[];
for i =1:size(dataMatrix,2)
    if dataMatrix(:,i)==0
        continue
    end
    if sum(isnan(dataMatrix(:,i))) > 0
        continue
    end
    if length(find(dataMatrix(:,i)==0)) > (size(dataMatrix,1)/2)
        continue
    end
    X = [X dataMatrix(:,i)];
    columnIDX = [columnIDX i];
end

% label anomalies by Cauchy Distribution
X = X(1:11600,:)';
% Labels_anomalies before normalize
SPIKE_LIMIT=0.92;
DIP_LIMIT = 0.08;
Omega_Cauchy_large = zeros(size(X));
Omega_Cauchy_small = zeros(size(X));
Cauchy_Trans = @(x, m) (x >= m) .* x + (x < m) .* ( (2*m/pi) * tan( (pi*(x - m))/(2*m) ) + m );
[~, Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_MEDIANs, Cauchy_MADs, Cauchy_thresh_SPIKE, Cauchy_thresh_DIP] = subfunc_robust_AnomalyDetect_Cauchy_w(X, SPIKE_LIMIT, DIP_LIMIT, Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_Trans);
Labels_anomalies_X = double(Omega_Cauchy_large | Omega_Cauchy_small); 

X_min=zeros(1,size(X,1));
X_max_min=zeros(1,size(X,1));
X_max = zeros(1,size(X,1));
for i=1:size(X,1)
    X_min(1,i)=min(X(i,:));
    X_max(1,i)=max(X(i,:));
    X_max_min(1,i)=max(X(i,:))-min(X(i,:));
    if X_max_min(1,i)>eps
        X(i,:)=(X(i,:)-X_min(1,i))/X_max_min(1,i);
    elseif X_max(1,i)>0
        X(i,:)=X(i,:)/X_max(1,i);
    end
end

% creat input Matrix by a parameter T(cycle length)
% T: cycle length; W: window size
% performing only self-embedding transform for the first W slices
T=100;
w=23;
index=1;
X_e=[];
for i=1:(T*w-T+1)
    X_e(:, (index-1)*T+1:index*T) = X(:,i:i+T-1);
    index = index+1;
end
w_size=i;
for i=T*w+1:T:size(X,2)
    X_e(:, (index-1)*T+1:index*T) = X(:, i:i+T-1);
    index=index+1;
end