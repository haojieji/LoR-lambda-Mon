function ari = adjusted_rand_index(true_labels, pred_labels)
    confusion_matrix = accumarray([true_labels, pred_labels], 1);
    
    sum_over_rows = sum(confusion_matrix, 2);
    sum_over_cols = sum(confusion_matrix, 1);
    n = sum(confusion_matrix(:));
    
    n_choose_2 = @(x) x*(x-1)/2;
    sum_over_rows_comb = sum(arrayfun(n_choose_2, sum_over_rows));
    sum_over_cols_comb = sum(arrayfun(n_choose_2, sum_over_cols));
    total_comb = n_choose_2(n);
    
    ari = (sum(arrayfun(n_choose_2, confusion_matrix(:))) - (sum_over_rows_comb * sum_over_cols_comb) / total_comb) ...
          / (0.5 * (sum_over_rows_comb + sum_over_cols_comb) - (sum_over_rows_comb * sum_over_cols_comb) / total_comb);
end