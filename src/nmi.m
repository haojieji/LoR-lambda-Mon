function nmi = nmi(true_labels, pred_labels)
    confusion_matrix = accumarray([true_labels, pred_labels], 1);
    
    P_true = sum(confusion_matrix, 2) / sum(confusion_matrix(:));
    P_pred = sum(confusion_matrix, 1) / sum(confusion_matrix(:));
    
    P_joint = confusion_matrix / sum(confusion_matrix(:));
    
    mi = 0;
    for i = 1:size(P_joint, 1)
        for j = 1:size(P_joint, 2)
            if P_joint(i,j) > 0
                mi = mi + P_joint(i,j) * log(P_joint(i,j) / (P_true(i) * P_pred(j)));
            end
        end
    end
    
    H_true = -sum(P_true .* log(P_true + eps));
    H_pred = -sum(P_pred .* log(P_pred + eps));
    
    nmi = mi / sqrt(H_true * H_pred);
end
