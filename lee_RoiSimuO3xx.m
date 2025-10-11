function lee_RoiSimuO3xx()
% =========================================================================
% PROGRAMA: Lectura de ROI y Tumor Virtual en Cerebro Completo
% DESCRIPCIÓN: Permite cargar un archivo .mat que contenga el cerebro completo
% (por ejemplo, generado con Brain_Sai_1210_2025) y, opcionalmente, cargar un ROI
% de tumor (virtual) que se posiciona dentro del cerebro usando offsets.
% Se visualiza el cerebro en gris claro (muy transparente), el tumor en rojo y
% la combinación de ambos.
%
% ARCHIVOS REQUERIDOS:
%  - Cerebro completo: un archivo .mat que contenga la variable T o roiData
%    (para generar T) representando el cerebro completo.
%  - Tumor: un archivo .mat que contenga, preferiblemente, roiData_withTumor (con
%    el campo tumor y las coordenadas del ROI) o bien la variable T (ROI del tumor).
%
% SALIDA: Se muestran figuras en 3D.
%
% AUTOR: SAI JORGE ROBLERO WONG
% FECHA: Febrero 2025
% =========================================================================

%% Configurar ventanas de figuras (opcional: docked)
% set(0, 'DefaultFigureWindowStyle', 'docked');

%% Cargar el cerebro completo
defaultBrainFile = '/Users/jorgeroblero/Documents/SAI_BRAIN/FullBrain.mat';
changeBrain = input(sprintf('Se va a usar el cerebro completo: %s. ¿Desea cambiarlo? (s/n, default=n): ', defaultBrainFile), 's');
if isempty(changeBrain) || lower(changeBrain(1))=='n'
    brainFile = defaultBrainFile;
else
    [filename, pathname] = uigetfile('*.mat','Seleccione el archivo .mat del cerebro completo');
    if isequal(filename, 0)
        error('No se seleccionó ningún archivo para el cerebro.');
    else
        brainFile = fullfile(pathname, filename);
    end
end
fprintf('Cerebro completo usado: %s\n', brainFile);
load(brainFile);
% Verificar que T esté presente; si no, generarla desde roiData
if ~exist('T','var')
    if exist('roiData','var')
        organNames = fieldnames(roiData.organs);
        T = false(size(roiData.organs.(organNames{1})));
        for i = 1:length(organNames)
            T = T | logical(roiData.organs.(organNames{i}));
        end
        disp('Variable T generada a partir de roiData (full brain).');
    else
        error('La variable T no se encuentra y no se puede generar desde roiData.');
    end
end
T = squeeze(T);  % Asegurarse de que T sea 3D
fullBrainMask = T;  % El cerebro completo

%% Visualizar el cerebro completo en gris claro (muy transparente)
figure('Name','Cerebro Completo','Color','w');
[f_brain, v_brain] = isosurface(fullBrainMask, 0.5);
p_brain = patch('Faces', f_brain, 'Vertices', v_brain);
p_brain.FaceColor = [0.8 0.8 0.8];  % Gris claro
p_brain.EdgeColor = 'none';
p_brain.FaceAlpha = 0.1;  % Muy transparente
axis equal; view(3); camlight; lighting phong; rotate3d on;
title('Cerebro Completo');

