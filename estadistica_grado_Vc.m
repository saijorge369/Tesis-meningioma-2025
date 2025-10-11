%% 1. Leer el archivo Excel
archivo = '/Users/jorgeroblero/Documents/Res_MMJR_ene23/Validos_G123_ene23.xlsx';
datos = readtable(archivo);

% Mostrar las primeras filas para verificar la lectura (opcional)
disp('Primeras filas de la tabla:');
disp(head(datos));

%% 2. Convertir la columna 'Grade' a valores numéricos y crear la versión categórica
% Se asume que la columna 'Grade' puede venir como numérica o como texto.
if isnumeric(datos.Grade)
    gradeNum = datos.Grade;
else
    gradeStr = string(datos.Grade);
    n = height(datos);
    gradeNum = zeros(n,1);  % Vector para almacenar el mapeo numérico
    for i = 1:n
        if gradeStr(i) == "I"
            gradeNum(i) = 1;
        elseif gradeStr(i) == "II"
            gradeNum(i) = 2;
        elseif gradeStr(i) == "III"
            gradeNum(i) = 3;
        else
            gradeNum(i) = NaN;  % En caso de encontrar otro valor
        end
    end
end
datos.Grade_num = gradeNum;
% Crear columna categórica para graficar y exportar
datos.Grade_cat = categorical(datos.Grade_num, [1, 2, 3], {'I','II','III'});

%% 3. Calcular la correlación de Pearson entre Grade_num y Vc
% Seleccionar solo los casos válidos (sin NaN)
indiceValidos = ~isnan(datos.Grade_num) & ~isnan(datos.Vc);
x = double(datos.Grade_num(indiceValidos));
y = double(datos.Vc(indiceValidos));

% Concatenar en una matriz de dos columnas
X = [x, y];

% Calcular la correlación de Pearson
[rMatrix, pMatrix] = corr(X, 'Type', 'Pearson');
r = rMatrix(1,2);
p = pMatrix(1,2);

% Crear y mostrar tabla de resultados de la correlación
tabla_resultados = table(r, p, 'VariableNames', {'Coeficiente_Pearson', 'Valor_p'});
disp('Tabla de resultados de la correlación:');
disp(tabla_resultados);

%% 4. Generar el diagrama de cajas (boxplot) de Vc por Grade con fondo blanco
figure('Color', 'w');  % Establece el fondo de la figura a blanco
boxplot(datos.Vc, datos.Grade_cat);  % Se agrupa usando la variable categórica (I, II, III)
title('Diagrama de cajas de Vc por Grade');
xlabel('Grade');
ylabel('Volumen del Tumor (Vc)');

%% 5. Exportar tabla de datos para el paper (solo columnas Grade y Vc)
% Se utiliza la versión categórica para mostrar las etiquetas "I", "II", "III"
tablaPaper = datos(:, {'Grade_cat', 'Vc'});
tablaPaper.Properties.VariableNames{'Grade_cat'} = 'Grade';  % Renombrar la columna
writetable(tablaPaper, 'Tabla_Paper.xlsx');
disp('Tabla con columnas Grade y Vc exportada a "Tabla_Paper.xlsx".');

%% 6. Calcular estadísticas descriptivas de Vc por grupo
uniqueGrades = [1, 2, 3];  % Grados numéricos
nGrupos = length(uniqueGrades);
meanVc = zeros(nGrupos,1);
stdVc  = zeros(nGrupos,1);
minVc  = zeros(nGrupos,1);
maxVc  = zeros(nGrupos,1);
nGrupo = zeros(nGrupos,1);

for i = 1:nGrupos
    idx = datos.Grade_num == uniqueGrades(i) & ~isnan(datos.Vc);
    grupoVc = datos.Vc(idx);
    nGrupo(i) = numel(grupoVc);
    if nGrupo(i) > 0
        meanVc(i) = mean(grupoVc);
        stdVc(i)  = std(grupoVc);
        minVc(i)  = min(grupoVc);
        maxVc(i)  = max(grupoVc);
    else
        meanVc(i) = NaN;
        stdVc(i)  = NaN;
        minVc(i)  = NaN;
        maxVc(i)  = NaN;
    end
end

% Crear tabla de estadísticas descriptivas
tablaEstadisticas = table(uniqueGrades', nGrupo, meanVc, stdVc, minVc, maxVc, ...
    'VariableNames', {'Grade_num', 'N', 'Media_Vc', 'Desviacion_Vc', 'Min_Vc', 'Max_Vc'});
tablaEstadisticas.Grade = categorical(tablaEstadisticas.Grade_num, [1, 2, 3], {'I','II','III'});
tablaEstadisticas = movevars(tablaEstadisticas, 'Grade', 'Before', 'Grade_num');

disp('Estadísticas descriptivas por grupo:');
disp(tablaEstadisticas);

%% 7. Informe estadístico en la ventana de comandos
disp('---------- Informe Estadístico ----------');
fprintf('Correlación entre Grade y Vc: Coeficiente Pearson = %.4f, Valor p = %.4e\n', r, p);
disp('Estadísticas descriptivas por grupo:');
disp(tablaEstadisticas(:, {'Grade', 'N', 'Media_Vc', 'Desviacion_Vc', 'Min_Vc', 'Max_Vc'}));

% Identificar cuál grupo tiene mayor y menor volumen promedio
[maxMean, idxMax] = max(meanVc);
[minMean, idxMin] = min(meanVc);
gradesLabels = {'I', 'II', 'III'};
fprintf('El grupo con mayor volumen de tumor promedio es el Grado %s (%.2f),\n', gradesLabels{idxMax}, maxMean);
fprintf('El grupo con menor volumen de tumor promedio es el Grado %s (%.2f).\n', gradesLabels{idxMin}, minMean);
