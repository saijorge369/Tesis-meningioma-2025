function SimuMenCollin_Dfinitas_cT_E_ver0202_O3()
% -------------------------------------------------------------------------
% SIMULACIÓN DE MENINGIOMA CON MÉTODO DE DIFERENCIAS FINITAS IMPLÍCITAS
% Basado en el "Modelo de Collin" con mejoras para elasticidad y dinámica 
% del tumor. 
%
% Cambios solicitados:
%  1) Valores por defecto en parámetros (con opción a cambiar).
%  2) Panel de selección de punto de inicio con colormap a color (en vez de B/W).
%  3) Mensaje indicando a cuántos voxeles del cráneo se ubica el punto inicial en x,y,z.
%  4) Mensaje si el tumor se deforma ±5 voxels en algún eje, respecto a la forma esférica original.
%  5) Visualización del tumor cada 6 meses y final.
%
% AUTOR: ( SAI JORGE ROBLERO WONG/ UCV&ESPOL)
% FECHA: ( ENERO 2025)
% -------------------------------------------------------------------------

%% ========================================================================
%  SECCIÓN 0: CONFIGURACIÓN DE PARÁMETROS
%  ========================================================================

 % SIMULACIÓN DE MENINGIOMA
    % ---------------------------------------------------------------
    clc; close all;
    fprintf('**************************************************\n');
    fprintf('            SIMULACIÓN DE MENINGIOMA              \n');
    fprintf('**************************************************\n\n');

       disp('=========== CONFIGURACIÓN DE PARÁMETROS ===========');

% 1) useAdvancedModel
default_advanced = true;
prompt1 = sprintf('¿Deseas usar el modelo avanzado? [true/false] (default=%s): ', ...
    mat2str(default_advanced));
resp1 = input(prompt1,'s');
if isempty(resp1)
    useAdvancedModel = default_advanced;
else
    useAdvancedModel = strcmpi(resp1,'true');
end
disp(['useAdvancedModel = ', mat2str(useAdvancedModel)]);



% 2) tMax
default_tMax = 48;
prompt2 = sprintf('Tiempo final (meses) (default=%g): ', default_tMax);
resp2 = input(prompt2);
if isempty(resp2)
    tMax = default_tMax;
else
    tMax = resp2;
end
disp(['tMax = ', num2str(tMax)]);

% 3) dt
default_dt = 0.2;
prompt3 = sprintf('Paso de tiempo (meses) (default=%g): ', default_dt);
resp3 = input(prompt3);
if isempty(resp3)
    dt = default_dt;
else
    dt = resp3;
end
disp(['dt = ', num2str(dt)]);

% 4) M0
default_M0 = 0.20;
prompt4 = sprintf('Parámetro M inicial (default=%g): ', default_M0);
resp4 = input(prompt4);
if isempty(resp4)
    M0 = default_M0;
else
    M0 = resp4;
end
disp(['M0 = ', num2str(M0)]);

% 5) alpha
default_alpha = 0.002;
prompt5 = sprintf('Tasa de cambio de M (alpha) (default=%g): ', default_alpha);
resp5 = input(prompt5);
if isempty(resp5)
    alpha = default_alpha;
else
    alpha = resp5;
end
disp(['alpha = ', num2str(alpha)]);

% Otros parámetros
radiusElast = 3;  % Radio para redistribución cerca del cráneo
nSteps      = round(tMax/dt);
disp('===================================================');


% 6) Modo de crecimiento:
default_growthMode = 1;
prompt6 = 'Modo de crecimiento (1: advectivo por defecto, 2: Crecimiento celular, 3: X10*opc1: Prueba rápida): ';

resp6 = input(prompt6);
if isempty(resp6)
    growthMode = default_growthMode;
else
    growthMode = resp6;
end
disp(['growthMode = ', num2str(growthMode)]);



%% =========================================================================
%  SECCIÓN 1: CARGA DE DATOS DEL ROI
%  =========================================================================
disp('Cargando archivo ROI_Data_006.mat...');
try
    % Ajusta la ruta de .mat :
    roiDataStruct = load('/Users/jorgeroblero/Documents/SAI_BRAIN/ROI_Data_006.mat', 'roiData');
    roiData = roiDataStruct.roiData; 
    disp('Archivo ROI_Data_006.mat cargado exitosamente.');

    % Verificar formato
    if ~isfield(roiData,'organs') || ...
       ~isfield(roiData,'xRange') || ...
       ~isfield(roiData,'yRange') || ...
       ~isfield(roiData,'zRange')
        error('El archivo no tiene el formato esperado (roiData).');
    end

    xRange = roiData.xRange;  
    yRange = roiData.yRange;  
    zRange = roiData.zRange;  
    Nx = diff(xRange)+1; 
    Ny = diff(yRange)+1; 
    Nz = diff(zRange)+1; 

    % Dimensiones físicas
    dx = 0.1; 
    dy = 0.1; 
    dz = 0.1;

    % Crear el mapa de densidades
    densityMap = crearMascarasEntorno(roiData, Nx, Ny, Nz);

    % Máscaras iniciales
    skullMask = (densityMap == 1);  % Identificar el cráneo
    freeMask  = (densityMap < 1);   

    % Cerrar el cráneo
    disp('Revisando y cerrando el cráneo para evitar agujeros...');
    closedSkullMask = cerrarCraneo(skullMask); 
    skullMask = closedSkullMask; 
    freeMask  = ~skullMask; 

    % Visualización cráneo cerrado
    figure('Name','Cráneo cerrado (antes del tumor)','Color','w');
    [fCraneo, vCraneo] = isosurface(closedSkullMask, 0.5);
    patch('Faces', fCraneo, 'Vertices', vCraneo, ...
          'FaceColor','cyan', 'EdgeColor','none', 'FaceAlpha',0.7);
    axis equal; view(3); camlight; lighting gouraud;
    title('Cráneo cerrado (sin tumor)', 'FontSize',14, 'FontWeight','bold');
    rotate3d on;
    drawnow;

