% *****************************************************************
% Descripción:
%   Este código realiza el ajuste de cuatro modelos (Exponencial, 
%   Logístico, Gompertz y Potencia(Vaju)) a los datos obtenidos de un 
%   archivo Excel. Se generan una tabla con los valores de R² y 
%   gráficos individuales y combinados para cada paciente. El 
%   usuario debe ingresar los ID de los pacientes (por ejemplo, 
%   "48, 222") y luego elegir interactivamente:
%       1. Si desea unir (conectar) los puntos observados (default no).
%       2. Si desea guardar los gráficos (default no).
%   Además, al seleccionar un ID para graficar se muestra una tabla con 
%   los parámetros ajustados para cada modelo.
%
% Restricciones:
%   - Se requiere MATLAB con Optimization Toolbox para lsqcurvefit.
%   - El archivo Excel debe contener las columnas de tiempo (T0 a T16)
%     y volumen (V0 a V16) con datos numéricos.
%
% Autor: OM SAI RAM. JORGE ROBLERO WONG
% Fecha: Febrero 2025
% *****************************************************************

clc;
clear;
close all;

%% Información inicial y selección del archivo
archivoPath = '/Users/jorgeroblero/Documents/mening-2.xlsx'; 
fprintf('Se usará el archivo: %s\n', archivoPath);
pause(1);  % Pausa para que el usuario lea la información

%% Lectura de datos
% Leer datos del archivo Excel asegurándose de que todas las columnas sean numéricas
opts = detectImportOptions(archivoPath);
for i = 1:length(opts.VariableNames)
    opts = setvartype(opts, opts.VariableNames{i}, 'double');
end
data = readtable(archivoPath, opts);

