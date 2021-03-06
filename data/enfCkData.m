% data file for the double cantilever beam problem
% VP Nguyen, H Nguyen-Xuan High order Bsplines for delamination paper.

addpath ../fem_util/;
addpath ../nurbs-geopdes/inst/
addpath ../nurbs-util/
addpath ../meshing/
addpath ../fem-functions/
addpath ../post-processing/
addpath ../xiga/
addpath ../nurbs-geopdes/inst/


L = 100;
W = 3;
a0 = 30;

p = 1;
q = 1;

% initial mesh- linear x linear

controlPts          = zeros(4,2,2);

controlPts(1:2,1,1) = [0;0];
controlPts(1:2,2,1) = [L;0];
controlPts(1:2,1,2) = [0;W];
controlPts(1:2,2,2) = [L;W];

controlPts(4,:,:)   = 1;

uKnot = [0 0 1 1];
vKnot = [0 0 1 1];

%% build NURBS object

solid = nrbmak(controlPts,{uKnot vKnot});

% evaluate order 

solid = nrbdegelev(solid,[2 1]); 

% h-refinement in Y direction to make sure it is C^{-1} along the 
% delamination path. The multiplicity must be q+1.
  
solid     = nrbkntins(solid,{[0.5 0.5 0.5] [0.5 0.5 0.5]});

% insert for intitial crack 

solid     = nrbkntins(solid,{[1-a0/L ] []});

uKnot     = cell2mat(solid.knots(1));
vKnot     = cell2mat(solid.knots(2));


refineCountX = 4;
for i=1:refineCountX
    uKnotVectorU = unique(uKnot);
    uKnotVectorV = unique(vKnot);
   
    newKnotsY = [];
    
    % new knots along two directions (uniform)
    
    %newKnotsX = uKnotVectorU(1:end-1) + 0.5*diff(uKnotVectorU);
    newKnotsX = uKnotVectorU(1:end-1) + 0.5*diff(uKnotVectorU);
    
    newKnots  = {newKnotsX newKnotsY};
    
    % h-refinement
    
    solid     = nrbkntins(solid,newKnots);
    
    uKnot      = cell2mat(solid.knots(1));
    vKnot      = cell2mat(solid.knots(2));
end

%% convert to IGA format

convert2DNurbs
noCtrPts       = noPtsX * noPtsY;
noDofs         = noCtrPts * 2;
    

%% generate element connectivity ...

generateIGA2DMesh

% plot the mesh

buildVisualizationMesh;

% Plot mesh and enriched nodes to check
figure
hold on
plot_mesh(node,elementV,'Q4','b-',1.1);
n5 = plot(controlPts(:,1),controlPts(:,2),'go');
set(n5,'MarkerSize',4, 'MarkerFaceColor','g','MarkerEdgeColor','k','LineWidth',1.01);
%axis off


%% Bezier extraction operators

[C,Cxi,Cet]  = bezierExtraction2D(uKnot,vKnot,p,q);
    
% build mesh of interface elements

delaminationNodes  =  find(abs(controlPts(:,2) -W/2  ) <1e-10);
mm                 = 0.5*length(delaminationNodes);
lowerNodes         = delaminationNodes(1:mm);
upperNodes         = delaminationNodes(mm+1:end);

iElements   = zeros(noElemsU,2*(p+1));

for i=1:noElemsU
    iElements(i,1:p+1)   = lowerNodes(i:i+p);
    iElements(i,p+2:end) = upperNodes(i:i+p);
end

%% write to jive mesh 

fixedNodes   =  [1 noPtsX];
forcedNodes  = intersect(find(abs(controlPts(:,1)-L/2)<eps),...
                         find(abs(controlPts(:,2)-W  )<eps));

% xi     = 0.5;
% span   = findspan(noPtsX-1,p,xi,uKnot);
% ielem  = span - 1;
% elem   = element(ielem,:);
% forcedNodes=elem(end-2:end);

noElems  = size(C,3);

fileName = '~/code/jive/bezier/delamination/enf/enf.mesh';

file = fopen(fileName, 'wt');

fprintf(file, '<Nodes>\n');

for i=1:length(controlPts)
   fprintf(file, '  %1d %2.6f %2.6f', i, controlPts(i,1),controlPts(i,2));
   fprintf(file, ';\n');
end

fprintf(file, '</Nodes>\n\n');

fprintf(file, '<Elements>\n');

% write solid elements

for i=1:noElems
   fprintf(file, '  %1d %1d', i-1, element(i,:) );
   fprintf(file, ';\n');
end

% write interface elements

for i=1:noElemsU
   fprintf(file, '  %1d %1d', noElems+i-1, iElements(i,:) );
   fprintf(file, ';\n');
end

fprintf(file, '</Elements>\n\n');