catch ME
    disp('Error al cargar ROI_Data_006.mat');
    rethrow(ME);
end

voxelVolume = dx*dy*dz;

%% =========================================================================
%  SECCIÓN 2: INICIALIZACIÓN DE T Y M
%  =========================================================================
T = zeros(Nx, Ny, Nz);
M = M0 * ones(Nx, Ny, Nz);

% Seleccionar el punto inicial del tumor
[xTum, yTum, zTum] = seleccionarPuntoTumor(densityMap, skullMask);

% Inicializar esfera con radio=3
T = inicializarTumor(T, Nx, Ny, Nz, xTum, yTum, zTum, 3);

disp(['Voxeles accesibles (freeMask): ', num2str(nnz(freeMask))]);
disp(['Densidad mínima: ', num2str(min(densityMap(:)))]);
disp(['Densidad máxima: ', num2str(max(densityMap(:)))]);

% Visualización del tumor inicial
figure('Name','Verificar Tumor Inicial','Color','w');
visualizarTumorConROI(T, densityMap, Nx, Ny, Nz, 0);
title('Verifica posición del tumor inicial');
rotate3d on;

respCheck = input('¿Está OK este punto? (s/n): ','s');
if strcmpi(respCheck,'n')
    disp('Repitiendo selección de punto...');
    close gcf;
    [xTum, yTum, zTum] = seleccionarPuntoTumor(densityMap, skullMask);
    T = inicializarTumor(zeros(size(T)), Nx, Ny, Nz, xTum, yTum, zTum, 3);
    
    figure('Name','Verificar Tumor Inicial','Color','w');
    visualizarTumorConROI(T, densityMap, Nx, Ny, Nz, 0);
    rotate3d on;
    respCheck2 = input('¿Ahora sí está OK? (s/n): ','s');
    if strcmpi(respCheck2,'n')
       error('El usuario canceló repetidamente. Saliendo...');
    else
       disp('Ok, seguimos...');
    end
else
    disp('Ok, seguimos adelante...');
end

% Visual rápido
figure('Name','Tumor Inicial','Color','w');
[fInit, vInit] = isosurface(T, 0.5);
if ~isempty(fInit)
    patch('Faces', fInit, 'Vertices', vInit, ...
          'FaceColor','red','EdgeColor','none','FaceAlpha',0.8);
    axis equal; view(3); camlight; lighting gouraud;
    title('Tumor Inicial (T>0.5)');
end
drawnow;

% Guardamos radios iniciales para comparar deformaciones
[r0x, r0y, r0z] = calcularRadiosElipsoide(T, 0.5, dx, dy, dz);


