
NF == 4 {
  ctx =$1
  account = $2
  amount = $3
  children = $4

  if (!amount && !empty)
    next

  levels = split(account, accounts, /:/)

  if (flat && children > 0 && (!depth || levels < depth))
    next

  if (depth && levels > depth)
    next

  if (children == 1 && levels != depth) {
    flat_override++
    next
  }

  if (!flat && flat_override) {
    indent = levels - flat_override
    account = accounts[levels]
    for (i = levels - 1; i >= indent; i--)
        account = accounts[i] ":" account
  } else if (flat) {
    indent = 1
  } else {
    indent = levels
    gsub(/.*:/, "", account)
  }

  flat_override = 0

  printf "%s%20s%*s%s\n", (context ? ctx : ""), (nopretty ? amount : pretty_dollars(amount)), 2 * indent, "", account
}

# total
NF == 1 {
  printf("--------------------\n")
  printf("%20s\n", sprintf("%0.2f", $1))
}

