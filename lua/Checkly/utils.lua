local M = {}

--- Mostrar un mensaje en la consola
--- @param text (string) Mensaje
--- @param level (string) Nivel (ej. ERROR, WARN, etc.)
M.notify = function(text, level)
  local level_map = {
    ERROR = vim.log.levels.ERROR,
    WARN = vim.log.levels.WARN,
    INFO = vim.log.levels.INFO,
    DEBUG = vim.log.levels.DEBUG,
  }

  local log_level = level_map[level:upper()] or vim.log.levels.INFO
  vim.notify("[Checkly] " .. text, log_level)
end


--- Cambiar las letras con tilde por una sin tilde
local ACCENT_MAP = {
  ["Á"] = "A", ["á"] = "a",
  ["É"] = "E", ["é"] = "e",
  ["Í"] = "I", ["í"] = "i",
  ["Ó"] = "O", ["ó"] = "o",
  ["Ú"] = "U", ["ú"] = "u",
  ["Ñ"] = "N", ["ñ"] = "n",
}

--- @param text (string) Texto a corregir
--- @return (string)
function M.normal_letters(text)
  return (text:gsub("[%z\1-\127\194-\244][\128-\191]*", function(char)
    return ACCENT_MAP[char] or char
  end))
end


--- Normalizar el estilo del texto
--- @param raw (string) Texto inicial
--- @return (string)
function M.sanitized_text(raw)
  local text = M.normal_letters(raw)
  -- Añadir inicial en mayuscula y minuscula al resto del texto
  text = text:lower():gsub("^%l", string.upper)
  return text
end


--- Calcular el tiempo transcurrido desde un momento dado y mostrarlo en el buffer
--- @param start_time (number) Tiempo inicial
function M.time_elapsed(start_time)
  local end_time = os.clock()
  local elapsed_time = end_time - start_time
  local output_lines = {}
  table.insert(output_lines, "Elapsed time: " .. string.format("%.3f", elapsed_time) .. " seg")
  -- Obtener la posición actual del cursor
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1] - 1
  -- Insertar la línea de tiempo transcurrido en la posición del cursor
  vim.api.nvim_buf_set_lines(0, row, row, false, output_lines)
end


--- Extraer el nombre del archivo de una ruta de archivo
--- @param path (string) Ruta del archivo
--- @return (string)
function M.processString(path)
  -- Dividir la ruta en varias partes
  local split_path = {}
  for part in path:gmatch("[^/]+") do
    table.insert(split_path, part)
  end
  -- Tomar la ultima parte y remover "-", el keyword (ej. watch) y la extension
  return split_path[#split_path]:gsub("-", " "):gsub("%.%w+%.md", "")
end


--- Acortar el texto dado
--- @param text (string) Texto inicial
--- @param max_len (number) Longitud maxima
--- @return (string)
function M.truncate_text(text, max_len)
  if #text > max_len then
    return string.sub(text, 1, max_len - 3) .. "…"
  end
  return text
end

return M
