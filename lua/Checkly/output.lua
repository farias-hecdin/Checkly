local M = {}
local utils = require("Checkly.utils")
local config = require("Checkly.config")

local function format_list(title, url)
  return string.format("* [%s](%s)", title, url)
end


-- Helper function to format a single row of the output table
local function format_row(name, checked, total, col_widths)
  local name_str = utils.truncate_text(name, col_widths.name)

  -- Format count string: "checked / Pending / total"
  local pending = total - checked

  local empty_count = 0
  for _, num in ipairs({checked, pending, total}) do
    if num == 0 then
      empty_count = empty_count + 1
    end
  end

  if empty_count >= 3 then
    return string.format(
      "| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
      name_str, "-", "-"
    )
  end

  local count_str = string.format("%d : %d : %d", checked, pending, total)

  -- Calculate percentage and progress bar
  local percentage = 0
  if total > 0 then
    percentage = math.floor((checked / total) * 100)
  end
  -- A 100% progress corresponds to 20 bars (100 / 5 = 20)
  local num_bars = math.floor(percentage / 5)
  local bar_str = string.rep(config.options.bars, num_bars)
  local progress_str = string.format("%s %d%%", bar_str, percentage)

  -- Format the full line using specified column widths for alignment
  return string.format(
    "| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
    name_str, count_str, progress_str
  )
end


-- Genera las líneas de texto para el informe en formato tabla.
-- @param results_for_table (table) Tabla que contiene los resultados de todos los archivos.
-- @param grand_totals (table) Tabla con los totales generales {checked, total}.
-- @return (table) Una tabla de strings, donde cada string es una línea del informe.
function M.generate_report_lines(results_for_table, grand_totals)
  local col_widths = {
    name = config.options.colwidth_name + 5,
    count = config.options.colwidth_counter + 2,
    progress = config.options.colwidth_progress + 2
  }
  local output = {}

  -- Encabezado de la tabla
  table.insert(output, "")
  table.insert(output, string.format(
    "| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
    "TASKS", "COM : PEN : TOT", "PROGRESS"
  ))
  table.insert(output, string.format(
    "|%s|:%s:|%s|",
    string.rep('-', col_widths.name + 2), string.rep('-', col_widths.count + 2), string.rep('-', col_widths.progress + 2)
  ))

  -- Filas de tareas
  for _, file_result in ipairs(results_for_table) do
    -- Imprimir el título del archivo/tarea principal
    table.insert(output, format_row(file_result.title, 0, 0, col_widths))
    -- Imprimir cada sub-tarea encontrada en ese archivo
    for _, task_data in ipairs(file_result.tasks) do
      table.insert(output, format_row(task_data.name, task_data.checked, task_data.total, col_widths))
    end
  end

  -- Fila de totales
  table.insert(output, format_row("Total", grand_totals.checked, grand_totals.total, col_widths))
  table.insert(output, "")

  -- Encabezado de la lista
  table.insert(output, "")
  table.insert(output, "**File path:**")

  -- lista de paths
  for _, file_result in ipairs(results_for_table) do
    table.insert(output, format_list(file_result.title, file_result.path))
  end
  table.insert(output, "")
  return output
end

return M
