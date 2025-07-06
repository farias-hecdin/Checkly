local M = {}

-- Cambiar las letras con tilde por una sin tilde.
-- @return
local ACCENT_MAP = {
  ["Á"] = "A", ["á"] = "a",
  ["É"] = "E", ["é"] = "e",
  ["Í"] = "I", ["í"] = "i",
  ["Ó"] = "O", ["ó"] = "o",
  ["Ú"] = "U", ["ú"] = "u",
  ["Ñ"] = "N", ["ñ"] = "n",
}

function M.normal_letters(text)
  return (text:gsub("[%z\1-\127\194-\244][\128-\191]*", function(char)
    return ACCENT_MAP[char] or char
  end))
end


--- Normalizar el estido del texto
function M.sanitized_text(raw)
  local text = M.normal_letters(raw)
  return text:lower():gsub("^%l", string.upper)
end


--- Calcular el tiempo transcurrido desde un momento dado y mostrarlo en el buffer.
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


--- Leer el contenido de un archivo YAML y retornar su contenido
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


--- Extraer el nombre del archivo de una ruta de archivo
-- @return string
function M.processString(path)
  -- Dividir la ruta en varias partes
  local split_path = {}
  for part in path:gmatch("[^/]+") do
    table.insert(split_path, part)
  end
  -- Tomar la ultima parte y remover "-", el keyword (ej. watch) y la extension
  return split_path[#split_path]:gsub("-", " "):gsub("%.%w+%.md", "")
end


-- Acortar el texto dado
-- @return (string)
function M.truncate_text(text, max_len)
  if #text > max_len then
    return string.sub(text, 1, max_len - 3) .. "…"
  else
    return text
  end
end


-- Buscar archivos `.watch.md` en un directorio dado.
-- @return (table)
function M.find_files(dir)
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

return M
