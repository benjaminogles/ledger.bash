
function abs(n) {
  return n < 0 ? -n : n
}

function min(a, b) {
  return a < b ? a : b;
}

function max(a, b) {
  return a > b ? a : b
}

function approx(a, b, diff) {
  diff = a - b
  if (diff < 0)
    diff *= -1
  return diff < 0.00001
}

function is_budget_account(a) {
  return a ~ /\[.*\]/
}

function pretty_account(a) {
  gsub(/\[|\]/, "", a)
  return a
}

function die(msg) {
  print msg > "/dev/stderr"
  exit 1
}

function trim(s) {
  gsub(/^[ \t]+/, "", s)
  gsub(/[ \t]+$/, "", s)
  return s
}

function parse_dollars(s) {
  if (!match(s, /\$/))
    die("expected $ character in amount on line " NR ": " $0)
  gsub(/[\$,]/, "", s)
  return sprintf("%0.2f", s)
}

function to_cents(d) {
  gsub(/\./, "", d)
  return d
}

function to_dollars(c, s, prefix) {
  if (c < 0) {
    prefix = "-"
    c *= -1
  }
  if (c < 100) {
    if (c < 10)
      return prefix "0.0" c
    return prefix "0." c
  }
  return prefix substr(c, 1, length(c) - 2) "." substr(c, length(c) - 1)
}

function parent_account(a) {
  if (!index(a, ":"))
    return ""
  match(a, /.*:/)
  return substr(a, RSTART, RLENGTH - 1)
}

function is_parent_account(parent, child) {
  return parent != child && parent == substr(child, 1, length(parent))
}

function pretty_dollars(s, pos) {
  s = sprintf("%0.2f", s)
  if (match(s, /[0-9][0-9][0-9][0-9]\.[0-9][0-9]$/))
    s = substr(s, 1, length(s) - 6) "," substr(s, length(s) - 5)
  pos = 10
  while (match(s, /[0-9][0-9][0-9][0-9],/)) {
    s = substr(s, 1, length(s) - pos) "," substr(s, length(s) - (pos - 1))
    pos += 4
  }
  return "$" s
}

function date_to_num(date) {
  gsub(/\//, "", date)
  return int(date)
}

