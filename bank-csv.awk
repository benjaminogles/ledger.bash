
function maybe_unquote(col) {
  if (col == 1 && unquote)
    return substr($col, 2)
  else if (col == NF && unquote)
    return substr($col, 1, length($col) - 1)
  return $col
}

function should_process(date) {
  if (!after)
    return 1
  if (date_to_num(date) > after)
    return 1
  return 0
}

BEGIN {
  if (!date_col || !description_col || !amount_col)
    die("date_col, description_col and amount_col must all be set")
  if (unquote)
    FS = "\",\""
  else
    FS = ","
  OFS = ","
  sort_cmd = "sort"
  after = date_to_num(after)
  gsub(/\//, "", after)
  after = int(after)
}

header && FNR == 1 { next }

NF >= 4 {
  date_cmd = "date -d '" maybe_unquote(date_col) "' '+%Y/%m/%d'"
  date_cmd | getline date
  close(date_cmd)
  description = maybe_unquote(description_col)
  gsub(/,/, "", description)
  amount = maybe_unquote(amount_col)
  if (should_process(date))
    print date, description, amount | sort_cmd
}

END { close(sort_cmd) }
