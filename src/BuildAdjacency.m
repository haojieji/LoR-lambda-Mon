%--------------------------------------------------------------------------
% This function takes a NxN coefficient matrix and returns a NxN adjacency
% matrix by choosing the K strongest connections in the similarity graph
% CMat: NxN coefficient matrix
% K: number of strongest edges to keep; if K=0 use all the exiting edges
% CKSym: NxN symmetric adjacency matrix

function [CKSym,CAbs] = BuildAdjacency(CMat,K)

if (nargin < 2)
    K = 0;
end

N = size(CMat,1);
CAbs = abs(CMat);

[Srt,Ind] = sort( CAbs,1,'descend' );

if (K == 0)
    for i = 1:N
        if (CAbs(Ind(1,i),i)+eps) ~= 0
            CAbs(:,i) = CAbs(:,i) ./ (CAbs(Ind(1,i),i)+eps);
        else
            CAbs(:,i) = CAbs(:,i);
        end
    end
else
    for i = 1:N
        for j = 1:K
            if (CAbs(Ind(1,i),i)+eps) ~= 0
                CAbs(Ind(j,i),i) = CAbs(Ind(j,i),i) ./ (CAbs(Ind(1,i),i)+eps);
            else
                CAbs(Ind(j,i),i) = CAbs(Ind(j,i),i);
            end
        end
    end
end

CKSym = CAbs + CAbs';
