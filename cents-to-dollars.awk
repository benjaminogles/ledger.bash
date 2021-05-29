
function pretty_field(f, s) {
  s = $f
  if (f == col)
    s = to_dollars(s)
  return s
}

{
  for (i = 1; i <= NF; i++) {
    printf "%s", pretty_field(i)
    if (i != NF)
      printf "%s", OFS
    else
      printf "\n"
  }
}

