local M = {}
local U = require("Checkly.utils")
local yaml = require("Checkly.vendor.YAMLParserLite")

local cfg = {
  colwidth_name = 28,
  colwidth_counter = 14,
  colwidth_progress = 25,
  bars = "█"
}

-- Helper function to format a single row of the output table
local function format_row(name, checked, total, col_widths)
  -- Truncate name as per the specified width
  local name_str = U.truncate(name, col_widths.name)

  -- Format count string: "checked / Pending / total"
  local pending = total - checked
  local count_str = string.format("%d : %d : %d", checked, pending, total)

  -- Calculate percentage and progress bar
  local percentage = 0
  if total > 0 then
    percentage = math.floor((checked / total) * 100)
  end
  -- A 100% progress corresponds to 20 bars (100 / 5 = 20)
  local num_bars = math.floor(percentage / 5)
  local bar_str = string.rep(cfg.bars, num_bars)
  local progress_str = string.format("%s %d%%", bar_str, percentage)

  -- Format the full line using specified column widths for alignment
  return string.format(
    "| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
    name_str,
    count_str,
    progress_str
  )
end


-- Main function to find config, process tasks, and generate the report
function M.process_tasks(base_dir)
  local config_path = vim.fs.joinpath(base_dir, 'checkly.yml')
  local config_data = {}

  if not vim.fn.filereadable(config_path) then
    vim.notify("Error: '.checkly.yml' no encontrado en " .. base_dir, vim.log.levels.ERROR)
    return
  end

  -- Load the YAML configuration file
  local yaml_file = U.readYaml(config_path)
  local yaml_data = yaml.parse(yaml_file)

  for _, path in pairs(yaml_data.path) do
    table.insert(config_data, path)
  end

  if type(config_data) ~= 'table' then
    vim.notify("Error al ejecutar 'checkly.yml' o el archivo no retorna una tabla.", vim.log.levels.ERROR)
    return
  end

  local results = {}
  local grand_total_checked = 0
  local grand_total_tasks = 0
  local config_dir = vim.fn.fnamemodify(config_path, ':h')

  -- Iterate over each task defined in the config
  for _, task_info in ipairs(config_data) do
    if task_info then
      local task_dir = vim.fs.joinpath(config_dir, task_info)
      local current_checked = 0
      local current_total = 0
      local current_name = U.processString(task_info)

      local lines = vim.fn.readfile(task_dir)
      for _, line in ipairs(lines) do
        -- Match an unchecked checkbox: "- [ ]"
        if line:match("^%s*-%s*%[%s%]") then
          current_total = current_total + 1
          -- Match a checked checkbox: "- [x]", "- [C]", etc. (any non-space character)
        elseif line:match("^%s*-%s*%[%S%]") then
          current_total = current_total + 1
          current_checked = current_checked + 1
        end
      end

      table.insert(results, {
        name = "* " .. current_name,
        checked = current_checked,
        total = current_total,
      })

      grand_total_checked = grand_total_checked + current_checked
      grand_total_tasks = grand_total_tasks + current_total
    end
  end

  -- Define column widths for the output table
  local col_widths = {name = cfg.colwidth_name + 5, count = cfg.colwidth_counter + 2 , progress = cfg.colwidth_progress + 2}
  local output_lines = {}

  -- Header
  table.insert(output_lines, "")
  table.insert(output_lines, string.format(
    "| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
    "TASKS", "COM : PEN : TOT", "PROGRESS"
  ))
  -- Separator
  table.insert(output_lines, string.format(
    "|%s|:%s:|%s|",
    string.rep('-', col_widths.name + 2),
    string.rep('-', col_widths.count + 2),
    string.rep('-', col_widths.progress + 2)
  ))

  -- Task rows
  for _, res in pairs(results) do
    table.insert(output_lines, format_row(res.name, res.checked, res.total, col_widths))
  end

  -- Total row
  table.insert(output_lines, format_row("Total", grand_total_checked, grand_total_tasks, col_widths))
  table.insert(output_lines, "")

  -- Insert the generated lines into the current buffer at the cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1] - 1 -- API is 0-indexed
  vim.api.nvim_buf_set_lines(0, row, row, false, output_lines)
end


-- Create the user command :Checkly
function M.setup(_)
  vim.api.nvim_create_user_command('Checkly', function(arg)
    -- The base directory can be passed as an argument, otherwise use the current working directory
    local base_dir = arg.fargs[1] or vim.fn.getcwd()
    M.process_tasks(base_dir)
  end, {
      nargs = '?', -- 0 or 1 arguments
      complete = 'dir', -- Provide directory completion for the argument
      desc = 'Analiza los directorios de checkly.yml y muestra el progreso de las tareas.'
    })
end

return M
