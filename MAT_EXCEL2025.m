%% Convertir archivos .MAT a .XLSX automáticamente
% Solicitar al usuario si quiere seleccionar un archivo o un directorio
choice = input('Seleccione una opción (1: Archivo, 2: Directorio): ');

if choice == 1
    [fileName, filePath] = uigetfile('*.mat', 'Seleccione un archivo .MAT');
    if fileName == 0
        error('No se seleccionó ningún archivo.');
    end
    matFiles = struct('name', fileName);
    matDirPath = filePath;
else
    matDirPath = uigetdir('', 'Seleccione un directorio con archivos .MAT');
    if matDirPath == 0
        error('No se seleccionó ningún directorio.');
    end
    matFiles = dir(fullfile(matDirPath, '*.mat'));
end

% Inicializar una figura para graficar todas las curvas
figure('Name','Evolución del Volumen de Todos los Pacientes','Color','w');
hold on;

% Procesar cada archivo .mat encontrado
for i = 1:length(matFiles)
    matFile = fullfile(matDirPath, matFiles(i).name);
    [~, baseFileName, ~] = fileparts(matFiles(i).name);
    xlsxFile = fullfile(matDirPath, [baseFileName, '.xlsx']);
    
    % Cargar el archivo .mat
    data = load(matFile);
    
    % Convertir `TablaDatos` en tabla (si es un struct)
    if isfield(data, 'TablaDatos')
        if isstruct(data.TablaDatos)
            TablaDatos = struct2table(data.TablaDatos);
        else
            TablaDatos = data.TablaDatos;
        end
    else
        TablaDatos = table(); % Crear tabla vacía si no existe
    end
    
    % Guardar en un archivo Excel
    writetable(TablaDatos, xlsxFile, 'Sheet', 'Datos');
    
    % Leer todas las hojas del Excel
    sheets = sheetnames(xlsxFile);
    
    for j = 1:length(sheets)
        T = readtable(xlsxFile, 'Sheet', sheets{j});
        if ismember({'Tiempo', 'Volumen'}, T.Properties.VariableNames)
            Tiempo = T.Tiempo;
            Volumen = T.Volumen;
            
            % Graficar cada paciente
            plot(Tiempo, Volumen, '-o', 'DisplayName', sheets{j});
        end
    end
    
    disp(['✅ Archivo convertido: ', xlsxFile]);
end

% Configurar gráfica
xlabel('Tiempo (meses)'); ylabel('Volumen del Tumor (cm^3)');
title('Evolución del Volumen Tumoral de Todos los Pacientes');
grid on;
legend;

disp('✅ Todos los archivos .MAT han sido convertidos a Excel correctamente.');