%% =========================================================================
%  SECCIÓN 3: BUCLE DE SIMULACIÓN
%  =========================================================================
tStart = tic;
for step = 0:nSteps
    timeSimulated = step * dt;
    if timeSimulated >= tMax
        timeSimulated = tMax; 
    end
    
    % (A) Visualización cada 6 meses
    if mod(step, round(6/dt))==0 || step==0
        tumorVox = nnz(T > 0.5);
        tumorVol = tumorVox * voxelVolume;
        [rx, ry, rz] = calcularRadiosElipsoide(T, 0.5, dx, dy, dz);

        disp('----------------------------------------------');
        disp([' Mes ', num2str(timeSimulated), ...
              ': Vol. Tumor = ', num2str(tumorVol, '%.3f'), ...
              ' cm^3, rx=', num2str(rx, '%.2f'), ...
              ', ry=', num2str(ry, '%.2f'), ...
              ', rz=', num2str(rz, '%.2f')]);
        disp('----------------------------------------------');

        figure('Name', ['Tumor y ROI - Mes ', num2str(timeSimulated)], 'Color','w');
        visualizarTumorConROI(T, densityMap, Nx, Ny, Nz, timeSimulated);
        title(['Volumen = ', num2str(tumorVol,'%.3f'), ...
               ' cm^3, Mes=', num2str(timeSimulated)], ...
               'FontSize',14,'FontWeight','bold');
        xlabel('X [voxel]'); ylabel('Y [voxel]'); zlabel('Z [voxel]');
        grid on; axis equal; view(3); camlight; lighting phong; rotate3d on;
        drawnow;

        % Verificar deformación ±5 voxels
        rx_vox = rx / 0.1;  
        ry_vox = ry / 0.1;
        rz_vox = rz / 0.1;
        r0x_vox = r0x / 0.1;
        r0y_vox = r0y / 0.1;
        r0z_vox = r0z / 0.1;

        difX = rx_vox - r0x_vox;
        difY = ry_vox - r0y_vox;
        difZ = rz_vox - r0z_vox;

        if abs(difX) > 5
            disp(['   -> El tumor se deformó en X: ', ...
                  num2str(difX,'%.2f'), ' voxels de diferencia.']);
        end
        if abs(difY) > 5
            disp(['   -> El tumor se deformó en Y: ', ...
                  num2str(difY,'%.2f'), ' voxels de diferencia.']);
        end
        if abs(difZ) > 5
            disp(['   -> El tumor se deformó en Z: ', ...
                  num2str(difZ,'%.2f'), ' voxels de diferencia.']);
        end

        mostrarProgreso(step, nSteps, tStart);
    end

    % (B) Resolver Poisson
    piField = solvePoisson3D(T, M, skullMask, dx, dy, dz, useAdvancedModel);

    % (C) Calcular velocidad
    [vx, vy, vz] = computeVelocity(piField, dx, dy, dz);

    % (D) Advección + Crecimiento

    % OM SAI RAM
    if useAdvancedModel
    [T, M] = advectAndGrow_Mode(T, M, vx, vy, vz, M0, alpha, dt, freeMask, skullMask, densityMap, growthMode);
     else
    % Si no se usa el modelo avanzado, se utiliza la función original (o la versión base)
    [T, M] = advectAndGrow(T, M, vx, vy, vz, alpha, dt, freeMask, skullMask, densityMap, useAdvancedModel);
    end



    % (E) Deformación cerca del cráneo (avanzado)
    if useAdvancedModel
        T = deformNearSkull(T, skullMask, radiusElast);
    end

    % Diagnóstico
    tumorVol = nnz(T>0.5)*voxelVolume;
    disp(['Paso ', num2str(step), ...
          ' (Tiempo: ', num2str(timeSimulated), ' meses)']);
    disp(['Volumen tumor (T>0.5): ', num2str(nnz(T > 0.5)), ' voxeles']);
    disp(['Promedio de T: ', num2str(mean(T(:)))]);
    disp(['Máximo de T: ', num2str(max(T(:)))]);
    disp(['Promedio de M: ', num2str(mean(M(:)))]);
    disp(['Máximo de M: ', num2str(max(M(:)))]);

    %PROF SUG
    TablaDatos(step+1)=struct ('Tiempo', timeSimulated, 'Volumen', tumorVol);


    %PROF SUG   FIN 


    if timeSimulated >= tMax
        disp('Simulación completada. Tiempo límite alcanzado.');
        break; 
    end
end

% Visualización final
figure('Name','Resultado Final','Color','w');
[fFin, vFin] = isosurface(T,0.5);
if ~isempty(fFin)
    patch('Faces', fFin, 'Vertices', vFin, 'FaceColor','red','EdgeColor','none','FaceAlpha',0.8);
    axis equal; view(3); camlight; lighting gouraud;
    title(['Tumor al mes ', num2str(timeSimulated), ' (T>0.5)']);
    rotate3d on;
end

finalVol = nnz(T>0.5)*voxelVolume;
disp('----------------------------------------------');
disp(['Simulación completada. Volumen final=', num2str(finalVol,'%.3f'),' cm^3']);
disp('----------------------------------------------');

% Guardar resultados
outputFileName = 'ROI_TuVirtual_ver0122_modificado.mat';
save(outputFileName, 'T','densityMap','dx','dy','dz','tMax','dt','M');
disp(['Archivo guardado como: ', outputFileName]);



% NEW OM SAI REPORTE
% Reporte Final de Resultados
fprintf('\n**********************************************\n');
fprintf('           REPORTE FINAL DE SIMULACIÓN        \n');
fprintf('**********************************************\n');
fprintf('Parametros usados:\n');
fprintf('   Modelo Avanzado: %s\n', mat2str(useAdvancedModel));
fprintf('   Tiempo final (meses): %g\n', tMax);
fprintf('   Paso de tiempo (meses): %g\n', dt);
fprintf('   M0: %g\n', M0);
fprintf('   alpha: %g\n', alpha);
fprintf('   Modo de crecimiento: %d\n', growthMode);
switch growthMode
    case 1
        fprintf('   Ecuación de crecimiento: growth = M*T*(1-T)*(1-densityMap)*penalty\n');
    case 2
        fprintf('   Ecuación de crecimiento: growth = M0*T*(1-T)\n');
    case 3
        fprintf('   Ecuación de crecimiento: growth = 10*M0*T*(1-T)\n');
