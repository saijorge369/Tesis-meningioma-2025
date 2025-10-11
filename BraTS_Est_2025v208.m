%% SECCIÓN 1: Selección y Lectura del Archivo
[archivo, path] = uigetfile('*.xlsx', 'Selecciona el archivo Excel con R^2 > 0.98');
if isequal(archivo, 0)
    disp('Operación cancelada. No se seleccionó archivo.');
    return;
end
archivoExcel = fullfile(path, archivo);
try
    data = readtable(archivoExcel, 'VariableNamingRule', 'preserve');
    fprintf('Archivo cargado exitosamente.\n');
catch ME
    fprintf('Error al cargar el archivo: %s\n', ME.message);
    return;
end

%% SECCIÓN 2: Mostrar Información de las Columnas
varNames = data.Properties.VariableNames;
fprintf('\n========== Columnas Disponibles ==========\n');
for i = 1:length(varNames)
    fprintf('%d) %s\n', i, varNames{i});
end

%% SECCIÓN 3: Parámetros Iniciales del Usuario
cajasColor = input('¿Desea que las cajas se muestren a color? (s/n) [por defecto s]: ', 's');
if isempty(cajasColor)
    cajasColor = 's';
end
fontSize = str2double(input('Ingrese el tamaño de letra (por defecto 14): ', 's'));
if isnan(fontSize)
    fontSize = 14;
end

%% SECCIÓN 4: Aplicar Filtro Opcional
usarFiltro = input('¿Desea aplicar un filtro a los datos? (s/n) [por defecto n]: ', 's');
if isempty(usarFiltro)
    usarFiltro = 'n';
end
if strcmpi(usarFiltro, 's')
    columnaFiltro = input('Escribe el nombre de la columna para filtrar: ', 's');
    if ~any(strcmpi(columnaFiltro, data.Properties.VariableNames))
        fprintf('La columna %s no se encontró en el archivo. Continuando sin aplicar filtro.\n', columnaFiltro);
    else
        idxFiltro = find(strcmpi(columnaFiltro, data.Properties.VariableNames), 1);
        columnaFiltro = data.Properties.VariableNames{idxFiltro};
        
        % Filtrar según el tipo de datos
        if isnumeric(data.(columnaFiltro)) || islogical(data.(columnaFiltro))
            valorFiltro = input(sprintf('Escribe el valor mínimo para filtrar en la columna %s: ', columnaFiltro));
            data = data(data.(columnaFiltro) >= valorFiltro, :);
            fprintf('Filtro aplicado: %s >= %.2f\n', columnaFiltro, valorFiltro);
        else
            valorFiltro = input(sprintf('Escribe el valor a filtrar en la columna %s: ', columnaFiltro), 's');
            if iscell(data.(columnaFiltro))
                data = data(strcmpi(data.(columnaFiltro), valorFiltro), :);
            else
                data = data(strcmpi(string(data.(columnaFiltro)), valorFiltro), :);
            end
            fprintf('Filtro aplicado: %s == %s\n', columnaFiltro, valorFiltro);
        end
    end
end

%% SECCIÓN 5: Verificación de Columnas Clave (Split y Grade)
if any(strcmpi('Split', varNames))
    flagSplit = true;
    data.Split = lower(strtrim(data.Split));  % Uniformizar la columna Split
else
    flagSplit = false;
    data.Split = repmat("todos", height(data), 1);
    fprintf('La columna Split no se encontró. Se usará "todos" como categoría.\n');
end

if any(strcmpi('Grade', varNames))
    flagGrade = true;
    if ~isnumeric(data.Grade)
        data.Grade = str2double(data.Grade);
    end
else
    flagGrade = false;
    data.Grade = ones(height(data), 1);
    fprintf('La columna Grade no se encontró. Se agruparán todos los datos juntos.\n');
end

%% SECCIÓN 6: Selección de Columnas a Graficar
columnasInput = input(['Escribe los números o nombres de las columnas que deseas graficar ' ...
    '(separados por coma, espacio o salto de línea).\n' ...
    'Por ejemplo: 1, 5, 7 o DF+Aaj, DF+Aloc: '], 's');
