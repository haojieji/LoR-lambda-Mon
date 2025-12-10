

function [r_Stru, r_Ord] = subfunc_SCD_rmSuprious(W)

    [M, n] = size(W);
    Y = W; % 
    Ord = []; % 
    K_Ord = [1:M]; % 
    
    % step1. 
    Y = Y - mean(Y, 2)*ones(1,n);
    r_Stru = ones(M,M); % 

    % step2. 
    while length(Ord) < M-1
        % step2.0 candidates
        candidates = setdiff(K_Ord, Ord);  % 
        % step2.1 Residual Matrix Res(M, size(W,2), M)
        Res = computeR( Y, candidates, K_Ord, r_Stru);
        % step2.2 Most Independent metric k with its Res(:,:,k)
%         if length(candidates) ==1
%             index = candidates;
%         else
            index = findindex( Y, Res, candidates, K_Ord, r_Stru );
%         end
        % step2.3 Append k to Ord
        Ord = [Ord index];
        K_Ord(K_Ord == index) = [];
        
        % step2.4 
        r_Stru = rmSuprious( Res, K_Ord, index, r_Stru );

        % step2.5 Update Y to Remove the effect of k on remain mateics
        Y = Res(:,:,index);
    end
    r_Ord = [Ord K_Ord];
    % step3.  r_Stru
    r_Stru_Ord = r_Stru(r_Ord, r_Ord);
    r_Stru_Ord = tril(r_Stru_Ord, -1);
    r_Stru_Ord
    r_Stru(r_Ord, r_Ord) = r_Stru_Ord;
    r_Stru
end


function [J] = my_call_contrast(x)
% Author: Yasuhiro Sogawa
% Modified by SS (27 Sep 2010)
% my_call_contrast - set parameters of KernelICA.
% and call a contrast function employed in KernelICA.
% The details of the parameters are shown in section 4.5,
% "Kernel Independent Component Analysis" (F. R. Bach and M.I.Jordan).

[m,N]=size(x);

if any(var(x,0,2) < 1e-10)
    J = 0;
    return;
end

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
try
    J = contrast_ica(contrast,x,kparam);
catch
    J = 0; % 异常处理
end

end

function R = computeR( X, candidates, U_K, r_Stru )

    [p,n] = size( X );
    R = zeros(p,n,p);
    Cov = cov(X');
    
    for j = candidates
        for i = setdiff(U_K, j)
            if r_Stru(j,i)==1 && r_Stru(i,j)==1
                R(i,:,j) = X(i,:) - Cov(i,j)/Cov(j,j)*X(j,:);  % 无条件计算残差
            end
        end
    end

end

function index = findindex( X, R, candidates, U_K, r_Stru )

    p = size(X,1);
    
    % calculate T
    T = NaN(1,p);
    
    minT = -1; %% SS (24 Sep 2010)
    for j = candidates

        if minT == -1 %% SS (24 Sep 2010) Input: minT, X, R, j
            
            T(j) = 0;
            for i = setdiff(U_K, j)
                
                if r_Stru(j,i)==1 && r_Stru(i,j)==1
                    J = my_call_contrast([R(i,:,j); X(j,:)]); %using kernel based independence measure
                    if isnan(J)
                        disp('Debug Info:');
                        disp(['Var1: ', num2str(var(R(i,:,j)))]);
                        disp(['Var2: ', num2str(var(X(j,:)))]);
                        disp(['Cov: ', num2str(cov(R(i,:,j),X(j,:)))]);
                        J = 0; 
                    end
                else
                    J = 0;
                end
                
                T(j) = T(j) + J;
            end

            minT = T(j);
        else
            
            T(j) = 0;
            for i = setdiff(U_K, j)

                if r_Stru(j,i)==1 && r_Stru(i,j)==1
                    J = my_call_contrast([R(i,:,j); X(j,:)]); %using kernel based independence measure
                    if isnan(J)
                        disp('Debug Info:');
                        disp(['Var1: ', num2str(var(R(i,:,j)))]);
                        disp(['Var2: ', num2str(var(X(j,:)))]);
                        disp(['Cov: ', num2str(cov(R(i,:,j),X(j,:)))]);
                        J = 0;
                    end
                else
                    J = 0;
                end
                
                T(j) = T(j) + J;
                    
                if T(j) > minT
                    T(j) = Inf;
                    break;
                end
                
            end
            minT = min( [ T(j), minT ] );
        end %% SS (24 Sep 2010) Output: minT, T(j)
    end
    
    % find argmin T
    [minval, index] = min(T);

end

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
%                 disp([j_ord,i_ord,J])
                if J < 2e-4
                    r_Stru(j_ord, i_ord) = 0;
                    r_Stru(i_ord, j_ord) = 0;
                end
            end
        end
    end
end
