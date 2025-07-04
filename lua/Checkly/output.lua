local M = {}
local uts = require("Checkly.utils")
local cfg = require("Checkly.config")
local string_format_, string_rep_ = string.format, string.rep

-- Helper function to format a single row of the output table
function M.format_row(name, checked, total, col_widths)
  local name_str = uts.truncate(name, col_widths.name)

  -- Format count string: "checked / Pending / total"
  local pending = total - checked

  local empty_count = 0
  for _, num in ipairs({checked, pending, total}) do
    if num == 0 then
      empty_count = empty_count + 1
    end
  end

  if empty_count >= 3 then
    return string_format_(
      "| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
      name_str, "#", "#"
    )
  end

  local count_str = string_format_("%d : %d : %d", checked, pending, total)

  -- Calculate percentage and progress bar
  local percentage = 0
  if total > 0 then
    percentage = math.floor((checked / total) * 100)
  end
  -- A 100% progress corresponds to 20 bars (100 / 5 = 20)
  local num_bars = math.floor(percentage / 5)
  local bar_str = string_rep_(cfg.options.bars, num_bars)
  local progress_str = string_format_("%s %d%%", bar_str, percentage)

  -- Format the full line using specified column widths for alignment
  return string_format_(
    "| %-" .. col_widths.name .. "s | %-" .. col_widths.count .. "s | %-" .. col_widths.progress .. "s |",
    name_str, count_str, progress_str
  )
end

return M