tokens = regexp(columnasInput, '[,\s\n]+', 'split');
tokens = tokens(~cellfun(@isempty, strtrim(tokens)));
columnasGrafico = {};
for i = 1:length(tokens)
    token = strtrim(tokens{i});
    numToken = str2double(token);
    if ~isnan(numToken) && numToken>=1 && numToken<=length(varNames)
        columnasGrafico{end+1} = varNames{round(numToken)};
    else
        idx = find(strcmpi(token, varNames), 1);
        if ~isempty(idx)
            columnasGrafico{end+1} = varNames{idx};
        else
            fprintf('El token "%s" no coincide con ningún nombre de columna y se omitirá.\n', token);
        end
    end
end
if isempty(columnasGrafico)
    fprintf('No se ingresó ninguna columna válida.\n');
    return;
end

if flagGrade
    deseaEtiquetas = input('¿Desea agregar etiquetas personalizadas en el boxplot? (s/n) [por defecto n]: ', 's');
    if isempty(deseaEtiquetas)
         deseaEtiquetas = 'n';
    end
else
    deseaEtiquetas = 'n';
end

%% SECCIÓN 7: Procesar y Graficar Datos (por Split y Grade)
% Se acumulan estadísticas en formato cell array:
% {Columna, Split, Grade, Promedio, Error, Desviacion, N}
stats = [];
for c = 1:length(columnasGrafico)
    colName = columnasGrafico{c};
    fprintf('Procesando columna: %s\n', colName);
    
    if flagSplit
        splits = {'train', 'validation', 'train + validation'};
    else
        splits = {'todos'};
    end
    
    for s = 1:length(splits)
        if flagSplit && ~strcmpi(splits{s}, 'train + validation')
            dataFiltrada = data(strcmpi(data.Split, splits{s}), :);
            tituloSplit = splits{s};
        else
            dataFiltrada = data;
            tituloSplit = 'train + validation';
        end
        
        if isempty(dataFiltrada)
            fprintf('No hay datos para %s en el Split %s. Se omite este gráfico.\n', colName, splits{s});
            continue;
        end
        
        if flagGrade
            % Recolectar datos para el boxplot (por grados)
            grados = unique(dataFiltrada.Grade(~isnan(dataFiltrada.Grade)));
            grados = sort(grados);
            boxData = [];
            groupLabels = [];
            for g = 1:length(grados)
                idx = (dataFiltrada.Grade == grados(g));
                values = dataFiltrada{idx, colName};
                boxData = [boxData; values];
                groupLabels = [groupLabels; repmat(grados(g), size(values))];
                
                nVal = sum(~isnan(values));
                if nVal > 0
                    meanVal = mean(values, 'omitnan');
                    stdVal = std(values, 'omitnan');
                else
                    meanVal = NaN; stdVal = NaN;
                end
                % Guardar error = std/sqrt(n)
                % stats = [stats; {colName, tituloSplit, grados(g), round(meanVal,4), round(stdVal/sqrt(nVal),4), round(stdVal,4), nVal}];
                  stats = [stats; {colName, tituloSplit, grados(g), round(meanVal, 2), round(stdVal/sqrt(nVal), 2), round(stdVal, 2), nVal}];
                    
            end
            
            %% Ajustar ejes según los valores en la caja
            minVal = min(boxData) - 0.1 * range(boxData);
            maxVal = max(boxData) + 0.1 * range(boxData);
            midVal = (minVal + maxVal) / 2;
            
            % Si es DFAj+Alaj (train), ajustar manualmente el eje Y
            if strcmpi(colName, 'DFAj+Alaj') && strcmpi(tituloSplit, 'train')
                ylimRange = [1.8, maxVal];
            else
                ylimRange = [minVal, maxVal];
            end
            
            %% Diagrama de Cajas CON color
            figure('Color', 'w'); 
            b = boxplot(boxData, groupLabels, 'Labels', arrayfun(@num2str, unique(groupLabels), 'UniformOutput', false), 'Symbol', '');
            hold on;
            % Definir colores para las cajas
            nBoxes = length(findobj(gca, 'Tag', 'Box'));
            colores = lines(nBoxes);
            h = findobj(gca, 'Tag', 'Box');
            for j = 1:length(h)
                patch(get(h(j), 'XData'), get(h(j), 'YData'), colores(nBoxes - j + 1, :), 'FaceAlpha', 0.5);
            end
            % Agregar el valor promedio sobre cada caja (en azul)
            gruposUnicos = unique(groupLabels);
            for g = 1:length(gruposUnicos)
                meanValue = mean(boxData(groupLabels == gruposUnicos(g)), 'omitnan');
                text(g, meanValue, sprintf('%.2f', meanValue), 'HorizontalAlignment', 'center', 'Color', 'blue', 'FontSize', 14, 'FontWeight', 'bold');
            end
            hold off;
            ylim(ylimRange);
            title(sprintf('%s (%s)', colName, tituloSplit), 'FontSize', 14);
            xlabel('Grado', 'FontSize', 14);
            ylabel(colName, 'FontSize', 14);
            set(gca, 'XColor', 'k', 'YColor', 'k', 'FontSize', 14, 'Box', 'off');
            
            %% Diagrama de Cajas SIMPLE (sin colores adicionales)
            figure('Color', 'w');
            boxplot(boxData, groupLabels, 'Labels', arrayfun(@num2str, unique(groupLabels), 'UniformOutput', false), 'Symbol', '');
            hold on;
            % Agregar valores promedio dentro de la caja en negro
            for g = 1:length(gruposUnicos)
                meanValue = mean(boxData(groupLabels == gruposUnicos(g)), 'omitnan');
                text(g, meanValue, sprintf('%.2f', meanValue), 'HorizontalAlignment', 'center', 'Color', 'black', 'FontSize', 14, 'FontWeight', 'bold');
            end
            hold off;
            ylim(ylimRange);
            title(sprintf('%s (%s)', colName, tituloSplit), 'FontSize', 14);
            xlabel('Grado', 'FontSize', 14);
            ylabel(colName, 'FontSize', 14);
            set(gca, 'XColor', 'k', 'YColor', 'k', 'FontSize', 14, 'Box', 'off');
        end
    end
