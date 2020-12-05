#!/bin/bash

TMP_EXPECTED=/tmp/ledger-expected.tmp
TMP_ACTUAL=/tmp/ledger-actual.tmp

echo "================================================================================"
echo "Running all tests"
echo "================================================================================"
for t in $(find test -name "*.txt")
do
  args=$(head -n 1 $t)
  in="${t%.*.txt}.ledger"
  tail -n +2 $t > $TMP_EXPECTED
  LEDGER_BASH_FILE=$in ./ledger.bash $args > $TMP_ACTUAL
  if ! diff --strip-trailing-cr $TMP_ACTUAL $TMP_EXPECTED
  then
    echo "Failed $t"
    exit 1
  else
    echo "Passed $t"
  fi
done