% write Bezier extractors 
% first for solid elements
% then for interface elements

fprintf(file, '<ElementDatabase name="C">\n');

fprintf(file, ' <Column name = "irows" type = "int">\n');

for e=1:noElems
    Ce = C(:,:,e);
    [row,col] = find(Ce);
    fprintf(file, '  %1d ', e-1);
    for i=1:length(row)
        fprintf(file, '%1d ', row(i)-1);
    end
    fprintf(file, ';\n');
end

for e=1:noElemsU
    Ce = Cxi(:,:,e);
    [row,col] = find(Ce);
    fprintf(file, '  %1d ', noElems+e-1);
    for i=1:length(row)
        fprintf(file, '%1d ', row(i)-1);
    end
    fprintf(file, ';\n');
end

fprintf(file, ' </Column>\n');

fprintf(file, ' <Column name = "jcols" type = "int">\n');

for e=1:noElems
    Ce = C(:,:,e);
    [row,col] = find(Ce);
    
    fprintf(file, '  %d ', e-1);
    for i=1:length(row)
        fprintf(file, '%1d ', col(i)-1);
    end
    fprintf(file, ';\n');
end

for e=1:noElemsU
    Ce = Cxi(:,:,e);
    [row,col] = find(Ce);
    
    fprintf(file, '  %d ', noElems+e-1);
    for i=1:length(row)
        fprintf(file, '%1d ', col(i)-1);
    end
    fprintf(file, ';\n');
end

fprintf(file, ' </Column>\n');

fprintf(file, ' <Column name = "values" type = "float">\n');
for e=1:noElems
    Ce = C(:,:,e);
    [row,col,val] = find(Ce);
    
    fprintf(file, '  %d ', e-1);
    for i=1:length(row)
        fprintf(file, '%2.1f ', val(i));
    end
    fprintf(file, ';\n');
end
for e=1:noElemsU
    Ce = Cxi(:,:,e);
    [row,col,val] = find(Ce);
    
    fprintf(file, '  %d ', noElems+e-1);
    for i=1:length(row)
        fprintf(file, '%2.1f ', val(i));
    end
    fprintf(file, ';\n');
end
fprintf(file, ' </Column>\n');

% write weights 

fprintf(file, ' <Column name = "weights" type = "float">\n');

for e=1:noElems
    W = weights(element(e,:));
    fprintf(file, '  %1d ',e-1);
    for j=1:length(W)
        fprintf(file, '%2.4f ', W(j));
    end
    fprintf(file, ';\n');
end

for e=1:noElemsU
    sctr = iElements(e,:);
    W = weights(sctr(1:0.5*end));
    fprintf(file, '  %1d ',noElems+e-1);
    for j=1:length(W)
        fprintf(file, '%2.4f ', W(j));
    end
    fprintf(file, ';\n');
end

fprintf(file, ' </Column>\n');
fprintf(file, '</ElementDatabase>\n\n');

% write element groups

fprintf(file, '<ElementGroup name="solid">\n{');

for i=1:noElems
   fprintf(file, '  %1d', i-1);
  
end
fprintf(file, '}\n');
fprintf(file, '</ElementGroup>\n');

fprintf(file, '<ElementGroup name="interface">\n{');

for i=1+noElems:noElems+noElemsU
   fprintf(file, '  %1d', i-1);
  
end
fprintf(file, '}\n');
fprintf(file, '</ElementGroup>\n');

contacts =noElemsU-15:noElemsU;
cohesives= setdiff(1:noElemsU, contacts);
contacts = contacts - 1;
cohesives = cohesives - 1;

fprintf(file, '<ElementGroup name="contacts">\n{');

for i=1:length(contacts)
   fprintf(file, '  %1d', contacts(i) + noElems);
  
end
fprintf(file, '}\n');
fprintf(file, '</ElementGroup>\n');

fprintf(file, '<ElementGroup name="cohesives">\n{');

for i=1:length(cohesives)
   fprintf(file, '  %1d', cohesives(i) + noElems);
  
end
fprintf(file, '}\n');
fprintf(file, '</ElementGroup>\n');

% write node groups

fprintf(file, '<NodeGroup name="gr1">\n{');
fprintf(file, '  %1d', fixedNodes(1));
fprintf(file, '}\n');
fprintf(file, '</NodeGroup>\n');

fprintf(file, '<NodeGroup name="gr2">\n{');
fprintf(file, '  %1d', fixedNodes(2));
fprintf(file, '}\n');
fprintf(file, '</NodeGroup>\n');

fprintf(file, '<NodeGroup name="gr3">\n{');

for i=1:length(forcedNodes)
   fprintf(file, '  %1d', forcedNodes(i));
  
end
fprintf(file, '}\n');
fprintf(file, '</NodeGroup>\n');

fclose(file);