end





%% SECCIÓN 8: Análisis Global (Alpha Global)
if all(ismember({'WT','Vc'}, varNames))
    fprintf('\nCalculando Alpha Global...\n');
    data.L = data.Vc.^(1/3);
    data.Alpha_Global = data.WT ./ data.L;
    if flagGrade
        grados = sort(unique(data.Grade(~isnan(data.Grade))));
        simbolos = {'s', 'h', '^'};
        coloresPlot = {'r', 'b', 'g'};
        figure('Color', 'w'); hold on;
        leyenda = {};
        for g = 1:length(grados)
            grado = grados(g);
            idx = (data.Grade == grado) & (data.L > 0) & (data.WT > 0);
            datosGrado = data(idx, :);
            if isempty(datosGrado)
                continue;
            end
            marker = simbolos{mod(g-1, numel(simbolos))+1};
            colorPlot = coloresPlot{mod(g-1, numel(coloresPlot))+1};
            loglog(datosGrado.L, datosGrado.WT, marker, 'Color', colorPlot, 'MarkerSize', 6, 'LineWidth', 1.5);
            leyenda{end+1} = sprintf('\\alpha_{G%d} = %.3f \\pm %.3f', grado, ...
                mean(datosGrado.Alpha_Global, 'omitnan'), std(datosGrado.Alpha_Global, 'omitnan')/sqrt(height(datosGrado)));
            % Ajuste lineal en escala log-log
            p = polyfit(log(datosGrado.L), log(datosGrado.WT), 1);
            x_fit = linspace(min(datosGrado.L), max(datosGrado.L), 100);
            y_fit = exp(polyval(p, log(x_fit)));
            loglog(x_fit, y_fit, 'Color', colorPlot, 'LineWidth', 2);
        end
        xlabel('L (mm)', 'FontSize', 14);
        ylabel('W (mm)', 'FontSize', 14);
        title('Relación entre W y L por Grade', 'FontSize', 14);
        legend(leyenda, 'Location', 'northwest', 'FontSize', 14);
        grid on;
        hold off;
    else
        idx = (data.L > 0) & (data.WT > 0);
        datosTodos = data(idx, :);
        figure('Color', 'w'); hold on;
        loglog(datosTodos.L, datosTodos.WT, 's', 'Color', [0.5 0.25 0], 'MarkerSize', 6, 'LineWidth', 1.5);
        p_global = polyfit(log(datosTodos.L), log(datosTodos.WT), 1);
        x_fit_global = linspace(min(datosTodos.L), max(datosTodos.L), 100);
        y_fit_global = exp(polyval(p_global, log(x_fit_global)));
        loglog(x_fit_global, y_fit_global, 'r', 'LineWidth', 2);
        legend(sprintf('\\alpha = %.3f \\pm %.3f', p_global(1), std(datosTodos.Alpha_Global, 'omitnan')/sqrt(height(datosTodos))), 'Location', 'northwest', 'FontSize', 14);
        xlabel('L (mm)', 'FontSize', 14);
        ylabel('W (mm)', 'FontSize', 14);
        title('Relación Global entre W y L', 'FontSize', 14);
        grid on;
        hold off;
    end