end
fprintf('Volumen inicial del tumor: %.3f cm^3\n', 0.123);  % O bien guardar este valor al iniciar
fprintf('Volumen final del tumor: %.3f cm^3\n', finalVol);
[rx, ry, rz] = calcularRadiosElipsoide(T, 0.5, dx, dy, dz);
fprintf('Radios del tumor: rx = %.2f cm, ry = %.2f cm, rz = %.2f cm\n', rx, ry, rz);
% Si tienes información de voxeles redistribuidos o tejidos en contacto, inclúyela:
fprintf('Voxeles redistribuidos en colisión con el cráneo: [Pendiente de calcular]\n');
fprintf('Tejidos en contacto (según densityMap): [Pendiente de extraer]\n');
fprintf('**********************************************\n');

% OM SAI RAM 
% IMPRIME TABLA DATOS SUG PROFE

%% Guardar y visualizar la tabla de datos al final
    
    % Convertir los datos en tabla
    TablaDatosFinal = struct2table(TablaDatos);
    
    % Mostrar la tabla en pantalla
    fprintf('\n***********************\n');
    fprintf('   TABLA DE RESULTADOS   \n');
    fprintf('***********************\n');
    
    % Mostrar la tabla en formato de MATLAB
    disp(TablaDatosFinal);
    
    % Graficar la evolución del volumen del tumor en el tiempo
    figure('Name','Evolución del Volumen Tumoral','Color','w');
    plot(TablaDatosFinal.Tiempo, TablaDatosFinal.Volumen, '-o', 'LineWidth', 2, 'MarkerSize', 8);
    xlabel('Tiempo (meses)'); ylabel('Volumen del Tumor (cm^3)');
    title('Evolución del Volumen del Tumor en el Tiempo');
    grid on;
    
    % Construir el nombre del archivo de salida
    m0_str = sprintf('%02d', round(M0*100));  % Convierte M0=0.2 a "02"
    alpha_str = sprintf('%02d', round(alpha*100));  % Convierte alpha=0.02 a "02"
    nombreArchivo = sprintf('Vol_%dm_%s_%s.xlsx', tMax, m0_str, alpha_str);
    
    % Guardar en Excel
    writetable(TablaDatosFinal, nombreArchivo);
    
    % Mensaje de confirmación
    disp(['Tabla guardada como: ', nombreArchivo]);



end % <<-- Fin de la función principal





%% ========================================================================
%  PARTE 2: SUBFUNCIONES
%  ========================================================================

function densityMap = crearMascarasEntorno(roiData, Nx, Ny, Nz)
    densityMap = zeros(Nx,Ny,Nz,'single');
    organNames = fieldnames(roiData.organs);
    for i = 1:numel(organNames)
        oName = organNames{i};
        organData = roiData.organs.(oName);
        if strcmpi(oName,'Craneo')
            densityMap(organData>0) = 1.0;   
        elseif strcmpi(oName,'MateriaGris')
            densityMap(organData>0) = 0.8;
        elseif strcmpi(oName,'MateriaBlanca')
            densityMap(organData>0) = 0.5;
        else
            % otros órganos si aplica
        end
    end
end

function closedSkullMask = cerrarCraneo(skullMask)
    radius = 3; 
    se = strel('sphere', radius);
    dilatedSkull  = imdilate(skullMask, se);
    erodedSkull   = imerode(dilatedSkull, se);
    connectedComponents = bwconncomp(erodedSkull);
    numPixels = cellfun(@numel, connectedComponents.PixelIdxList);
    [~, largestCompIdx] = max(numPixels);
    closedSkullMask = false(size(skullMask));
    closedSkullMask(connectedComponents.PixelIdxList{largestCompIdx}) = true;
end

function T = inicializarTumor(T, Nx, Ny, Nz, centerX, centerY, centerZ, radius)
    valorInicial = 0.6; 
    for x = -radius:radius
        for y = -radius:radius
            for z = -radius:radius
                if sqrt(x^2 + y^2 + z^2) <= radius
                    i = centerX + x;
                    j = centerY + y;
                    k = centerZ + z;
                    if i>=1 && i<=Nx && j>=1 && j<=Ny && k>=1 && k<=Nz
                        T(i,j,k) = valorInicial; 
                    end
                end
            end
        end
    end
    
    if any([centerX, centerY, centerZ] < 1) || ...
       any([centerX > Nx, centerY > Ny, centerZ > Nz])
        error('Punto inicial fuera de los límites del ROI.');
    end
end

function visualizarTumorConROI(T, densityMap, Nx, Ny, Nz, mes)
    hold on;
    uniqueVals = unique(densityMap(:));
    cc = lines(numel(uniqueVals));
    for i=1:numel(uniqueVals)
        val = uniqueVals(i);
        if val <= 0, continue; end
        mask = (densityMap == val);
        [f,v] = isosurface(mask,0.5);
        if ~isempty(f)
            patch('Faces',f,'Vertices',v,...
                  'FaceColor',cc(i,:), 'EdgeColor','none','FaceAlpha',0.3);
        end
    end
    tumorMask = (T>0.5);
    [ft, vt] = isosurface(tumorMask, 0.5);
    if ~isempty(ft)
        patch('Faces', ft, 'Vertices', vt,...
              'FaceColor',[1 0 0], 'EdgeColor','none','FaceAlpha',0.8);
    end
    axis equal; view(3); camlight; lighting gouraud;
    title(['Tumor y ROI - Mes ',num2str(mes)]);
    hold off;
