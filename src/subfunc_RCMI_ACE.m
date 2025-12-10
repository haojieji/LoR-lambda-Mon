% ACE- root causal metric identification
% Input: each cluster's Causal Adjacent Weight,
%        r_Stru_i, r_B_i, r_Ord_i, r_B, r_Stru, W, and 
% Output: , r_IDX_root,  
% r_IDX_intermedia
function [r_IDX_root, r_IDX_intermedia]= subfunc_RCMI_ACE(r_Stru_i, r_B_i, r_Ord_i, r_B, r_Stru, W, thr_ACE)

    IDX_root_init = find( sum(r_Stru_i,2)==0 ); % initial root causal metric with indegree=0
    r_IDX_root = r_Ord_i(IDX_root_init); % 
    r_IDX_intermedia = []; % 
    W_infer = zeros(size(W)); % 
    for ime = length(IDX_root_init)+1:length(r_Ord_i)

        ime_idx = r_Ord_i(ime);
        ime_childs = find(r_Stru_i(:,ime) ~= 0);
        if ~isempty(ime_childs)
            E_do_1 = 0; % E[ime_childs | do(ime=1)]  
            E_do_0 = 0; % E[ime_childs | do(ime=0)]  
    

            ime_infer_node = recursive_ime(ime, r_Stru_i, r_B_i, r_Ord_i, r_IDX_root, W, r_IDX_intermedia, W_infer);

            ime_childs_idx = r_Ord_i(ime_childs); % 
            for j = 1:length(ime_childs_idx)
                ici = ime_childs_idx(j);
                child = W(ici,:);

                parents_idx = find(r_Stru(ici,:)~=0);
                parents = W(parents_idx,:);
                coeff = r_B(ici, parents_idx);
                
                child_infer_do1 = parents' * coeff';
                err_ici = sum(abs(child' - child_infer_do1)) / sum(abs(child')); % 
                
                E_do_1 = E_do_1 + err_ici;
    
                % ime_index in parents
                ime_parents_idx = find(parents_idx == ime_idx);
                parents(ime_parents_idx,:) = ime_infer_node;

                child_infer_do0 = parents' * coeff';
                err_ici_do0 = sum(abs(child' - child_infer_do0)) / sum(abs(child')); %
                
                E_do_0 = E_do_0 + err_ici_do0;
            end
            E_do_1 = E_do_1/length(ime_childs_idx);
            E_do_0 = E_do_0/length(ime_childs_idx);

            ACE =  abs(E_do_0-E_do_1);  % 
            
            disp(["ACE=do0-do1, ",E_do_0," - ",E_do_1," = ", ACE])
            
            if ACE > thr_ACE
                %
                r_IDX_root = [r_IDX_root ime_idx];
            else
                % 
                r_IDX_intermedia = [r_IDX_intermedia ime_idx];
                W_infer(ime_idx,:) = ime_infer_node';
            end
        end
    end
end

function ime_infer_node = recursive_ime(start_ime, r_Stru_i, r_B_i, r_Ord_i, r_IDX_root, W, r_IDX_intermedia, W_infer)
    % step1-
    ime_parents_idx = find( r_Stru_i(start_ime,:) ~= 0 );
    
    if isempty(ime_parents_idx)
        ime_infer_node = W(r_Ord_i(start_ime),:); %
        return
    end
    % step2-
    ime_parents = [];
    for ipi = ime_parents_idx
        if ~ismember(r_Ord_i(ipi), r_IDX_root)
            % ime3-
            if ismember( r_Ord_i(ipi), r_IDX_intermedia)
                ime_parents_ipi = W_infer(r_Ord_i(ipi),:); % 
            else
                ime_parents_ipi = recursive_ime(ipi, r_Stru_i, r_B_i, r_Ord_i, r_IDX_root, W, r_IDX_intermedia, W_infer);
            end
        else
            ime_parents_ipi = W(r_Ord_i(ipi),:); % 
        end
        ime_parents = [ime_parents ime_parents_ipi'];
    end
    
    % ime4-
    ime_infer_node = (ime_parents * r_B_i(start_ime, ime_parents_idx)')';
    return
end
