local M = {}
local utils = require("Checkly.utils")
local config = require("Checkly.config")

--- Formatear texto a lista de enlaces
--- @param title (string) Titulo del URL
--- @param url (string) Direccion URL
--- @return (string)
local function text_to_list(title, url)
  return string.format("* [%s](%s)", title, url)
end


--- Formatear una sola fila de la tabla de salida
--- @param name (string) Nombre de la tarea
--- @param checked (number) Numero de elementos verificados
--- @param total (number) Numero total de elementos verificados
--- @param col_widths (table) Tamaño de las columnas
--- @return (string)
local function format_row(name, checked, total, col_widths)
  local name_str = utils.truncate_text(name, col_widths.name)

  -- Formatear los contadores: "checked / Pending / total"
  local pending = total - checked
  local empty_count = 0
  for _, num in ipairs({checked, pending, total}) do
    if num == 0 then
      empty_count = empty_count + 1
    end
  end

  if empty_count >= 3 then
    return string.format("| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
      name_str, "-", "-")
  end

  local count_str = string.format("%d : %d : %d", checked, pending, total)

  -- Calcular porcentaje y barra de progreso
  local percentage = 0
  if total > 0 then
    percentage = math.floor((checked / total) * 100)
  end
  -- Un 100% de progreso corresponde a 20 barras (100 / 5 = 20)
  local num_bars = math.floor(percentage / 5)
  local bar_str = string.rep(config.options.style_bar, num_bars)
  local progress_str = string.format("%s %d%%", bar_str, percentage)

  -- Formatear la fila usando los anchos de columna especificados
  return string.format("| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
    name_str, count_str, progress_str)
end


-- Generar las líneas de texto para el reporte final
-- @param data (table) Datos de todos los archivos
-- @param totals (table) Total de elementos: checked y total
-- @return (table)
function M.generate_report_lines(data, totals)
  local tbl_add_, str_rep_ = table.insert, string.rep
  local col_widths = {
    name = config.options.colwidth_name + 5,
    count = config.options.colwidth_counter + 2,
    progress = config.options.colwidth_progress + 2
  }
  local output = {}

  -- Encabezado de la tabla
  tbl_add_(output, "")
  tbl_add_(output, string.format("| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
    "TASKS", "COM : PEN : TOT", "PROGRESS"))
  tbl_add_(output, string.format("|%s|:%s:|%s|",
    str_rep_('-', col_widths.name + 2), str_rep_('-', col_widths.count + 2), str_rep_('-', col_widths.progress + 2)))

  -- Filas de tareas
  for _, file_result in ipairs(data) do
    -- Imprimir el título del archivo/tarea principal
    tbl_add_(output, format_row(file_result.title, 0, 0, col_widths))
    -- Imprimir cada sub-tarea encontrada en ese archivo
    for _, task_data in ipairs(file_result.tasks) do
      tbl_add_(output, format_row(task_data.name, task_data.checked, task_data.total, col_widths))
    end
  end

  -- Fila de totales
  tbl_add_(output, format_row("Total", totals.checked, totals.total, col_widths))
  tbl_add_(output, "")

  -- Encabezado de la lista
  tbl_add_(output, "")
  tbl_add_(output, "**File path:**")

  -- lista de paths
  for _, file_result in ipairs(data) do
    tbl_add_(output, text_to_list(file_result.title, file_result.path))
  end
  tbl_add_(output, "")
  return output
end

return M
