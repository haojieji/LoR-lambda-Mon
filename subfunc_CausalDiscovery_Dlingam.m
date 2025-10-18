
%
% Input:  IDX_i,  W
% Output：： r_Stru_i,  r_B_i,  r_Ord
function [r_Stru_i, r_B_i, r_Ord] = subfunc_CausalDiscovery_Dlingam(IDX_i, W)

    W_i = W(IDX_i, :);
    [M_i, n] = size(W_i);
    Y = W_i; %
    Ord = []; % 
    K_Ord = 1:M_i; % 
    % step1. 
    Y = Y - mean(Y, 2)*ones(1,n);

    r_Stru_i = ones(M_i,M_i);

    % step2. 
    i=1;
    while length(Ord) < M_i-1
        candidates = setdiff(K_Ord, Ord);  % 
        % step2.1 Residual Matrix Res(M_i, size(W,2), M_i)
        Res = computeR( Y, candidates, K_Ord, r_Stru_i);
        i = i+1;
        % step2.2 Most Independent metric k with its Res(:,:,k)
        if length(candidates) ==1
            index = candidates;
        else
            index = findindex( Y, Res, candidates, K_Ord);
        end
        % step2.3 Append k to Ord
        Ord = [Ord index];

        
        K_Ord(K_Ord == index) = [];

        % step2.4 
        r_Stru_i = rmSuprious( Res, K_Ord, index, r_Stru_i );

        % step2.4 Update Y to Remove the effect of k on remain mateics
        Y = Res(:,:,index);
    end
    Ord = [Ord K_Ord];
    r_Ord = IDX_i(Ord);

    r_Stru_Ord = r_Stru_i(Ord, Ord);
    r_Stru_Ord = tril(r_Stru_Ord, -1);
    r_Stru_i(Ord, Ord) = r_Stru_Ord;

    % step3. 

    r_B_i = ols3(W_i, Ord, r_Stru_i); % input r_Stru_i, output r_B_i
    r_Stru_i = r_B_i ~= 0;
end

%
function [J] = my_call_contrast(x)
% Author: Yasuhiro Sogawa
% Modified by SS (27 Sep 2010)
% my_call_contrast - set parameters of KernelICA.
% and call a contrast function employed in KernelICA.
% The details of the parameters are shown in section 4.5,
% "Kernel Independent Component Analysis" (F. R. Bachand and M.I.Jordan).

[m,N]=size(x);

% set the parameters
contrast='kgv';
% contrast='kcca';
if N < 1000
    sigma=1;
    kappa=2e-2;
else % Added by SS (24 Sep 2010)
    sigma = 1/2;
    kappa = 2e-3;
end

kernel='gaussian';

mc=m;
kparam.kappas=kappa*ones(1,mc);
kparam.etas=kappa*1e-2*ones(1,mc);
kparam.neigs=N*ones(1,mc);
kparam.nchols=N*ones(1,mc);
kparam.kernel=kernel;
kparam.sigmas=sigma*ones(1,mc);

% Commented out by SS (24 Sep 2010)
% % scales data
% covmatrix=x*x'/N;
% sqrcovmatrix=sqrtm(covmatrix);
% invsqrcovmatrix=inv(sqrcovmatrix);
% x=invsqrcovmatrix*x;

% perform contrast function
J = contrast_ica(contrast,x,kparam);

end

function R = computeR( X, candidates, U_K, M )

    [p,n] = size( X );
    R = zeros(p,n,p);
    Cov = cov(X');
    
    for j = candidates
        if Cov(j,j)~=0
            for i = setdiff(U_K, j)
                % skip residue calculation by using M
                R(i,:,j) = X(i,:) - Cov(i,j)/Cov(j,j)*X(j,:);  % 无条件计算残差
            end
        end
    end

end

function index = findindex( X, R, candidates, U_K )

    p = size(X,1);
    
    % calculate T
    T_MI = NaN(1,p);
    
    minT = -1; %% SS (24 Sep 2010)
    
    for j = candidates
        
        if minT == -1 %% SS (24 Sep 2010) Input: minT, X, R, j
            T_MI(j) = 0;
            for i = setdiff(U_K, j)
                if all(R(i,:,j) == 0) %
                    R(i,:,j) = R(i,:,j) + 1e-10 * randn(1, size(R,2));
                end
                J = my_call_contrast([R(i,:,j); X(j,:)]); %using kernel based independence measure
                if isnan(J)
                    warning('NaN detected, using fallback value');
                    J = 0;  % 
                end
                T_MI(j) = T_MI(j) + J;
            end
            minT = T_MI(j);
        else
            T_MI(j) = 0;
            for i = setdiff(U_K, j)
                if all(R(i,:,j) == 0) % 
                    R(i,:,j) = R(i,:,j) + 1e-10 * randn(1, size(R,2));
                end
                J = my_call_contrast([R(i,:,j); X(j,:)]); %using kernel based independence measure
                if isnan(J)
                    warning('NaN detected, using fallback value');
                    J = 0;  % 
                end
                T_MI(j) = T_MI(j) + J;
                if T_MI(j) > minT
                    T_MI(j) = Inf;
                    break;
                end
            end
            minT = min( [ T_MI(j), minT ] );
        end %% SS (24 Sep 2010) Output: minT, T(j)

        T_MI(j)
       
    end
    % find argmin T
    [minval, index] = min(T_MI);

end

% 
% input:Res(K_Ord,:,index), r_Stru
% , IND=corr=Res*Res';  ，IND=MI(Res(i,:),Res(j,:))
% r_Stru(i,j)=r_Stru(j,i)=0 if (Res(i,:) \perp Res(j,:) | index)
% output: r_Stru
function r_Stru = rmSuprious( Res, K_Ord, index, r_Stru )
    R = Res(:,:,index);
    for j = 1:length(K_Ord)
        j_ord = K_Ord(j);
        for i = j+1:length(K_Ord)
            i_ord = K_Ord(i);
            if r_Stru(j_ord,i_ord)==1 || r_Stru(i_ord,j_ord)==1
                J = my_call_contrast(R([j_ord i_ord],:)); %using kernel based independence measure  
                %disp(["j_ord:", j_ord, " i_ord:",i_ord, " IND:",J])
                if J < 0.001
                    r_Stru(j_ord, i_ord) = 0;
                    r_Stru(i_ord, j_ord) = 0;
                end
            end
        end
    end
end