clc;
clear;
close all;

%% Lectura de datos

% Ruta del archivo Excel
archivoPath = '/Users/jorgeroblero/Documents/mening-2.xlsx'; 

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

patientIDs_input = input('Ingrese los ID de los pacientes separados por comas (ejemplo: 48, 31, 222): ', 's');
patientIDs = str2num(patientIDs_input);  %#ok<ST2NM>

if isempty(patientIDs)
    error('No se ingresaron IDs válidos.');
end

%% Inicialización de resultados

numModels = 5;
numPatients = length(patientIDs);

% 'ajustes' guardará los parámetros ajustados para cada modelo y paciente
ajustes = cell(numModels, numPatients);
% 'resultados' guardará el valor de R² para cada modelo y paciente.
resultados = array2table(zeros(numModels, numPatients), 'VariableNames', cellstr(string(patientIDs)), ...
                          'RowNames', {'Exponencial', 'Power', 'Logístico', 'Gompertz', 'VAJU'});

%% Definición de modelos

exponencial = @(p, t) p(1) * exp(p(2) * t);
power      = @(p, t) p(1) * t.^p(2);
logistico  = @(p, t) p(1) ./ (1 + exp(-p(2) * (t - p(3))));
gompertz   = @(p, t) p(1) * exp(-p(2) * exp(-p(3) * t));
% En vaju_model se reemplaza min(T) por min(t) para que use el mínimo del vector de tiempo local.
vaju_model = @(p, t) ((p(2) * (t - min(t)) * (1 - p(3)) + p(1)^(1 - p(3))).^(1/(1 - p(3))));

modelos = {exponencial, power, logistico, gompertz, vaju_model};
nombres_modelos = {'Exponencial', 'Power', 'Logístico', 'Gompertz', 'VAJU'};

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
            [1, 0.5], ...                    % Power
            [max(V), 0.1, median(T)], ...      % Logístico
            [max(V), 1, 0.05], ...             % Gompertz (parámetros iniciales mejorados)
            [V(1), 0.1, 0.5] };                % VAJU

    % Ajustar cada modelo y guardar parámetros y R²
    for j = 1:numModels
        [p, r2] = ajustar_modelos(modelos{j}, T, V, p0s{j});
        ajustes{j, i} = p;
        % Si el R² es negativo, se reemplaza por 0
        if r2 < 0
            r2 = 0;
        end
        resultados{j, i} = r2;
    end
end

% Mostrar los resultados (R²)
disp('Resultados de ajuste (R²):');
disp(resultados);

% Guardar la tabla de R² en Excel
writetable(resultados, 'resultados_ajuste.xlsx', 'WriteRowNames', true);

%% Graficar modelos ajustados para un paciente seleccionado

while true
    plotID = input('Ingrese el ID que desea graficar (o 0 para salir): ');
    if plotID == 0
        disp('Saliendo del programa...');
        break;
    end
    
    % Buscar el índice del paciente en el vector patientIDs
    idx = find(patientIDs == plotID, 1);
    if isempty(idx)
        disp('ID no encontrado en los análisis. Intente nuevamente.');
        continue;
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
    colors = lines(numModels); % Paleta de colores para distinguir cada modelo
    % Modificar manualmente el color para Logístico (índice 3) y VAJU (índice 5)
    colors(3,:) = [0, 0, 0.5];   % Logístico: azul oscuro
    colors(5,:) = [0, 0.5, 0];     % VAJU: verde oscuro

    for j = 1:numModels
        figure;
        hold on;
        % Graficar los datos observados (solo puntos)
        plot(T, V, 'ko', 'MarkerSize', 10, 'DisplayName', 'Datos Observados');
        
        % Graficar el modelo ajustado (si se obtuvo ajuste)
        params = ajustes{j, idx};
        if isempty(params)
            plot(T, NaN(size(T)), '--', 'LineWidth', 2, 'DisplayName', sprintf('%s (no converge)', nombres_modelos{j}));
        else
            V_ajustado = modelos{j}(params, T);
            % Línea discontinua del modelo con el color asignado
            plot(T, V_ajustado, '--', 'LineWidth', 2, 'Color', colors(j,:), 'DisplayName', nombres_modelos{j});
            % Puntos ajustados con el símbolo "+" en el mismo color
            plot(T, V_ajustado, '+', 'MarkerSize', 12, 'LineWidth', 2, 'Color', colors(j,:), 'DisplayName', [nombres_modelos{j} ' Puntos']);
        end

        xlabel('Tiempo (meses)', 'FontSize', 16, 'FontWeight', 'bold');
        ylabel('Volumen (cm³)', 'FontSize', 16, 'FontWeight', 'bold');
        title(sprintf('Ajuste del modelo %s para el paciente ID %d', nombres_modelos{j}, plotID), ...
              'FontSize', 18, 'FontWeight', 'bold');
        legend('show', 'FontSize', 14, 'Location', 'northwest');
        grid on;
        hold off;
        
        % Guardar el gráfico en un archivo PNG
        saveas(gcf, sprintf('ajuste_%s_ID%d.png', nombres_modelos{j}, plotID));
    end
    
    %% Gráfica combinada de los 5 modelos con los datos observados
    figure;
    hold on;
    % Graficar los datos observados
    plot(T, V, 'ko', 'MarkerSize', 10, 'DisplayName', 'Datos Observados');
    % Usar la misma paleta modificada
    for j = 1:numModels
        params = ajustes{j, idx};
        if isempty(params)
            plot(T, NaN(size(T)), '--', 'LineWidth', 2, 'Color', colors(j,:), ...
                'DisplayName', sprintf('%s (no converge)', nombres_modelos{j}));
        else
            V_ajustado = modelos{j}(params, T);
            % Línea del modelo
            plot(T, V_ajustado, '--', 'LineWidth', 2, 'Color', colors(j,:), 'DisplayName', nombres_modelos{j});
            % Puntos ajustados
            plot(T, V_ajustado, '+', 'MarkerSize', 12, 'LineWidth', 2, 'Color', colors(j,:), 'DisplayName', [nombres_modelos{j} ' Puntos']);
        end
    end
    xlabel('Tiempo (meses)', 'FontSize', 16, 'FontWeight', 'bold');
    ylabel('Volumen (cm³)', 'FontSize', 16, 'FontWeight', 'bold');
    title(sprintf('Ajuste de los 5 modelos para el paciente ID %d', plotID), ...
          'FontSize', 18, 'FontWeight', 'bold');
    legend('show', 'FontSize', 14, 'Location', 'northwest');
    grid on;
    hold off;
    
    % Guardar la gráfica combinada
    saveas(gcf, sprintf('ajuste_Todos_ID%d.png', plotID));
    
end

%% Función para ajustar modelos y calcular R²
function [p, r2] = ajustar_modelos(model, t, V, p0)
    % Opciones para lsqcurvefit (se suprime la salida en pantalla)
    options = optimoptions('lsqcurvefit', 'Display', 'off');
    lb = [];
    ub = [];
    
    % Intentar ajustar usando lsqcurvefit (requiere Optimization Toolbox)
    try
        p = lsqcurvefit(model, p0, t, V, lb, ub, options);
    catch ME
        warning('lsqcurvefit falló: %s. Se usará nlinfit en su lugar.', ME.message);
        % Si falla, usar nlinfit
        p = nlinfit(t, V, model, p0);
    end
    
    % Calcular las predicciones del modelo y el coeficiente de determinación R²
    V_pred = model(p, t);
    SS_res = sum((V - V_pred).^2);
    SS_tot = sum((V - mean(V)).^2);
    r2 = 1 - SS_res/SS_tot;
end



