local M = {}

function M.readYaml(ruta)
    local archivo = io.open(ruta, "r")
    if archivo then
        local contenido = archivo:read("*a")
        archivo:close()
        return contenido
    else
        vim.notify("No se pudo abrir el archivo en la ruta: " .. ruta, vim.log.levels.ERROR)
    end
end


-- Helper function to process a String
function M.processString(ruta)
    local partes = {}
    for parte in ruta:gmatch("[^/]+") do
        table.insert(partes, parte)
    end
    return partes[#partes]:gsub("-", " "):gsub("^%l", string.upper):gsub("%.md", "")
end


-- Helper function to truncate text
function M.truncate(text, max_len)
  if #text > max_len then
    return string.sub(text, 1, max_len - 3) .. "…"
  else
    return text
  end
end

return M
