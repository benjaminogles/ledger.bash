
NF == 3 {
  ++idx
  inputs[idx, 1] = $1
  inputs[idx, 2] = $2
  inputs[idx, 3] = $3
  children[$2] = 0

  leaf = match($2, /:[^:]*$/)
  parent = substr($2, 1, leaf-1)
  children[parent]++
}

NF == 1 { total = $1 }

END {
  for (i = 1; i <= idx; i++)
    print inputs[i, 1], inputs[i, 2], inputs[i, 3], children[inputs[i, 2]]
  print total
}

