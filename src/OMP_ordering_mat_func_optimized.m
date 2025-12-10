function r_C = OMP_ordering_mat_func_optimized(X, r_Ord, r_Stru, K, thr)

%% 
MEMORY_TOTAL = 0.1 * 10^9; 
[~, N] = size(X);
X = X(:, r_Ord);         
r_Stru = r_Stru(r_Ord, r_Ord); 

%% 
Xn = cnormalize(X);     
S = zeros(N, N);        
Val = zeros(N, N);        
t_vec = zeros(N, 1);      

%% 
parent_indices = cell(N,1);
for iN = 2:N
    parent_indices{iN} = find(r_Stru(iN,1:iN-1)); % 
end

%% 
res = Xn; % 

% 
blockSize = round(MEMORY_TOTAL / (N*8)); % 
blockSize = max(blockSize, 10); % 

for t = 1:K
    active_nodes = find(t_vec == 0); % 
    if isempty(active_nodes), break; end
    
    %% 
    num_blocks = ceil(length(active_nodes)/blockSize);
    for b = 1:num_blocks
        % 
        blk_start = (b-1)*blockSize + 1;
        blk_end = min(b*blockSize, length(active_nodes));
        current_blk = active_nodes(blk_start:blk_end);
        
        % 
        I = zeros(length(current_blk), N);
        for idx = 1:length(current_blk)
            iN = current_blk(idx);
            if iN == 1, continue; end % 
            cols = parent_indices{iN};
            I(idx, cols) = abs(Xn(:,cols)' * res(:,iN));
        end
        
        % 
        [max_corr, max_indices] = max(I, [], 2);
        
        % 
        for local_idx = 1:length(current_blk)
            global_idx = current_blk(local_idx);
            if global_idx == 1, continue; end
            max_col = max_indices(local_idx);
            if max_col > 0
                S(global_idx, t) = max_col;
                temp = parent_indices{global_idx};
                parent_indices{global_idx} = temp(temp~=max_col);
            end
        end
    end
    
    %% 
    for iN = 2:N % 
        if t_vec(iN) > 0 || isempty(parent_indices{iN}), continue; end
        
        current_support = nonzeros(S(iN,t));
        if ~isempty(current_support)

            coeff = Xn(:,current_support) \ res(:, iN);
            
            res(:,iN) = res(:,iN) - Xn(:,current_support) * coeff;
            
            norm(res(:,iN))
            if norm(res(:,iN)) < thr
                t_vec(iN) = t;
            end
        end
    end
end

for iN = 2:N	
    idx = find(S(iN,:)>0);
    if ~isempty(idx)
        Val(iN, S(iN, idx)) = (X(:, S(iN, idx)) \ X(:, iN))'; % use X rather than Xn
    end
end

%%
[rows, cols, vals] = find(Val);
temp_C = sparse(rows, cols, vals, N, N);
r_C = zeros(N, N);
r_C(r_Ord, r_Ord) = temp_C; %
end