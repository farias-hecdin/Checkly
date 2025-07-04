local M = {}
local uts = require("Checkly.utils")
local cfg = require("Checkly.config")
local out = require("Checkly.output")
local yaml = require("vendor.YAMLParserLite")

local table_insert_, string_format_, string_rep_ = table.insert, string.format, string.rep
local log_, fs_ = vim.log.levels, vim.fs


--- Busca archivos `.watch.md` en un directorio dado.
-- @param dir string El directorio donde buscar archivos.
-- @return table Una lista de paths de archivos encontrados.
function find_files(dir)
  local found_files = {}

  local ok, dir_iterator = pcall(vim.fs.dir, dir)
  if not ok then
    return found_files
  end

  -- Iterar sobre el contenido del directorio.
  for filename, filetype in dir_iterator do
    if filetype == 'file' and filename:match("%.watch%.md$") then
      local full_path = vim.fs.joinpath(dir, filename)
      table.insert(found_files, full_path)
    end
  end
  return found_files
end


-- Main function to find config, process tasks, and generate the report
function M.process_tasks(base_dir)
  local config_path = fs_.joinpath(base_dir, 'checkly.yaml')
  local config_data = {}

  if not vim.fn.filereadable(config_path) then
    vim.notify("Error: '.checkly.yml' no encontrado en " .. base_dir, log_.ERROR)
    return
  end

  -- Load the YAML configuration file
  local yaml_file = uts.readYaml(config_path)
  local yaml_data = yaml.parse(yaml_file)


  for _, path in pairs(yaml_data.dirs) do
    config_data = find_files(path)
  end

  if type(config_data) ~= 'table' then
    vim.notify("Error al ejecutar 'checkly.yml' o el archivo no retorna una tabla.", log_.ERROR)
    return
  end

  local results = {}
  local grand_total_checked, grand_total_tasks = 0, 0

  -- Iterate over each task defined in the config
  local cdir = vim.fn.fnamemodify(config_path, ':p:h')

  for _, task_info in ipairs(config_data) do
    if task_info then
      local task_dir = fs_.joinpath(cdir, task_info)
      local current_checked = 0
      local current_total = 0
      local current_name = "* " .. uts.processString(task_info)

      local lines = vim.fn.readfile(task_dir)
      for i = 1, #lines do
        local line = lines[i]
        local target_name, startLine, endLine = line:match("checkly: %(([%w%s]+), (%d+), (%d+)%)")
        if not startLine then
          goto continue
        end

        local startIndex = tonumber(startLine) - 1
        local endIndex = tonumber(endLine) - 1

        if startIndex >= 0 and endIndex < #lines then
          for y = startIndex, endIndex do
            -- Match an unchecked checkbox: "- [ ]"
            local target_line = lines[y]
            if target_line:match("^%s*-%s*%[%s%]") then
              current_total = current_total + 1
              -- Match a checked checkbox: "- [x]", "- [C]", etc. (any non-space character)
            elseif target_line:match("^%s*-%s*%[%S%]") then
              current_total = current_total + 1
              current_checked = current_checked + 1
            end
          end

          table_insert_(results, {
            title = current_name,
            name = "- " .. target_name,
            checked = current_checked,
            total = current_total,
          })

          grand_total_checked = grand_total_checked + current_checked
          grand_total_tasks = grand_total_tasks + current_total
        else
          goto continue
        end
        ::continue::
      end
    end
  end

  -- Define column widths for the output table
  local col_widths = {name = cfg.options.colwidth_name + 5, count = cfg.options.colwidth_counter + 2 , progress = cfg.options.colwidth_progress + 2}
  local output_lines = {}

  -- Header
  table_insert_(output_lines, "")
  table_insert_(output_lines, string_format_(
    "| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
    "TASKS", "COM : PEN : TOT", "PROGRESS"
  ))
  -- Separator
  table_insert_(output_lines, string_format_(
    "|%s|:%s:|%s|",
    string_rep_('-', col_widths.name + 2), string_rep_('-', col_widths.count + 2), string_rep_('-', col_widths.progress + 2)
  ))

  -- Task rows
  local cached_title = ""
  for _, res in pairs(results) do
    if cached_title ~= res.title then
      table_insert_(output_lines, out.format_row(res.title, 0, 0, col_widths))
      cached_title = res.title
    end
    table_insert_(output_lines, out.format_row(res.name, res.checked, res.total, col_widths))
  end

  -- Total row
  table_insert_(output_lines, out.format_row("Total", grand_total_checked, grand_total_tasks, col_widths))
  table_insert_(output_lines, "")

  -- Insert the generated lines into the current buffer at the cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1] - 1 -- API is 0-indexed
  vim.api.nvim_buf_set_lines(0, row, row, false, output_lines)
end


function M.run(opts)
  opts = opts or {}
  local base_dir = (opts.fargs and opts.fargs[1]) or vim.fn.getcwd()

  local current_file = vim.fn.fnamemodify(vim.fn.expand('%'), ':t')
  local target_file = cfg.options.target_file

  if current_file == target_file then
    -- Borrar todo el texto del buffer actual
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
    -- Cronometrar la ejecucion del script
    local start_time = os.clock()
    -- Ejecutar Checkly
    M.process_tasks(base_dir)
    -- Determinar el tiempo de ejecucion
    uts.time_elapsed(start_time)
  else
    local message = string_format_("Advertencia: No estás en el archivo '%s'", target_file)
    vim.notify(message, vim.log.levels.WARN)
  end
end


function M.setup(_)
  local keymap_opts = {noremap = true, silent = true, desc = "Ejecutar Checkly"}
  vim.keymap.set('n', '<leader>1', function() M.run() end, keymap_opts)
end


-- Create the user command :Checkly
vim.api.nvim_create_user_command('Checkly',
  M.run, -- Pasa la tabla de argumentos del comando directamente a M.run.
  {nargs = '?', complete = 'dir', desc = 'Analiza los directorios de checkly.yml y muestra el progreso de las tareas.'}
)

return M
