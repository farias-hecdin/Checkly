local M = {}

M.options = {
  bars = "█",
  colwidth_counter = 15,
  colwidth_name = 30,
  colwidth_progress = 25,
  target_file = "Summary.md",
  sub = {"^[%d]+[%:%.]%s", ""}
}

return M
