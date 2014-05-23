function [W,F,V,E,H] = bwmesh(A,varargin)
  % BWMESH Construct a mesh from a black and white image.
  %
  % [W,F] = bwmesh(A)
  % [W,F] = bwmesh(png_filename)
  % [W,F,V,E,H] = bwmesh(...,'ParameterName',ParameterValue,...)
  %
  % Inputs:
  %   A  a h by w black and white image (grayscale double images will be
  %     clamped)
  %     or
  %   png_filename  path to a png file
  %   Optional:
  %     'Tol'  tolerance for Douglas-Peucker algorithm {0}
  %     'TriangleFlags' followed by flags to pass to triangle
  %       {'-q30a[avg_sqr_length]'}
  % Outputs:
  %   W  #W by 2 list of mesh vertices
  %   F  #F by 3 list of triangle indices into W
  %   V  #V by 2 list of boundary polygon vertices
  %   E  #E by 2 list of boundary edge indices into V
  %   H  #H by 2 list of hole indicator point positions
  %

  if ischar(A)
    % read alpha channel
    [~,~,A] = imread(A);
  end

  % default values
  tol = 0;
  triangle_flags = '';
  % Map of parameter names to variable names
  params_to_variables = containers.Map( ...
    {'Tol','TriangleFlags'}, ...
    {'tol','triangle_flags'});
  v = 1;
  while v <= numel(varargin)
    param_name = varargin{v};
    if isKey(params_to_variables,param_name)
      assert(v+1<=numel(varargin));
      v = v+1;
      % Trick: use feval on anonymous function to use assignin to this workspace 
      feval(@()assignin('caller',params_to_variables(param_name),varargin{v}));
    else
      error('Unsupported parameter: %s',varargin{v});
    end
    v=v+1;
  end

  % B contains list of boundary loops then hole loops, N number of outer
  % boundaries (as opposed to hole boundaries)
  [B,~,N] = bwboundaries(A>0.5);
  V = [];
  E = [];
  H = [];
  for b = 1:numel(B)
    Vb = B{b};
    Vb = bsxfun(@plus,Vb*[0 -1;1 0],[-0.5,size(A,1)+0.5]);
    if tol > 0 
      Vb = dpsimplify(Vb([1:end 1],:),tol);
      Vb = Vb(1:end-1,:);
    end
    % don't consider degenerate boundaries
    if size(Vb,1)>2
      Eb = [1:size(Vb,1);2:size(Vb,1) 1]';
      E = [E;size(V,1)+Eb];
      V = [V;Vb];
      if b > N
        H = [H;point_inside_polygon(Vb)];
      end
    end
  end
  if isempty(triangle_flags)
    % triangulate the polygon
    % get average squared edge length as a guess at the maximum area constraint
    % for the triangulation
    avg_sqr_edge_length = mean(sum((V(E(:,1),:)-V(E(:,2),:)).^2,2))/2.0;
    quality = 30;
    triangle_flags = sprintf('-q%da%0.17f',quality,avg_sqr_edge_length);
  end

  [W,F] = triangle(V,E,H,'Flags',triangle_flags,'Quiet');
end