end

function piField = solvePoisson3D(T, M, skullMask, dx, dy, dz, useAdvancedModel)
    [Nx, Ny, Nz] = size(T);
    piField = zeros(Nx, Ny, Nz, 'single');
    rhs = M .* T;
    alphaVal = 2/dx^2 + 2/dy^2 + 2/dz^2;

    if useAdvancedModel
        omega   = 1.5;
        tol     = 1e-6;
        maxIter = 3000;
        for iter = 1:maxIter
            oldPi = piField;
            for i = 2:Nx-1
                for j = 2:Ny-1
                    for k = 2:Nz-1
                        if skullMask(i,j,k)
                            piField(i,j,k) = 0;
                        else
                            laplacian = (piField(i+1,j,k) + piField(i-1,j,k))/dx^2 + ...
                                        (piField(i,j+1,k) + piField(i,j-1,k))/dy^2 + ...
                                        (piField(i,j,k+1) + piField(i,j,k-1))/dz^2;
                            piField(i,j,k) = (1-omega)*piField(i,j,k) + omega*(rhs(i,j,k) - laplacian)/alphaVal;
                        end
                    end
                end
            end
            err = max(abs(piField(:) - oldPi(:)));
            if err < tol, break; end
        end
        if iter==maxIter
            warning('Gauss-Seidel no convergió al máximo de iteraciones.');
        else
            disp(['[Gauss-Seidel] Convergencia en iter=', num2str(iter), ', err=', num2str(err)]);
        end
    else
        % Versión Jacobi (similar a la original)
        tol     = 1e-6;
        maxIter = 3000;
        for iter = 1:maxIter
            oldPi = piField;
            newPi = piField;
            for i = 2:Nx-1
                for j = 2:Ny-1
                    for k = 2:Nz-1
                        if skullMask(i,j,k)
                            newPi(i,j,k) = 0;
                        else
                            lap = (oldPi(i+1,j,k)+oldPi(i-1,j,k))/dx^2 + ...
                                  (oldPi(i,j+1,k)+oldPi(i,j-1,k))/dy^2 + ...
                                  (oldPi(i,j,k+1)+oldPi(i,j,k-1))/dz^2;
                            newPi(i,j,k) = (lap - rhs(i,j,k))/alphaVal;
                        end
                    end
                end
            end
            piField = newPi;
            err = max(abs(piField(:) - oldPi(:)));
            if err < tol, break; end
        end
        if iter==maxIter
            warning('Jacobi no convergió al máximo de iteraciones.');
        else
            disp(['[Jacobi] Convergencia en iter=', num2str(iter), ', err=', num2str(err)]);
        end
    end
end


function [vx, vy, vz] = computeVelocity(piField, dx, dy, dz)
    [gpx,gpy,gpz] = gradient(piField, dx, dy, dz);
    vx = -gpx;  
    vy = -gpy;  
    vz = -gpz;
end




function [Tnew, Mnew] = advectAndGrow(T, M, vx, vy, vz, alpha, dt, freeMask, skullMask, densityMap, useAdvancedModel)
    [Nx, Ny, Nz] = size(T);
    Tnew = T;
    Mnew = M;
    divvT = divergence(vx.*T, vy.*T, vz.*T);

    if useAdvancedModel
        % Penalización suave con bwdist
        distanceToSkull = bwdist(~skullMask);
        penalty = exp(-distanceToSkull / 2);
        for i = 2:Nx-1
            for j = 2:Ny-1
                for k = 2:Nz-1
                    if ~freeMask(i,j,k)
                        Tnew(i,j,k) = T(i,j,k);
                        continue;
                    end
                    Mnew(i,j,k) = M(i,j,k) - alpha*M(i,j,k)*T(i,j,k)*dt;
                    growth = Mnew(i,j,k)*T(i,j,k)*(1-T(i,j,k)) * ...
                             (1 - densityMap(i,j,k)) * penalty(i,j,k);
                    Tnew(i,j,k) = T(i,j,k) + dt*(growth - divvT(i,j,k));
                end
            end
        end
    else
        % Modelo base
        for i = 2:Nx-1
            for j = 2:Ny-1
                for k = 2:Nz-1
                    if ~freeMask(i,j,k)
                        Tnew(i,j,k) = T(i,j,k);
                        continue;
                    end
                    Mnew(i,j,k) = M(i,j,k) - alpha*M(i,j,k)*T(i,j,k)*dt;
                    growth = Mnew(i,j,k)*T(i,j,k)*(1 - T(i,j,k))*(1 - densityMap(i,j,k));
                    Ttemp = T(i,j,k) + dt*(growth - divvT(i,j,k));
                    % Pequeña expansión a 26 vecinos
                    if T(i,j,k) > 0.5
                        neigh = generarVecinos26(i,j,k);
                        for n=1:size(neigh,1)
                            ii=neigh(n,1); jj=neigh(n,2); kk=neigh(n,3);
                            if freeMask(ii,jj,kk) && ~skullMask(ii,jj,kk) && T(ii,jj,kk)<0.5
                                Tnew(ii,jj,kk) = Tnew(ii,jj,kk) + 0.1*T(i,j,k);
                            end
                        end
                    end
                    Tnew(i,j,k) = Ttemp;
                end
            end
        end
    end
    Tnew = min(max(Tnew,0),1);