%% Preguntar si se desea cargar el ROI del tumor (por defecto no)
otro = input('¿Desea cargar otro ROI (tumor) y sumarlo al cerebro? (s/n, default=n): ', 's');
if ~isempty(otro) && lower(otro(1))=='s'
    [filenameTumor, pathnameTumor] = uigetfile('*.mat','Seleccione el archivo .mat del tumor');
    if isequal(filenameTumor,0)
         error('No se seleccionó ningún archivo para el tumor.');
    end
    tumorFile = fullfile(pathnameTumor, filenameTumor);
    fprintf('Archivo seleccionado para el tumor: %s\n', tumorFile);
    load(tumorFile);
    
    % Caso 1: El archivo del tumor contiene roiData_withTumor
    if exist('roiData_withTumor','var')
         tumorT = squeeze(roiData_withTumor.tumor);
         % Usar los límites del ROI como offsets
         offsetX = roiData_withTumor.xRange(1);
         offsetY = roiData_withTumor.yRange(1);
         offsetZ = roiData_withTumor.zRange(1);
         fprintf('Se detectó roiData_withTumor. Offset tomado: X=%d, Y=%d, Z=%d\n', offsetX, offsetY, offsetZ);
    else
         % Caso 2: El archivo solo contiene T (tumor ROI sin posición)
         if ~exist('T','var')
             error('La variable T no se encuentra en el archivo del tumor.');
         end
         tumorT = squeeze(T);
         tumorT_suavizado = imgaussfilt3(tumorT, sigma);

         [fullX, fullY, fullZ] = size(fullBrainMask);
         [tumorX, tumorY, tumorZ] = size(tumorT);
         if tumorX > fullX || tumorY > fullY || tumorZ > fullZ
              error('El volumen del tumor es mayor que el del cerebro completo.');
         end
         maxOffsetX = fullX - tumorX + 1;
         maxOffsetY = fullY - tumorY + 1;
         maxOffsetZ = fullZ - tumorZ + 1;
         offsetX = input(sprintf('Offset en X (entre 1 y %d, default=1): ', maxOffsetX));
         if isempty(offsetX), offsetX = 1; end
         offsetY = input(sprintf('Offset en Y (entre 1 y %d, default=1): ', maxOffsetY));
         if isempty(offsetY), offsetY = 1; end
         offsetZ = input(sprintf('Offset en Z (entre 1 y %d, default=1): ', maxOffsetZ));
         if isempty(offsetZ), offsetZ = 1; end
    end
    
        % *** SUAVIZADO ***
    sigma = 2; % Ajusta este valor para controlar la cantidad de suavizado
    tumorT_suavizado = imgaussfilt3(tumorT, sigma);

 
    % Crear tumorFull: ubicar tumorT dentro del cerebro completo usando los offsets
    [fullX, fullY, fullZ] = size(fullBrainMask);
    [tumorX, tumorY, tumorZ] = size(tumorT);
    tumorFull = false(fullX, fullY, fullZ);
    xIdx = offsetX : offsetX + tumorX - 1;
    yIdx = offsetY : offsetY + tumorY - 1;
    zIdx = offsetZ : offsetZ + tumorZ - 1;
    tumorFull(xIdx, yIdx, zIdx) = tumorT;
    
    % Combinar el cerebro completo con el tumor insertado
    combinedT = fullBrainMask | tumorFull;
    
    %% Visualizar el tumor (solo) en rojo
    figure('Name','Tumor Virtual','Color','w');
    [f_tumor, v_tumor] = isosurface(tumorFull, 0.5);
    patch('Faces', f_tumor, 'Vertices', v_tumor, 'FaceColor', 'red', 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    axis equal; view(3); camlight; lighting phong; rotate3d on;
    title('Tumor Virtual (Rojo)');
    
    %% Visualizar la combinación: Cerebro + Tumor
    figure('Name','Cerebro Completo con Tumor Virtual','Color','w');
    % Graficar el cerebro (muy transparente)
    [f_brain, v_brain] = isosurface(fullBrainMask, 0.5);
    p_brain = patch('Faces', f_brain, 'Vertices', v_brain);
    p_brain.FaceColor = [0.8 0.8 0.8];  
    p_brain.EdgeColor = 'none';
    p_brain.FaceAlpha = 0.1;  % Muy transparente
    hold on;
    % Graficar el tumor en rojo (más opaco)
    [f_tumor, v_tumor] = isosurface(tumorFull, 0.5);
    p_tumor = patch('Faces', f_tumor, 'Vertices', v_tumor);
    p_tumor.FaceColor = 'red';
    p_tumor.EdgeColor = 'none';
    p_tumor.FaceAlpha = 0.7;  
    hold off;
    axis equal; view(3); camlight; lighting phong; rotate3d on;
    title('Cerebro Completo con Tumor Virtual');
    
else
    disp('No se añadió tumor al cerebro.');
    combinedT = fullBrainMask;
end

%% Visualización final del cerebro completo (por separado)
figure('Name','Cerebro Completo','Color','w');
[f_brain, v_brain] = isosurface(fullBrainMask, 0.5);
p_brain = patch('Faces', f_brain, 'Vertices', v_brain);
p_brain.FaceColor = [0.8 0.8 0.8];
p_brain.EdgeColor = 'none';
p_brain.FaceAlpha = 0.3;    % Transparencia para ver el interior
axis equal; view(3); camlight; lighting phong; rotate3d on;
title('Cerebro Completo');

end
