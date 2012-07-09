function topo_fdr_thresholding(spm_mat_file, con_index, cluster_forming_thr, thresDesc, use_topo_fdr, force_activation, cluster_extent_p_fdr_thr, stat_filename, height_threshold_type, extent_threshold)

% write thresholded images on the disk folowing different methods
%
% FORMAT: topo_fdr_thresholding(spm_mat_file, con_index, cluster_forming_thr, thresDesc, use_topo_fdr, force_activation, cluster_extent_p_fdr_thr, stat_filename, height_threshold_type, extent_threshold)
%
% INPUT: spm_mat_file: full name (ie with path) of the SPM.mat
%        con_index: the number of the contrast image
%        cluster_forming_thr: the T value to threashold voxels and create clusters
%        thresDesc: what method to apply 'FWE' for random filed theory or 'none' for FDR
%        use_topo_fdr: should be set to 1 to apply FDR on clusters
%        force_activation: should be set to 1 - if nothing survives the topological FDR we can still look at 
%                          the map threasholded at the voxel level
%        cluster_extent_p_fdr_thr: 0.05 that the q value in FDR
%        stat_filename: full name (ie with path) of the spmT image
%        height_threshold_type: 'stat'
%        extent_threshold: since we already use FDR on clusters we should leave that to 0
%
% OUTPUT: 2 images are writen on the disk, one before applying the
% correction for multiple comparisons based on clusters and one after
%
% see also adaptive_thresholding
% ------------------------------------------
% Chris Gorgolewski 29 June 2012

load(spm_mat_file);

FWHM  = SPM.xVol.FWHM;
df = [SPM.xCon(con_index).eidf SPM.xX.erdf];
STAT = SPM.xCon(con_index).STAT;
R = SPM.xVol.R;
S = SPM.xVol.S;
n = 1;

switch thresDesc
    case 'FWE'
        cluster_forming_thr = spm_uc(cluster_forming_thr,df,STAT,R,n,S);
        
    case 'none'
        if strcmp(height_threshold_type, 'p-value')
            cluster_forming_thr = spm_u(cluster_forming_thr^(1/n),df,STAT);
        end
end

stat_map_vol = spm_vol(stat_filename);
[stat_map_data, stat_map_XYZmm] = spm_read_vols(stat_map_vol);

Z = stat_map_data(:)';
[x,y,z] = ind2sub(size(stat_map_data),(1:numel(stat_map_data))');
XYZ = cat(1, x', y', z');

XYZth = XYZ(:, Z >= cluster_forming_thr);
Zth = Z(Z >= cluster_forming_thr);
[pathstr, name, ext] = fileparts(stat_filename)
spm_write_filtered(Zth,XYZth,stat_map_vol.dim',stat_map_vol.mat,'thresholded map', strrep(stat_filename,ext, '_pre_topo_thr.hdr'));

max_size = 0;
max_size_index = 0;
th_nclusters = 0;
nclusters = 0;
if isempty(XYZth)
    thresholded_XYZ = [];
    thresholded_Z = [];
else
    if use_topo_fdr
        V2R        = 1/prod(FWHM(stat_map_vol.dim > 1));
        [uc,Pc,ue] = spm_uc_clusterFDR(cluster_extent_p_fdr_thr,df,STAT,R,n,Z,XYZ,V2R,cluster_forming_thr);
    end
    
    voxel_labels = spm_clusters(XYZth);
    nclusters = max(voxel_labels);
    
    thresholded_XYZ = [];
    thresholded_Z = [];
    
    for i = 1:nclusters
        cluster_size = sum(voxel_labels==i);
        if cluster_size > extent_threshold && (~use_topo_fdr || (cluster_size - uc) > -1)
            thresholded_XYZ = cat(2, thresholded_XYZ, XYZth(:,voxel_labels == i));
            thresholded_Z = cat(2, thresholded_Z, Zth(voxel_labels == i));
            th_nclusters = th_nclusters + 1;
        end
        if force_activation
            cluster_sum = sum(Zth(voxel_labels == i));
            if cluster_sum > max_size
                max_size = cluster_sum;
                max_size_index = i;
            end
        end
    end
end

activation_forced = 0;
if isempty(thresholded_XYZ)
    if force_activation && max_size ~= 0
        thresholded_XYZ = XYZth(:,voxel_labels == max_size_index);
        thresholded_Z = Zth(voxel_labels == max_size_index);
        th_nclusters = 1;
        activation_forced = 1;
    else
        thresholded_Z = [0];
        thresholded_XYZ = [1 1 1]';
        th_nclusters = 0;
    end
end

fprintf('activation_forced = %d\n',activation_forced);
fprintf('pre_topo_n_clusters = %d\n',nclusters);
fprintf('n_clusters = %d\n',th_nclusters);
fprintf('cluster_forming_thr = %f\n',cluster_forming_thr);

spm_write_filtered(thresholded_Z,thresholded_XYZ,stat_map_vol.dim',stat_map_vol.mat,'thresholded map', strrep(stat_filename,ext, '_thr.hdr'));

end

