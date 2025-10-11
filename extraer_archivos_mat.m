function extraer_archivos_mat()
    % Pedir al usuario seleccionar el directorio de origen
    sourceDir = uigetdir('', 'Seleccione el directorio con archivos .mat');
    if sourceDir == 0
        disp('No se seleccionó ningún directorio. Saliendo...');
        return;
    end

    % Pedir el directorio de destino para guardar los archivos extraídos
    destDir = uigetdir('', 'Seleccione el directorio donde guardar los archivos extraídos');
    if destDir == 0
        disp('No se seleccionó directorio destino. Saliendo...');
        return;
    end

    % Listar todos los archivos .mat en el directorio seleccionado
    matFiles = dir(fullfile(sourceDir, '*.mat'));

    if isempty(matFiles)
        disp('No se encontraron archivos .mat en el directorio seleccionado.');
        return;
    end

    % Procesar cada archivo .mat
    for i = 1:length(matFiles)
        matFilePath = fullfile(sourceDir, matFiles(i).name);
        fprintf('Procesando: %s\n', matFiles(i).name);

        % Cargar el contenido del archivo .mat
        data = load(matFilePath);
        varNames = fieldnames(data);

        if length(varNames) == 1
            % Si solo hay una variable, guardar el archivo .mat tal cual en el destino
            copyfile(matFilePath, fullfile(destDir, matFiles(i).name));
            fprintf('  → Copiado sin cambios: %s\n', matFiles(i).name);
        else
            % Si hay múltiples variables, extraer y guardar
            for j = 1:length(varNames)
                varName = varNames{j};
                varData = data.(varName);
                
                % Si la variable parece ser una tabla, guardarla como Excel
                if istable(varData)
                    excelFile = fullfile(destDir, sprintf('%s_%s.xlsx', matFiles(i).name(1:end-4), varName));
                    writetable(varData, excelFile);
                    fprintf('  → Guardado Excel: %s\n', excelFile);
                elseif isstruct(varData) || iscell(varData)
                    % Guardar estructuras y celdas en un archivo .mat aparte
                    matOutFile = fullfile(destDir, sprintf('%s_%s.mat', matFiles(i).name(1:end-4), varName));
                    save(matOutFile, 'varData');
                    fprintf('  → Guardado estructura/celda en .mat: %s\n', matOutFile);
                else
                    % Guardar otras variables numéricas en archivos separados
                    matOutFile = fullfile(destDir, sprintf('%s_%s.mat', matFiles(i).name(1:end-4), varName));
                    save(matOutFile, 'varData');
                    fprintf('  → Guardado variable en .mat: %s\n', matOutFile);
                end
            end
        end
    end

    disp('Proceso finalizado.');
end
