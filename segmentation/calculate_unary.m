function [unary_scan, unary_smpl] = calculate_unary( ...
    mesh_scan, mesh_smpl, prior_scan, prior_smpl)

global is_first;
global mesh_prefix;
global mesh_prefix_last;
global result_dir;
global result_dir_base;	

n_scan = size(mesh_scan.vertices, 1);
n_smpl = size(mesh_smpl.vertices, 1);

% unary: data likelihood
% for both SMPL and scan model
unary_scan_data = zeros(n_scan, 3);
unary_smpl_data = zeros(n_smpl, 3);

if is_first
    center_ind = [21888, 16836, 15667];
    
    % color feature
    color_start = mesh_scan.colors(center_ind, :);
    color_start = rgb2hsv(double(color_start) / 255);
    color_hsv = rgb2hsv(double(mesh_scan.colors) / 255);
    
    % total feature;
    total_feature = color_hsv;
    total_start = color_start;
    
    % k-means on scan
    labels_k_means = kmeans(total_feature, 3, 'Start', total_start);
    
    m = mesh_scan;
    m.colors = render_labels(labels_k_means - 1);
    mesh_exporter([result_dir, filesep, mesh_prefix, '_kmeans.obj'], m, true);
    
    % for scan
    % find neighbors directly from adjacent map
    for i = 1 : n_scan
        adjacency = mesh_scan.adjacency_map(i, :);
        [~, neighbors_ind] = find(adjacency == 1);
        neighbor_label = labels_k_means(neighbors_ind);
        
        unary_scan_data(i, 1) = sum(-log((neighbor_label == 1) + 1e-6));
        unary_scan_data(i, 2) = sum(-log((neighbor_label == 2) + 1e-6));
        unary_scan_data(i, 3) = sum(-log((neighbor_label == 3) + 1e-6));
    end
    
    % for smpl
    % node i -> scan point v -> v's neighbors
    ind_scan = matching_pair(mesh_scan, mesh_smpl, 1);
    for i = 1 : size(ind_scan, 1)
        neighbors = mesh_scan.adjacency_map(ind_scan(i), :);
        [~, neighbors_ind] = find(neighbors == 1);
        neighbor_label = labels_k_means(neighbors_ind);
        
        unary_smpl_data(i, 1) = sum(-log((neighbor_label == 1) + 1e-6));
        unary_smpl_data(i, 2) = sum(-log((neighbor_label == 2) + 1e-6));
        unary_smpl_data(i, 3) = sum(-log((neighbor_label == 3) + 1e-6));
    end
else
	gmm_path = [result_dir_base, filesep, mesh_prefix_last];
    gmm_name = [mesh_prefix_last, '_gmm.mat'];
    gmm = load([gmm_path, filesep, gmm_name]);
    gmm = gmm.gmm;
    
    % for scan
    % find neighbors directly from adjacent map
    for i = 1 : n_scan
        adjacency = mesh_scan.adjacency_map(i, :);
        [~, neighbors_ind] = find(adjacency == 1);
        neighbor_colors = mesh_scan.colors(neighbors_ind, :);
        
        probs = gmm_sample(gmm, neighbor_colors);
        unary_scan_data(i, :) = sum(-log(probs + 1e-6));
    end

    % for smpl
    % node i -> scan point v -> v's neighbors
    ind_scan = matching_pair(mesh_scan, mesh_smpl, 1);
    for i = 1 : size(ind_scan, 1)
        neighbors = mesh_scan.adjacency_map(ind_scan(i), :);
        [~, neighbors_ind] = find(neighbors == 1);
        neighbor_colors = mesh_scan.colors(neighbors_ind, :);
        
        probs = gmm_sample(gmm, neighbor_colors);
        unary_smpl_data(i, :) = sum(-log(probs + 1e-6));
    end
end

[~, ind_smpl] = min(unary_smpl_data, [], 2);
[~, ind_scan] = min(unary_scan_data, [], 2);

m = mesh_smpl;
m.colors = render_labels(ind_smpl - 1);
mesh_exporter([result_dir, filesep, mesh_prefix, '_unary_smpl_data.obj'], m, true);
m = mesh_scan;
m.colors = render_labels(ind_scan - 1);
mesh_exporter([result_dir, filesep, mesh_prefix, '_unary_scan_data.obj'], m, true);

% unary: prior
% for both SMPL and scan model
unary_scan_prior = zeros(n_scan, 3);
unary_smpl_prior = zeros(n_smpl, 3);

% for scan
l_skin_scan(prior_scan.skin == 0) = 100;
l_skin_scan(prior_scan.skin == 1) = -200;
l_skin_scan(prior_scan.skin == 0.5) = 0;

l_shirt_scan(prior_scan.shirt == 0) = 100;
l_shirt_scan(prior_scan.shirt == 1) = -200;
l_shirt_scan(prior_scan.shirt == 0.5) = 0;

l_pants_scan(prior_scan.pants == 0) = 100;
l_pants_scan(prior_scan.pants == 1) = -200;
l_pants_scan(prior_scan.pants == 0.5) = 0;

unary_scan_prior(:, 1) = l_skin_scan;
unary_scan_prior(:, 2) = l_shirt_scan;
unary_scan_prior(:, 3) = l_pants_scan;

% for smpl
l_skin_smpl(prior_smpl.skin == 0) = 100;
l_skin_smpl(prior_smpl.skin == 1) = -200;
l_skin_smpl(prior_smpl.skin == 0.5) = 0;

l_shirt_smpl(prior_smpl.shirt == 0) = 100;
l_shirt_smpl(prior_smpl.shirt == 1) = -200;
l_shirt_smpl(prior_smpl.shirt == 0.5) = 0;

l_pants_smpl(prior_smpl.pants == 0) = 100;
l_pants_smpl(prior_smpl.pants == 1) = -200;
l_pants_smpl(prior_smpl.pants == 0.5) = 0;

unary_smpl_prior(:, 1) = l_skin_smpl;
unary_smpl_prior(:, 2) = l_shirt_smpl;
unary_smpl_prior(:, 3) = l_pants_smpl;

% total unary
% for both SMPL and scan model
unary_scan = unary_scan_data + unary_scan_prior;
unary_smpl = unary_smpl_data + unary_smpl_prior;

[~, ind_smpl] = min(unary_smpl, [], 2);
[~, ind_scan] = min(unary_scan, [], 2);

m = mesh_smpl;
m.colors = render_labels(ind_smpl - 1);
mesh_exporter([result_dir, filesep, mesh_prefix, '_unary_smpl_all.obj'], m, true);
m = mesh_scan;
m.colors = render_labels(ind_scan - 1);
mesh_exporter([result_dir, filesep, mesh_prefix, '_unary_scan_all.obj'], m, true);

end

