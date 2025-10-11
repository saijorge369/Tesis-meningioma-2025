%% 1. Leer el archivo Excel y mostrar nombres de columnas
archivo = '/Users/jorgeroblero/Documents/Res_MMJR_ene23/Validos_G123_ene23.xlsx';
datos = readtable(archivo);

% Mostrar en pantalla todas las columnas disponibles
disp('Columnas disponibles en el archivo Excel:');
disp(datos.Properties.VariableNames);

%% 2. Solicitar al usuario el nombre de la columna a analizar
% Por defecto se analiza 'SDfa_loc'
columnaAnalizar = input('Ingrese el nombre de la columna a analizar (por defecto "SDfa_loc"): ', 's');
if isempty(columnaAnalizar)
    columnaAnalizar = 'SDfa_loc';
end

%% 3. Extraer y convertir la columna seleccionada a numérica (si es necesario)
dataCol = datos.(columnaAnalizar);
if ~isnumeric(dataCol)
    try
        dataCol = str2double(string(dataCol));
    catch
        error('La columna "%s" no se puede convertir a valores numéricos.', columnaAnalizar);
    end
end

%% 4. Procesar la columna 'Grade'
% Si la columna 'Grade' ya es numérica se utiliza directamente; de lo contrario, se convierte.
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
            gradeNum(i) = NaN;  % En caso de otro valor
        end
    end
end
datos.Grade_num = gradeNum;
datos.Grade_cat = categorical(datos.Grade_num, [1, 2, 3], {'I','II','III'});

%% 5. Calcular la correlación de Pearson entre Grade y la columna seleccionada
indiceValidos = ~isnan(datos.Grade_num) & ~isnan(dataCol);
x = double(datos.Grade_num(indiceValidos));
y = double(dataCol(indiceValidos));
X = [x, y];
[rMatrix, pMatrix] = corr(X, 'Type', 'Pearson');
r = rMatrix(1,2);
p = pMatrix(1,2);
fprintf('Correlación entre Grade y %s: Coeficiente Pearson = %.4f, Valor p = %.4e\n', columnaAnalizar, r, p);

%% 6. Calcular estadísticas descriptivas de la variable seleccionada por grupo de Grade
uniqueGrades = [1, 2, 3];
nGrupos = length(uniqueGrades);
meanVal = zeros(nGrupos,1);
stdVal  = zeros(nGrupos,1);
minVal  = zeros(nGrupos,1);
maxVal  = zeros(nGrupos,1);
nGrupo  = zeros(nGrupos,1);

for i = 1:nGrupos
    idx = datos.Grade_num == uniqueGrades(i) & ~isnan(dataCol);
    grupoData = dataCol(idx);
    nGrupo(i) = numel(grupoData);
    if nGrupo(i) > 0
        meanVal(i) = mean(grupoData);
        stdVal(i)  = std(grupoData);
        minVal(i)  = min(grupoData);
        maxVal(i)  = max(grupoData);
    else
        meanVal(i) = NaN;
        stdVal(i)  = NaN;
        minVal(i)  = NaN;
        maxVal(i)  = NaN;
    end
end

tablaEstadisticas = table(uniqueGrades', nGrupo, meanVal, stdVal, minVal, maxVal, ...
    'VariableNames', {'Grade_num', 'N', ['Media_' columnaAnalizar], ['Desviacion_' columnaAnalizar], ['Min_' columnaAnalizar], ['Max_' columnaAnalizar]});
tablaEstadisticas.Grade = categorical(tablaEstadisticas.Grade_num, [1, 2, 3], {'I','II','III'});
tablaEstadisticas = movevars(tablaEstadisticas, 'Grade', 'Before', 'Grade_num');

disp('Estadísticas descriptivas por grupo:');
disp(tablaEstadisticas);

% Exportar la tabla de estadísticas a un archivo Excel
outputFilename = ['Estadisticas_' columnaAnalizar '_por_Grade.xlsx'];
writetable(tablaEstadisticas, outputFilename);
fprintf('Tabla de estadísticas exportada a "%s".\n', outputFilename);

%% 7. Generar el diagrama de cajas (boxplot) de la variable seleccionada por Grade
figure('Color','w');  % Fondo blanco para la figura
boxplot(dataCol, datos.Grade_cat);
title(['Diagrama de cajas de ' columnaAnalizar ' por Grade']);
xlabel('Grade');
ylabel(columnaAnalizar);