end

%% SECCIÓN 9: Consolidación y Exportación de Estadísticas
if ~isempty(stats)
    statsTable = cell2table(stats, 'VariableNames', {'Columna','Split','Grade','Promedio','Error','Desviacion','N'});
    % Mostrar tabla consolidada (sin la columna N)
    disp('----------------------------------------');
    disp('Tabla Consolidada de Estadísticas (sin N):');
    disp(statsTable(:,1:6));
    
    % Exportar la tabla consolidada completa a HTML
    htmlContent = generateHTMLTable(statsTable(:,1:6), 'Estadísticas Consolidadas');
    htmlFileName = 'Res_EstadisticasConsolidadas.html';
    fid = fopen(htmlFileName, 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', htmlContent);
    fclose(fid);
    fprintf('\nSe ha guardado el archivo HTML: %s\n', htmlFileName);
    
    % NUEVAS TABLAS SIMPLIFICADAS: Se generan dos tablas separadas para TRAIN y VALIDATION
    statsSimpleTrain = statsTable(strcmpi(statsTable.Split, 'train'), {'Grade', 'Columna', 'Promedio', 'Error'});
    statsSimpleValidation = statsTable(strcmpi(statsTable.Split, 'validation'), {'Grade', 'Columna', 'Promedio', 'Error'});
    
    % Exportar la tabla para TRAIN
    disp('----------------------------------------');
    disp('Tabla Simplificada para el conjunto TRAIN (Grado, Columna, Media, Error):');
    disp(statsSimpleTrain);
    
    fprintf('\n----------------------------------------\n');
    fprintf('\\begin{table}[h!]\n\\centering\n');
    fprintf('\\caption{Estadísticas: Media y Error por Grado y Columna \\textbf{(TRAIN)}.}\n');
    fprintf('\\begin{tabular}{|c|l|c|c|}\n');
    fprintf('\\hline\n');
    fprintf('\\textbf{Grado} & \\textbf{Columna} & \\textbf{Media} & \\textbf{Error} \\\\ \\hline\n');
    for i = 1:height(statsSimpleTrain)
        fprintf('%d & %s & %.2f & %.2f \\\\ \\hline\n', statsSimpleTrain.Grade(i), statsSimpleTrain.Columna{i}, statsSimpleTrain.Promedio(i), statsSimpleTrain.Error(i));
    end
    fprintf('\\end{tabular}\n');
    fprintf('\\label{tab:estadisticas_train}\n');
    fprintf('\\end{table}\n');
    
    % Exportar la tabla para VALIDATION
    disp('----------------------------------------');
    disp('Tabla Simplificada para el conjunto VALIDATION (Grado, Columna, Media, Error):');
    disp(statsSimpleValidation);
    
    fprintf('\n----------------------------------------\n');
    fprintf('\\begin{table}[h!]\n\\centering\n');
    fprintf('\\caption{Estadísticas: Media y Error por Grado y Columna \\textbf{(VALIDATION)}.}\n');
    fprintf('\\begin{tabular}{|c|l|c|c|}\n');
    fprintf('\\hline\n');
    fprintf('\\textbf{Grado} & \\textbf{Columna} & \\textbf{Media} & \\textbf{Error} \\\\ \\hline\n');
    for i = 1:height(statsSimpleValidation)
        fprintf('%d & %s & %.2f & %.2f \\\\ \\hline\n', statsSimpleValidation.Grade(i), statsSimpleValidation.Columna{i}, statsSimpleValidation.Promedio(i), statsSimpleValidation.Error(i));
    end
    fprintf('\\end{tabular}\n');
    fprintf('\\label{tab:estadisticas_validation}\n');
    fprintf('\\end{table}\n');
end

%% SECCIÓN 10: Estadísticas Descriptivas por Grado (Tabla LaTeX y HTML)
if flagGrade
    combinedStats = {};
    grades = sort(unique(data.Grade(~isnan(data.Grade))));
    for c = 1:length(columnasGrafico)
        colName = columnasGrafico{c};
        for i = 1:length(grades)
            grade = grades(i);
            idx = (data.Grade == grade);
            values = data{idx, colName};
            values = values(~isnan(values));
            if isempty(values), continue; end
            media = mean(values);
            mediana = median(values);
            std_val = std(values);
            combinedStats = [combinedStats; {grade, colName, media, mediana, std_val}];
        end
    end
    if ~isempty(combinedStats)
        combinedStatsTable = cell2table(combinedStats, 'VariableNames', {'Grado','Columna','Media','Mediana','DEstandar'});
        % Ordenar la tabla por la columna Grado
        combinedStatsTable = sortrows(combinedStatsTable, 'Grado');
        
        % Imprimir tabla en formato LaTeX
        fprintf('\n----------------------------------------\n');
        fprintf('\\begin{table}[h!]\n\\centering\n');
        fprintf('\\caption{Estadísticas descriptivas por grado}\n');
        fprintf('\\begin{tabular}{|c|l|c|c|c|}\n');
        fprintf('\\hline\n');
        fprintf('\\textbf{Grado} & \\textbf{Columna} & \\textbf{Media} & \\textbf{Mediana} & \\textbf{D.Estandar} \\\\ \\hline\n');
        for i = 1:height(combinedStatsTable)
            
            
            %fprintf('%d & %s & %.2f & %.2f & %.2f \\\\ \\hline\n', combinedStatsTable.Grado(i), combinedStatsTable.Columna{i}, combinedStatsTable.Media(i), combinedStatsTable.Mediana(i), combinedStatsTable.DEstandar(i));
        
            fprintf('%d & %s & %.2f & %.2f \\\\ \\hline\n', statsTable.Grade(i), statsTable.Columna{i}, statsTable.Promedio(i), statsTable.Error(i));

        
        end
        fprintf('\\end{tabular}\n');
        fprintf('\\label{tab:estadisticas_grado_columna}\n');
        fprintf('\\end{table}\n');
        
        % Exportar la tabla descriptiva a HTML
        htmlContent = generateHTMLTable(combinedStatsTable, 'Estadísticas Descriptivas por Grado', {'Grado','Columna','Media','Mediana','D.Estandar'});
        htmlFileName = 'Estadisticas_Descriptivas_por_Grado.html';
        fid = fopen(htmlFileName, 'w', 'n', 'UTF-8');
        fprintf(fid, '%s', htmlContent);
        fclose(fid);
        fprintf('\nSe ha guardado el archivo HTML: %s\n', htmlFileName);
    else
        fprintf('No se pudieron calcular estadísticas para las columnas ingresadas.\n');
    end
else
    fprintf('La columna Grade no está disponible. No se puede calcular el consolidado por grado.\n');
end

%% SECCIÓN 11: Mensaje Final
fprintf('\nFin del programa.\n');

%% Función auxiliar: Generar contenido HTML de una tabla
function htmlContent = generateHTMLTable(T, titleStr, colNames)
    if nargin < 3
        colNames = T.Properties.VariableNames;
    end
    htmlContent = sprintf('<html><head><meta charset="UTF-8"><title>%s</title></head><body>', titleStr);
    htmlContent = [htmlContent, sprintf('<h1>%s</h1>', titleStr)];
    htmlContent = [htmlContent, '<table border="1" cellspacing="0" cellpadding="5">'];
    htmlContent = [htmlContent, '<tr>'];
    for i = 1:length(colNames)
        htmlContent = [htmlContent, sprintf('<th>%s</th>', colNames{i})];
    end
    htmlContent = [htmlContent, '</tr>'];
    for i = 1:height(T)
        htmlContent = [htmlContent, '<tr>'];
        for j = 1:width(T)
            cellVal = T{i, j};
            if isnumeric(cellVal)
                cellStr = num2str(cellVal);
            elseif iscell(cellVal)
                cellStr = cellVal{1};
            else
                cellStr = char(cellVal);
            end
            htmlContent = [htmlContent, sprintf('<td>%s</td>', cellStr)];
        end
        htmlContent = [htmlContent, '</tr>'];
    end
    htmlContent = [htmlContent, '</table></body></html>'];
end

%% Función auxiliar: Convertir número a notación romana (para etiquetas)
function romanStr = num2roman(num)
    % Función simple para convertir números del 1 al 10 a romanos.
    romans = {'I','II','III','IV','V','VI','VII','VIII','IX','X'};
    if num >= 1 && num <= 10
        romanStr = romans{num};
    else
        romanStr = num2str(num);
    end
end
