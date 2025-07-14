local M = {}

--- Tabla de opciones por defecto
M.options = {
  style_bar = "█", -- <string>
  colwidth_counter = 15, -- <number>
  colwidth_name = 30, -- <number>
  colwidth_progress = 25, -- <number>
  target_file = "Summary", -- <string>
  title_replace = {"^[%d]+[%:%.]%s", ""} -- <regex, string>
}

return M
