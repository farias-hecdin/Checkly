local M = {}
local utils = require("Checkly.utils")
local output = require("Checkly.output")
local config = require("Checkly.config")
local yaml = require("vendor.YAMLParserLite")
local log = require("vendor.log").info

local PATTERNS = {
  -- Captura el nombre del objetivo, línea de inicio y línea de fin.
  capture_tag = "checkly: %(([%w%s%*]+), ([%d%*]+), ([%d%*]+)%)",
  -- Usado para encontrar el final de un rango cuando end_line es '*'.
  SIMPLE_TAG = "checkly: %(",
  -- Patrones para contar checkboxes en una línea.
  UNCHECKED_BOX = "^%s*-%s*%[%s%]",
  CHECKED_BOX = "^%s*-%s*%[%S%]",
  -- Patrón para extraer el nombre del objetivo de un encabezado Markdown.
  HEADER_TEXT = "^#+%s+(.+)",
}

-- Carga y parsea el archivo de configuración 'checkly.yaml'.
-- Acumula las rutas de todos los archivos de tareas especificados en el config.
-- @param base_dir (string) Directorio base donde buscar 'checkly.yaml'.
-- @return (table|nil) Tabla con rutas de archivos de tareas.
-- @return (string|nil) Directorio del archivo de configuración.
local function load_and_parse_config(base_dir)
  local config_path = vim.fs.joinpath(base_dir, 'checkly.yaml')
  if not vim.fn.filereadable(config_path) then
    vim.notify("Error: 'checkly.yaml' no encontrado en " .. base_dir, vim.log.levels.ERROR)
    return nil
  end

  local yaml_content = utils.readYaml(config_path)
  local yaml_data = yaml.parse(yaml_content)

  if type(yaml_data) ~= 'table' or not yaml_data.dirs then
    vim.notify("Error: 'checkly.yaml' es inválido o no contiene la clave 'dirs'.", vim.log.levels.ERROR)
    return nil
  end

  local config_dir = vim.fn.fnamemodify(config_path, ':p:h')
  local task_files = {
    absolute = {},
    relative = {}
  }

  for _, path_pattern in ipairs(yaml_data.dirs) do
    local files_in_path = utils.find_files(path_pattern)
    if type(files_in_path) == 'table' then
      for _, file_path in ipairs(files_in_path) do
        table.insert(task_files.absolute, vim.fs.joinpath(config_dir, file_path))
        table.insert(task_files.relative, vim.fs.joinpath(".", file_path))
      end
    end
  end

  return task_files, config_dir
end


-- Procesar un archivo de tareas, buscando etiquetas 'checkly' y contando checkboxes.
-- @param task_path (string) Ruta completa al archivo.
-- @return (table) Lista de resultados encontrados.
-- @return (string) Título del archivo.
local function process_task_file(task_path)
  local file_results = {}
  local lines = vim.fn.readfile(task_path)
  if not lines then return {}, "" end

  local task_title =  utils.processString(vim.fn.fnamemodify(task_path, ':t'))
  task_title = utils.sanitized_text(task_title)

  for i, line in ipairs(lines) do
    local target_name, start_line_str, end_line_str = line:match(PATTERNS.capture_tag)

    -- Si no se encuentra una etiqueta, se salta a la siguiente línea.
    if target_name then
      local start_idx = (start_line_str == "*") and (i - 1) or (tonumber(start_line_str) - 1)
      local end_idx
      -- Buscar la próxima etiqueta o el final del archivo para delimitar el rango.
      if end_line_str == "*" then
        for j = i + 1, #lines do
          if lines[j]:match(PATTERNS.SIMPLE_TAG) or j == #lines then
            end_idx = j - 1
            break
          end
        end
        end_idx = end_idx or #lines - 1
      else
        end_idx = tonumber(end_line_str) - 1
      end
      -- Si el nombre del objetivo es '*', se intenta extraer del siguiente encabezado Markdown.
      if target_name == "*" and lines[i + 1] then
        local header_text = lines[i + 1]:match(PATTERNS.HEADER_TEXT)
        if header_text then
          target_name = header_text:gsub(config.options.sub[1], config.options.sub[2])
        end
      end

      target_name = utils.sanitized_text(target_name)

      local checked_in_range, total_in_range = 0, 0

      if start_idx >= 0 and end_idx < #lines then
        for y = start_idx, end_idx do
          local target_line = lines[y]
          if target_line:match(PATTERNS.UNCHECKED_BOX) then
            total_in_range = total_in_range + 1
          elseif target_line:match(PATTERNS.CHECKED_BOX) then
            total_in_range = total_in_range + 1
            checked_in_range = checked_in_range + 1
          end
        end

        table.insert(file_results, {
          name = "- " .. target_name,
          checked = checked_in_range,
          total = total_in_range,
        })
      end
    end
  end
  return file_results, task_title
end


-- Función principal: Orquesta la carga, procesamiento y generación del informe.
-- @param base_dir (string) El directorio desde donde iniciar la búsqueda del config.
function M.process_tasks(base_dir)
  local task_files = load_and_parse_config(base_dir)
  if not task_files then return end

  local results_for_table = {}
  local grand_total_checked, grand_total_tasks = 0, 0

  -- Iterar sobre los archivos y delega el procesamiento.
  for i, task_path in ipairs(task_files.absolute) do
    local tasks_in_file, task_title = process_task_file(task_path)

    if #tasks_in_file > 0 then
      local file_total_checked, file_total_tasks = 0, 0
      for _, task in ipairs(tasks_in_file) do
        file_total_checked = file_total_checked + task.checked
        file_total_tasks = file_total_tasks + task.total
      end

      grand_total_checked = grand_total_checked + file_total_checked
      grand_total_tasks = grand_total_tasks + file_total_tasks
    end

    table.insert(results_for_table, {
      title = string.format("`%d: %s`", i, task_title),
      tasks = tasks_in_file,
      path = task_files.relative[i]
    })
  end

  -- Generar el informe a partir de los resultados compilados.
  local grand_totals = { checked = grand_total_checked, total = grand_total_tasks }
  local output_lines = output.generate_report_lines(results_for_table, grand_totals)

  -- Insertar las líneas generadas en el buffer actual.
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1] - 1
  vim.api.nvim_buf_set_lines(0, row, row, false, output_lines)
end


function M.run(opts)
  opts = opts or {}
  local base_dir = (opts.fargs and opts.fargs[1]) or vim.fn.getcwd()

  local current_file = vim.fn.fnamemodify(vim.fn.expand('%'), ':t')
  local target_file = config.options.target_file

  if current_file:lower() == target_file:lower() then
    -- Borrar todo el texto del buffer actual
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
    -- Cronometrar la ejecucion del script
    local start_time = os.clock()
    -- Ejecutar Checkly
    M.process_tasks(base_dir)
    -- Determinar el tiempo de ejecucion
    utils.time_elapsed(start_time)
  else
    local message = string.format("Advertencia: No estás en el archivo '%s'", target_file)
    vim.notify(message, vim.log.levels.WARN)
  end
end


function M.setup(_)
  local keymap_opts = {noremap = true, silent = true, desc = "Ejecutar Checkly"}
  vim.keymap.set('n', '<leader>Cy', function() M.run() end, keymap_opts)
end


-- Create the user command :Checkly
vim.api.nvim_create_user_command('Checkly', M.run,
  {nargs = '?', complete = 'dir', desc = 'Analiza los directorios de checkly.yml y muestra el progreso de las tareas.'}
)

return M
