local M = {}
local utils = require("Checkly.utils")
local yaml = require("vendor.YAMLParserLite")

--- Leer el contenido de un archivo YAML y retornar su contenido
--- @param path (string) Ruta absoluta del archivo
--- @return (string|nil) Contenido del archivo
local readYaml = function(path)
  local open_file = io.open(path, "r")
  if open_file then
    -- Leer el contenido del open_file
    local content= open_file:read("*a")
    open_file:close()
    return content
  else
    utils.notify("Could not open the file at path: " .. path, "warn")
    return nil
  end
end


--- Buscar archivos en `start_dir`. Si no los encuentras, se sube un nivel y se reintenta
--- @param start_dir (string) Directorio inicial
--- @param max_up? (number) Máximo de directorios hacia arriba. Por defecto 10
--- @return (table) Lista de rutas absolutas
local find_watch_files = function(start_dir, pattern, max_up)
  local found = {}
  max_up = max_up or 10
  local current = vim.fn.fnamemodify(start_dir or vim.loop.cwd(), ':p')

  for _ = 0, max_up do
    -- Iterar sobre el directorio actual
    local ok, dir_iter = pcall(vim.fs.dir, current)
    if ok then
      for name, typ in dir_iter do
        if typ == 'file' and name:match(pattern) then
          local fpath = vim.fn.fnamemodify(vim.fs.joinpath(current, name), ':p')
          table.insert(found, fpath)
        end
      end
    end
    if #found > 0 then
      return found
    end
    -- Si no se encontraron archivos, subir al directorio padre
    local parent = vim.fs.dirname(current)
    -- Detener la búsqueda si se llega al directorio raíz
    if parent == current then
      break
    end
    current = parent
  end
  return found
end


--- Cargar el archivo `checkly.yaml` y pasear sus datos
--- @param base_dir (string) Directorio a buscar `checkly.yaml`
--- @return (table|nil) Tabla con las rutas de las tareas en (1) absolutas y (2) relativas
M.load_and_parse_config = function(base_dir)
  local config_path = vim.fs.joinpath(base_dir, 'checkly.yaml')
  if not vim.fn.filereadable(config_path) then
    utils.notify("'checkly.yaml' file not found in: " .. base_dir, "error")
    return nil
  end

  -- Pasear el archivo YAML
  local yaml_content = readYaml(config_path)
  local yaml_data = yaml.parse(yaml_content)

  if type(yaml_data) ~= 'table' or not yaml_data.paths then
    utils.notify("The file 'checkly.yaml' is invalid or does not contain the 'paths' key", "error")
    return nil
  end

  -- Buscar las archivos ".watch.md"
  local config_dir = vim.fn.fnamemodify(config_path, ':p:h')
  local task_files = {
    absolute = {},
    relative = {}
  }

  for _, path_pattern in ipairs(yaml_data.paths) do
    local search_dir = vim.fs.joinpath(config_dir, path_pattern)
    local files_in_path = find_watch_files(search_dir, '%.watch%.md$')
    if type(files_in_path) == 'table' and #files_in_path > 0 then
      for _, file_path in ipairs(files_in_path) do
        table.insert(task_files.absolute, file_path)
        table.insert(task_files.relative, vim.fn.fnamemodify(file_path, ':.'))
      end
    end
  end
  return task_files
end

return M
