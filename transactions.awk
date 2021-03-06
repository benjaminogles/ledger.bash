
function output_final(date, payee, account, amount) {
  if (!budget && is_budget_account(account))
    return
  if (budget && !is_budget_account(account))
    return
  account = pretty_account(account)
  if (filter && account !~ filter)
    return
  if (start && date_to_num(start) > date_to_num(date))
    return
  if (end && date_to_num(end) <= date_to_num(date))
    return
  print date, payee, account, int(amount)
}

function apply_rules(date, payee, account, amount) {
  for (i = 0; i <= rule_idx; i++) {
    if (account !~ rule_patterns[i])
      continue
    btotal = 0
    delete bamounts
    for (j = 0; j < rule_sizes[i]; j++) {
      bamounts[j] = int(amount * rule_multipliers[i, j])
      btotal += abs(bamounts[j])
    }
    expected = abs(amount)
    if (btotal != expected)
      bamounts[0] += (expected - btotal)
    for (j = 0; j < rule_sizes[i]; j++) {
      baccount = rule_accounts[i, j]
      gsub(/\$account/, account, baccount)
      output_final(date, payee, baccount, bamounts[j])
    }
  }
}

function output(date, payee, account, amount) {
  apply_rules(date, payee, account, amount)
  output_final(date, payee, account, amount)
}

function transition(nxt) {
  if (state == "rule") {
    mult_total = 0
    for (i = 0; i < rule_size; i++)
      mult_total += rule_multipliers[rule_idx, i]
    if (!approx(abs(mult_total), 1.0))
      die("multipliers for budget rule " rule_patterns[rule_idx] " do not sum to +/- 1.0")
  }
  if (nxt == "rule") {
    rule_idx++
    rule_size = 0
  } else if (nxt == "transaction") {
    total = 0
    inferred = ""
  }
  state = nxt
}

BEGIN {
  rule_idx = -1
  state = "transaction"
}

# comments
/^ *;/ { next }

# blank lines
/^ *$/ { next }

# budget rule
/^= / {
  transition("rule")
  rule_patterns[rule_idx] = substr($0, 3)
  next
}

# date and payee
/^[0-9][0-9][0-9][0-9]\/[0-9][0-9]\/[0-9][0-9]/ {
  # print inferred amount from last transaction
  if (inferred)
    output(date, payee, inferred, total * -1)
  else if (total != 0)
    die("Transaction before line " NR " with line item " date "," payee "," account "," amount " does not balance: " total)

  # start next transaction
  date = $1
  payee = trim(substr($0, length(date) + 1))
  transition("transaction")
  next
}

/^[0-9]+\/[0-9]+\/[0-9]+/ { die("bad date format on line " NR ": " $0) }

# automatic transaction account and multiplier
state == "rule" && NF == 2 {
  rule_accounts[rule_idx, rule_size] = $1
  rule_multipliers[rule_idx, rule_size] = $2
  rule_size++
  rule_sizes[rule_idx] = rule_size
  next
}

# account and amount, assumes no spaces in account names
NF == 2 {
  account = $1
  amount = to_cents(parse_dollars($2))
  total += amount
  output(date, payee, account, amount)
  next
}

# just account, inferred amount, assumes no spaces in account names
NF == 1 {
  if (inferred)
    die("two inferred amounts in a single transaction on line " NR ": " $0 )
  inferred = $1
  next
}

{ die("skipping line " NR " with " NF " fields and bad format (maybe spaces in account names): " $0 ) }

END {
  # print inferred amount from last transaction
  if (inferred)
    output(date, payee, inferred, total * -1)
}