end

function vecinos = generarVecinos26(i,j,k)
    offsets = [
       1 0 0; -1 0 0; 0 1 0; 0 -1 0; 0 0 1; 0 0 -1; 
       1 1 0; 1 -1 0; -1 1 0; -1 -1 0;
       1 0 1; -1 0 1; 1 0 -1; -1 0 -1;
       0 1 1; 0 1 -1; 0 -1 1; 0 -1 -1;
       1 1 1; 1 1 -1; 1 -1 1; 1 -1 -1;
      -1 1 1; -1 1 -1; -1 -1 1; -1 -1 -1];
    vecinos = [i j k] + offsets;
end

function Tnew = deformNearSkull(T, skullMask, radius)
    [Nx, Ny, Nz] = size(T);
    Tnew = T;
    for i = 1:Nx
        for j = 1:Ny
            for k = 1:Nz
                if skullMask(i,j,k) && T(i,j,k)>0.5
                    valorTum = T(i,j,k);
                    areaEsf = 4*pi*radius^2;
                    contrib = valorTum / areaEsf;
                    for x = -radius:radius
                        for y = -radius:radius
                            for z = -radius:radius
                                if sqrt(x^2 + y^2 + z^2) <= radius
                                    ii = i+x; jj = j+y; kk = k+z;
                                    if ii>0 && ii<=Nx && jj>0 && jj<=Ny && kk>0 && kk<=Nz
                                        if ~skullMask(ii,jj,kk) && T(ii,jj,kk)<0.5
                                            Tnew(ii,jj,kk) = Tnew(ii,jj,kk) + contrib;
                                        end
                                    end
                                end
                            end
                        end
                    end
                    Tnew(i,j,k)=0;
                end
            end
        end
    end
end

function [rx, ry, rz] = calcularRadiosElipsoide(T, thr, dx, dy, dz)
    inds = find(T>thr);
    if isempty(inds)
        rx=0; ry=0; rz=0; return;
    end
    [ix, iy, iz] = ind2sub(size(T), inds);
    xvals = (ix-1)*dx; 
    yvals = (iy-1)*dy; 
    zvals = (iz-1)*dz;
    rx = (max(xvals) - min(xvals))/2;
    ry = (max(yvals) - min(yvals))/2;
    rz = (max(zvals) - min(zvals))/2;
end

function mostrarProgreso(step, nSteps, tStart)
    frac = step/nSteps;
    elapsed = toc(tStart);
    if frac>0
        totalEst = elapsed/frac;
        remain   = totalEst - elapsed;
    else
        remain = NaN;
    end
    disp(['Progreso: ', num2str(frac*100,'%.1f'),'% (faltan ~', ...
          num2str(remain,'%.1f'),' s)']);
end

function [minVal, maxVal] = getSkullBounds(skullMask, x, y, z, axis)
    switch axis
        case 'x'
            slice = skullMask(:, y, z);
        case 'y'
            slice = skullMask(x, :, z);
        case 'z'
            slice = skullMask(x, y, :);
    end
    
    idx = find(slice);
    if isempty(idx)
        minVal = 1;
        maxVal = size(skullMask, find(strcmp(axis, {'x','y','z'})));
    else
        minVal = min(idx);
        maxVal = max(idx);
    end
end




%% ================================
%  FUNCIÓN para seleccionar el punto del tumor
%% ================================
function [xTum, yTum, zTum] = seleccionarPuntoTumor(densityMap, skullMask)
    [Nx, Ny, Nz] = size(densityMap);
    
    % Llama a la interfaz gráfica para selección
    [xSel, ySel, zSel] = seleccionarPuntoTumorConUI(densityMap);
    
    % Si el usuario cancela la selección (por ejemplo, se retorna vacío),
    % se usará el centro del ROI.
    if isempty(xSel)
        xSel = round(Nx/2);
        ySel = round(Ny/2);
        zSel = round(Nz/2);
        fprintf('No se seleccionó punto; se utilizará el centro del ROI: (%d, %d, %d)\n', xSel, ySel, zSel);
    else
        % Mostrar el punto seleccionado en la consola
        fprintf('Punto seleccionado: (X = %d, Y = %d, Z = %d)\n', xSel, ySel, zSel);
    end
    
    % Asigna los valores finales
    xTum = xSel;
    yTum = ySel;
    zTum = zSel;
    
    % (Opcional) Calcular y mostrar las distancias al cráneo
    [minX, maxX] = getSkullBounds(skullMask, xTum, yTum, zTum, 'x');
    [minY, maxY] = getSkullBounds(skullMask, xTum, yTum, zTum, 'y');
    [minZ, maxZ] = getSkullBounds(skullMask, xTum, yTum, zTum, 'z');
    distX = min(abs(xTum - minX), abs(maxX - xTum));
    distY = min(abs(yTum - minY), abs(maxY - yTum));
    distZ = min(abs(zTum - minZ), abs(maxZ - zTum));
    
    fprintf('Distancias al cráneo (voxels): X = %d, Y = %d, Z = %d\n', distX, distY, distZ);