% Definir las columnas de tiempo y volumen
T_cols = {'T0', 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9', 'T10', 'T11', 'T12', 'T13', 'T14', 'T15', 'T16'};
V_cols = {'V0', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'V8', 'V9', 'V10', 'V11', 'V12', 'V13', 'V14', 'V15', 'V16'};

%% Solicitar IDs de pacientes
patientIDs_input = input('Ingrese los ID de los pacientes separados por comas (ejemplo: 48, 222, 242): ', 's');
patientIDs = str2num(patientIDs_input);  %#ok<ST2NM>
if isempty(patientIDs)
    error('No se ingresaron IDs válidos.');
end

%% Inicialización de resultados
numModels = 4;
numPatients = length(patientIDs);

% 'ajustes' guardará los parámetros ajustados para cada modelo y paciente
ajustes = cell(numModels, numPatients);
% 'resultados' guardará el valor de R² para cada modelo y paciente.
resultados = array2table(zeros(numModels, numPatients), 'VariableNames', cellstr(string(patientIDs)), ...
                          'RowNames', {'Exponencial', 'Logístico', 'Gompertz', 'Potencia'});

%% Definición de modelos
exponencial = @(p, t) p(1) * exp(p(2) * t);
% Se elimina el modelo de Potencia original
logistico  = @(p, t) p(1) ./ (1 + exp(-p(2) * (t - p(3))));
gompertz   = @(p, t) p(1) * exp(-p(2) * exp(-p(3) * t));
% En vaju_model se reemplaza min(T) por min(t) para que use el mínimo del vector de tiempo local.
vaju_model = @(p, t) ((p(2) * (t - min(t)) * (1 - p(3)) + p(1)^(1 - p(3))).^(1/(1 - p(3))));

modelos = {exponencial, logistico, gompertz, vaju_model};
nombres_modelos = {'Exponencial', 'Logístico', 'Gompertz', 'Potencia'};

%% Ajuste de modelos para cada paciente
for i = 1:numPatients
    pid = patientIDs(i);
    patientData = data(data.ID == pid, :);
    
    % Extraer los datos de tiempo y volumen
    T = nan(height(patientData), length(T_cols));
    V = nan(height(patientData), length(V_cols));
    for k = 1:length(T_cols)
        T(:, k) = patientData{:, T_cols{k}};
        V(:, k) = patientData{:, V_cols{k}};
    end
    % Seleccionar únicamente los datos válidos (no NaN)
    validIndices = ~isnan(T) & ~isnan(V);
    T = T(validIndices);
    V = V(validIndices);
    if isempty(T) || isempty(V)
        warning('Paciente %d: No se encontraron datos válidos.', pid);
        continue;
    end
    
    % Valores iniciales para cada modelo
    p0s = { [1, 0.1], ...                    % Exponencial
            [max(V), 0.1, median(T)], ...      % Logístico
            [max(V), 1, 0.05], ...             % Gompertz (parámetros iniciales mejorados)
            [V(1), 0.1, 0.5] };                % Potencia(Vaju) (anterior VAJU)

    % Ajustar cada modelo y guardar parámetros y R²
    for j = 1:numModels
        [p, r2] = ajustar_modelos(modelos{j}, T, V, p0s{j});
        ajustes{j, i} = p;
        if r2 < 0, r2 = 0; end
        resultados{j, i} = r2;
    end
end

% Mostrar la tabla de resultados (R²)
disp('Resultados de ajuste (R²):');
disp(resultados);
writetable(resultados, 'resultados_ajuste.xlsx', 'WriteRowNames', true);

%% Menú para graficar y mostrar parámetros
while true
    plotID = input('Ingrese el ID que desea graficar (o 0 para salir): ');
    if plotID == 0
        disp('Saliendo del programa...');
        break;
    end
    idx = find(patientIDs == plotID, 1);
    if isempty(idx)
        disp('ID no encontrado en los análisis. Intente nuevamente.');
        continue;
    end
    
    % Preguntar si se desean unir (conectar) los puntos observados.
    joinObserved = input('¿Desea unir los puntos observados? (default no, s/n): ', 's');
    if isempty(joinObserved)
        joinObserved = 'n';
    end
    if lower(joinObserved) == 's'
        observedStyle = 'ko-';
    else
        observedStyle = 'ko';
    end
    
    % Preguntar si se desean guardar los gráficos.
    saveGraphs = input('¿Desea guardar los gráficos? (default no, s/n): ', 's');
    if isempty(saveGraphs)
        saveGraphs = 'n';
    end
    
    % Extraer datos del paciente seleccionado
    patientData = data(data.ID == plotID, :);
    T = nan(height(patientData), length(T_cols));
    V = nan(height(patientData), length(V_cols));
    for k = 1:length(T_cols)
        T(:, k) = patientData{:, T_cols{k}};
        V(:, k) = patientData{:, V_cols{k}};
    end
    validIndices = ~isnan(T) & ~isnan(V);
    T = T(validIndices);
    V = V(validIndices);
    if isempty(T) || isempty(V)
        disp('No hay datos suficientes para graficar.');
        continue;
    end

    %% Gráficas separadas para cada modelo
    colors = lines(numModels);  % Paleta de colores por modelo
    colors(2,:) = [0, 0, 0.5];    % Logístico: azul oscuro
    colors(4,:) = [0, 0.5, 0];    % Potencia(Vaju): verde oscuro

    for j = 1:numModels
        figure('Color', 'white'); 
        hold on;
        % Graficar los datos observados según la opción elegida
        plot(T, V, observedStyle, 'MarkerSize', 10, 'DisplayName', 'Datos Observados');
        
        % Graficar el modelo ajustado (si se obtuvo ajuste)
        params = ajustes{j, idx};
        if isempty(params)
            plot(T, NaN(size(T)), '--', 'LineWidth', 2, 'DisplayName', sprintf('%s (no converge)', nombres_modelos{j}));
        else
            V_ajustado = modelos{j}(params, T);
            % Línea discontinua del modelo y puntos ajustados con "+"
            plot(T, V_ajustado, '--', 'LineWidth', 2, 'Color', colors(j,:), 'DisplayName', nombres_modelos{j});
            plot(T, V_ajustado, '+', 'MarkerSize', 12, 'LineWidth', 2, 'Color', colors(j,:), 'DisplayName', [nombres_modelos{j} ' Puntos']);
        end

        xlabel('Tiempo (meses)', 'FontSize', 16, 'FontWeight', 'bold');
        ylabel('Volumen (cm³)', 'FontSize', 16, 'FontWeight', 'bold');
        title(sprintf('Ajuste del modelo %s para el paciente ID %d', nombres_modelos{j}, plotID), 'FontSize', 18, 'FontWeight', 'bold');
        legend('show', 'FontSize', 14, 'Location', 'northwest');
        grid on;
        hold off;
        
        if lower(saveGraphs) == 's'
            saveas(gcf, sprintf('ajuste_%s_ID%d.png', nombres_modelos{j}, plotID));
        end
    end
    
    %% Gráfica combinada de los 4 modelos con los datos observados
    figure('Color', 'white'); 
    hold on;
    plot(T, V, observedStyle, 'MarkerSize', 10, 'DisplayName', 'Datos Observados');
    for j = 1:numModels
        params = ajustes{j, idx};
        if isempty(params)
            plot(T, NaN(size(T)), '--', 'LineWidth', 2, 'Color', colors(j,:), 'DisplayName', sprintf('%s (no converge)', nombres_modelos{j}));
        else
            V_ajustado = modelos{j}(params, T);
            plot(T, V_ajustado, '--', 'LineWidth', 2, 'Color', colors(j,:), 'DisplayName', nombres_modelos{j});
            plot(T, V_ajustado, '+', 'MarkerSize', 12, 'LineWidth', 2, 'Color', colors(j,:), 'DisplayName', [nombres_modelos{j} ' Puntos']);
        end
    end
    xlabel('Tiempo (meses)', 'FontSize', 16, 'FontWeight', 'bold');
    ylabel('Volumen (cm³)', 'FontSize', 16, 'FontWeight', 'bold');
    title(sprintf('Ajuste de los 4 modelos para el paciente ID %d', plotID), 'FontSize', 18, 'FontWeight', 'bold');
    legend('show', 'FontSize', 14, 'Location', 'northwest');
    grid on;
    hold off;
    
    if lower(saveGraphs) == 's'
        saveas(gcf, sprintf('ajuste_Todos_ID%d.png', plotID));
    end
    
    %% Mostrar tabla de parámetros para el paciente seleccionado
    paramTable = cell(numModels, 2);
    for j = 1:numModels
        p = ajustes{j, idx};
        if isempty(p)
            paramStr = 'No converge';
        else
            if length(p) == 2
                paramStr = sprintf('a = %.5f, b = %.5f', p(1), p(2));
            elseif length(p) == 3
                if strcmp(nombres_modelos{j}, 'Logístico')
                    paramStr = sprintf('a = %.5f, beta = %.5f, t0 = %.5f', p(1), p(2), p(3));
                elseif strcmp(nombres_modelos{j}, 'Gompertz')
                    paramStr = sprintf('a = %.5f, beta = %.5f, gamma = %.5f', p(1), p(2), p(3));
                elseif strcmp(nombres_modelos{j}, 'Potencia')
                    paramStr = sprintf('a = %.5f, beta = %.5f, gamma = %.5f', p(1), p(2), p(3));
                else
                    paramStr = sprintf('%.5f, %.5f, %.5f', p(1), p(2), p(3));
                end
            else
                paramStr = sprintf('Parámetros: %s', mat2str(p, 5));
            end
        end
        paramTable{j, 1} = nombres_modelos{j};
        paramTable{j, 2} = paramStr;
    end
    paramsTable = cell2table(paramTable, 'VariableNames', {'Modelo', 'Parámetros'});
    disp('Parámetros de ajuste para el paciente seleccionado:');
    disp(paramsTable);
end

%% Función para ajustar modelos y calcular R²
function [p, r2] = ajustar_modelos(model, t, V, p0)
    options = optimoptions('lsqcurvefit', 'Display', 'off');
    lb = [];
    ub = [];
    
    try
        p = lsqcurvefit(model, p0, t, V, lb, ub, options);
    catch ME
        warning(['lsqcurvefit falló: ' ME.message '. Se usará nlinfit en su lugar.']);
        p = nlinfit(t, V, model, p0);
    end

    V_pred = model(p, t);
    SS_res = sum((V - V_pred).^2);
    SS_tot = sum((V - mean(V)).^2);
    r2 = 1 - SS_res/SS_tot;
end
