
BEGIN { context = "*" }

function reset(ctx) {
  count = 0
  command = "sort"
  for (acct in bal) {
    count++
    print context, acct, to_dollars(bal[acct]) | command
  }
  close(command)
  if (count && !nototal)
    print to_dollars(total)
  delete bal
  total = 0
  context = ctx
}

function check_context(ctx) {
  if (context == "*")
    context = ctx
  else if (context != ctx)
    reset(ctx)
}

function year(d) {
  return substr(d, 1, 4)
}

function year_month(d) {
  return substr(d, 1, 7)
}

yearly && NF == 4 { check_context(year($1)) }

monthly && NF == 4 { check_context(year_month($1)) }

NF == 4 {
  cents = $4
  levels = split($3, accounts, /:/)
  for (i = 1; i <= levels; i++) {
    account = ""
    for (j = 1; j <= i; j++) {
      if (account)
        account = account ":"
      account = account accounts[j]
    }
    bal[account] += cents
  }
  total += cents
  next
}

{ print "bal.awk: skipping line " NR " with " NF " fields and bad format: " $0 }

END { reset("*") }
