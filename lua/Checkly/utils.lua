local M = {}

--- Calcular el tiempo transcurrido desde un momento dado y lo muestra en el buffer.
function M.time_elapsed(start_time)
  local end_time = os.clock()
  local elapsed_time = end_time - start_time
  local output_lines = {}
  table.insert(output_lines, "Elapsed time: " .. string.format("%.3f", elapsed_time) .. " seg")
  -- Obtiene la posición actual del cursor
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1] - 1
  -- Inserta la línea de tiempo transcurrido en la posición del cursor
  vim.api.nvim_buf_set_lines(0, row, row, false, output_lines)
end


--- Leer el contenido de un archivo YAML desde una ruta dada.
function M.readYaml(path)
  local open_file = io.open(path, "r")
  if open_file then
    -- Lee el contenido completo del open_file
    local content= open_file:read("*a")
    open_file:close()
    return content
  else
    vim.notify("No se pudo abrir el archivo en la ruta: " .. path, vim.log.levels.ERROR)
    return nil
  end
end


--- Extraer el nombre del archivo de una ruta
function M.processString(path)
  -- Dividir la ruta en varias partes
  local split_path = {}
  for part in path:gmatch("[^/]+") do
    table.insert(split_path, part)
  end
  -- Tomar la ultima parte y remover "-", el keyword (ej. watch) y la extension
  local last_part = #split_path
  return split_path[#last_part]:gsub("-", " "):gsub("^%l", string.upper):gsub("%.%w+%.md", "")
end


--- Acortar el texto dado
function M.truncate(text, max_len)
  if #text > max_len then
    return string.sub(text, 1, max_len - 3) .. "…"
  else
    return text
  end
end

return M