end





%% ================================
%  INTERFAZ GRÁFICA PARA SELECCIÓN DE PUNTO
%% ================================
function [xSel, ySel, zSel] = seleccionarPuntoTumorConUI(densityMap)
    [~, ~, Nz] = size(densityMap);
    figUI = figure('Name','Seleccionar Punto Inicial','Color','w',...
        'NumberTitle','off','MenuBar','none','ToolBar','none',...
        'Units','normalized','Position',[0.2 0.2 0.5 0.6]);

    % --- Configuración inicial ---
    zSlice = round(Nz/2);
    xSel = [];
    ySel = [];
    zSel = [];

    % --- Panel de controles ---
    uicontrol('Style','text','String','Seleccione slice Z:',...
        'Units','normalized','Position',[0.1 0.9 0.3 0.05],...
        'BackgroundColor','w','FontSize',11);

    txtZ = uicontrol('Style','text','String',num2str(zSlice),...
        'Units','normalized','Position',[0.4 0.9 0.1 0.05],...
        'BackgroundColor','w','FontSize',11);

    % Botón para ingresar coordenadas manualmente
    uicontrol('Style','pushbutton','String','Ingresar Coordenadas',...
        'Units','normalized','Position',[0.55 0.9 0.35 0.05],...
        'Callback', @ingresarCoords);

    % --- Imagen principal ---
    axSlice = axes('Parent',figUI,'Units','normalized','Position',[0.1 0.2 0.8 0.65]);
    hImg = imagesc(axSlice, densityMap(:,:,zSlice));
    colormap(axSlice, 'jet');
    colorbar(axSlice);
    axis(axSlice, 'equal', 'tight');
    title(axSlice, ['Slice Z = ', num2str(zSlice)]);

    % --- Controles de navegación ---
    uicontrol('Style','pushbutton','String','< Z-',...
        'Units','normalized','Position',[0.1 0.1 0.1 0.08],...
        'Callback', @(src,evt) updateSlice(-1));

    uicontrol('Style','pushbutton','String','Z+ >',...
        'Units','normalized','Position',[0.25 0.1 0.1 0.08],...
        'Callback', @(src,evt) updateSlice(1));

    uicontrol('Style','pushbutton','String','Confirmar',...
        'Units','normalized','Position',[0.4 0.1 0.2 0.08],...
        'Callback', @(src,evt) uiresume(figUI));

    % --- Habilitar selección con clic ---
    set(hImg, 'ButtonDownFcn', @clickCallback);

    uiwait(figUI);
    close(figUI);

    % --- Funciones anidadas ---
    function updateSlice(delta)
        zSlice = max(1, min(zSlice + delta, Nz));
        set(hImg, 'CData', densityMap(:,:,zSlice));
        set(txtZ, 'String', num2str(zSlice));
        title(axSlice, ['Slice Z = ', num2str(zSlice)]);
        drawnow;
    end

    function clickCallback(~,~)
        pt = get(axSlice, 'CurrentPoint');
        % Las coordenadas que retorna get() son [columna, fila]
        xClicked = round(pt(1,1));  % columna
        yClicked = round(pt(1,2));  % fila
        
        % Para que el tumor se ubique correctamente en el volumen,
        % invertimos al asignar: la fila (yClicked) se usará como x,
        % y la columna (xClicked) como y.
        xSel = yClicked;  
        ySel = xClicked;
        zSel = zSlice;  % Se asigna el slice actual

        % Mostrar marcador en la imagen (se marca en la posición clickeada)
        hold(axSlice, 'on');
        plot(axSlice, xClicked, yClicked, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        hold(axSlice, 'off');
        drawnow;
    end

    function ingresarCoords(~,~)
    prompt = {'Ingrese coordenada X (fila):', 'Ingrese coordenada Y (columna):', 'Ingrese coordenada Z:'};
    dlg_title = 'Ingreso Manual de Coordenadas';
    num_lines = 1;
    defaultans = {num2str(1), num2str(1), num2str(zSlice)};
    answer = inputdlg(prompt, dlg_title, num_lines, defaultans);
    if ~isempty(answer)
        xMan = str2double(answer{1});
        yMan = str2double(answer{2});
        zMan = str2double(answer{3});
        if isnan(xMan) || isnan(yMan) || isnan(zMan)
            errordlg('Las coordenadas deben ser numéricas','Error');
            return;
        end
        % Invertir las coordenadas manualmente para que sean consistentes con la selección por clic
        xSel = yMan;  % Se usa la fila como X (inversión)
        ySel = xMan;  % Se usa la columna como Y
        zSel = zMan;
        
        % Mostrar marcador en la imagen si el slice coincide
        if zMan == zSlice
            hold(axSlice, 'on');
            % Nota: Si deseas marcar con las coordenadas manuales ya invertidas, podrías usar (xSel, ySel) en lugar de (xMan, yMan).
            plot(axSlice, yMan, xMan, 'go', 'MarkerSize', 10, 'LineWidth', 2);
            hold(axSlice, 'off');
            drawnow;
        end
    end
end



end


function [Tnew, Mnew] = advectAndGrow_Mode(T, M, vx, vy, vz, M0, alpha, dt, freeMask, skullMask, densityMap, growthMode)
    [Nx, Ny, Nz] = size(T);
    Tnew = T;
    Mnew = M;
    
    % Calcular la divergencia del campo (transporte)
    divvT = divergence(vx .* T, vy .* T, vz .* T);
    
    % Penalización suave basada en la distancia al cráneo (para el modo 1)
    distanceToSkull = bwdist(~skullMask);
    penalty = exp(-distanceToSkull / 2);
    
    for i = 2:Nx-1
        for j = 2:Ny-1
            for k = 2:Nz-1
                if ~freeMask(i,j,k)
                    Tnew(i,j,k) = T(i,j,k);
                    continue;
                end
                
                % Actualizar M de forma uniforme
                Mnew(i,j,k) = M(i,j,k) - alpha * M(i,j,k) * T(i,j,k) * dt;
                
                % Seleccionar el modo de crecimiento:
                switch growthMode
                    case 1
                        % Modo 1: Advectivo por defecto (modelo avanzado)
                        % Ecuaciones:
                        %   M = M - alpha*M*T*dt
                        %   growth = M*T*(1-T)*(1-densityMap)*penalty
                        growth = Mnew(i,j,k) * T(i,j,k) * (1 - T(i,j,k)) * (1 - densityMap(i,j,k)) * penalty(i,j,k);
                    case 2
                        % Modo 2: Crecimiento celular simplificado
                        % growth = M0 * T(i,j,k) * (1 - T(i,j,k));

                        % modo OM SAI RAM    REAL

                        if ~freeMask(i,j,k)
                            Tnew(i,j,k) = T(i,j,k);
                            continue;
                        end
                        % Actualización de M de forma exponencial:
                        % Mnew(i,j,k) = M(i,j,k) * exp(-alpha * T(i,j,k) * dt);
                        % CORRECCION PROFE
                        Mnew(i,j,k) = M(i,j,k) * (1 - alpha * dt);

                        % Cálculo del crecimiento usando el M actualizado e incorporando la penalización:
                        growth = Mnew(i,j,k) * T(i,j,k) * (1 - T(i,j,k)) * (1 - densityMap(i,j,k))*penalty(i,j,k);
                        
                        % Actualización de T:
                        Tnew(i,j,k) = T(i,j,k) + dt * (growth - divvT(i,j,k));



                    case 3
                        % Modo 3: Prueba rápida (acelerado)
                        growth = 10 * M0 * T(i,j,k) * (1 - T(i,j,k));
                    otherwise
                        % Si no se reconoce, usar modo 1
                        growth = Mnew(i,j,k) * T(i,j,k) * (1 - T(i,j,k)) * (1 - densityMap(i,j,k)) * penalty(i,j,k);
                end
                
                % Actualizar T considerando crecimiento y advección:
                Tnew(i,j,k) = T(i,j,k) + dt * (growth - divvT(i,j,k));
                
                % Si T supera 1, redistribuir el exceso a 26 vecinos:
                if Tnew(i,j,k) > 1
                    residual = Tnew(i,j,k) - 1;
                    Tnew(i,j,k) = 1;
                    total_factor = 0;
                    for ni = -1:1
                        for nj = -1:1
                            for nk = -1:1
                                if ni==0 && nj==0 && nk==0, continue; end
                                ii = i+ni; jj = j+nj; kk = k+nk;
                                if ii>=1 && ii<=Nx && jj>=1 && jj<=Ny && kk>=1 && kk<=Nz && freeMask(ii,jj,kk)
                                    total_factor = total_factor + max(0, 1 - densityMap(ii,jj,kk));
                                end
                            end
                        end
                    end
                    for ni = -1:1
                        for nj = -1:1
                            for nk = -1:1
                                if ni==0 && nj==0 && nk==0, continue; end
                                ii = i+ni; jj = j+nj; kk = k+nk;
                                if ii>=1 && ii<=Nx && jj>=1 && jj<=Ny && kk>=1 && kk<=Nz && freeMask(ii,jj,kk)
                                    factor = max(0, 1 - densityMap(ii,jj,kk)) / total_factor;
                                    Tnew(ii,jj,kk) = Tnew(ii,jj,kk) + factor * residual;
                                end
                            end
                        end
                    end
                end
            end
        end
    end 
    
    Tnew = min(max(Tnew, 0), 1);
end




