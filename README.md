
# ledger.bash

This is a watered down version of [the ledger cli](https://github.com/ledger/ledger) that focuses on a simple budgeting work-flow.
The project started with some bash, SQLite and JavaScript utilities that I used with my ledger setup.
I realized I could implement the ledger features I needed relatively quickly in AWK and customize it along the way.
You should use this if

  - You use ledger but only some of the features
  - You want an interactive script for importing CSV transactions from your bank (after downloading manually)
  - You want a simple way to implement envelope budgeting
  - You want a simple GUI for adjusting your budget
  - You like the idea of tinkering with AWK scripts when things break or you want new features

# Examples

Here is a sample journal file.

```
; Budget rules

= ^Income
  [Savings]                   -0.25
  [Unbudgeted]                -0.75

= ^Expenses
  [$account]                  -1.0

; Transactions

2020/01/01 Salary
  Assets:Bank:Checking        $500
  Income

2020/01/01 Adjust Budget
  [Expenses:Food]             $100
  [Expenses:Fun]              $50
  [Unbudgeted]

2020/01/01 Walmart
  Expenses:Food               $50
  Assets:Bank:Checking

2020/02/01 AMC
  Expenses:Fun                $20
  Assets:Bank:Checking
```

The budget rules activate on transactions to/from accounts that match the supplied regular expression.
This journal allocates 25% of earnings to a savings envelope and sets the rest aside to be budgeted manually as needed (see second transaction).
In addition, an envelope is created for each expense account.

Check the balance of your accounts.
```
$ ledger.bash bal
             $430.00  Assets:Bank:Checking
              $70.00  Expenses
              $50.00    Food
              $20.00    Fun
            $-500.00  Income
--------------------
                0.00
```

Check your budget.
```
$ ledger.bash bal --budget
              $80.00  Expenses
              $50.00    Food
              $30.00    Fun
             $125.00  Savings
             $225.00  Unbudgeted
--------------------
              430.00
```

Filter accounts.
```
$ ledger.bash bal Fun
              $20.00  Expenses:Fun
--------------------
               20.00
```

Date range.
```
$ ledger.bash bal --start 2020/02
             $-20.00  Assets:Bank:Checking
              $20.00  Expenses:Fun
--------------------
                0.00
```

Monthly (or yearly) totals. The depth argument here gives us the monthly total of the Expenses parent account.
```
$ ledger.bash monthly --depth 1 Expenses
2020/01 Expenses $50.00
2020/02 Expenses $20.00
```

Import a CSV of bank transactions.
```
$ ledger.bash import Checking.csv
...
$ cat ledger-imported.dat
```

This command is interactive and requires [FZF](https://github.com/junegunn/fzf).
It helps you assign payee and account names to each transaction and formats it.
You can write a bash script that auto assigns payee and account names.

```bash
$ cat ledger-import-helper.bash
shopt -s nocasematch
assign_payee_and_account() {
  local dt="$1"
  local desc="$2"
  local amt="$3"
  case "$desc" in
    *walmart*)
      payee="Walmart"
      account="Expenses:Food"
      ;;
    *)
      payee="$desc"
      account="Expenses:Misc"
      ;;
  esac
}
$ export LEDGER_IMPORT_HELPER=ledger-import-helper.bash
```

The script should contain a function named `assign_payee_and_account` that assigns global variables `payee` and `account`.
This makes importing really fast for me because most of my transactions are from the same place.

The CSV parsing is currently specific to my bank but the AWK script is parameterized to handle other formats.
It just needs to know whether the fields are quoted and which fields hold the date, description and amount.

When importing a CSV, you don't need to worry about selecting a date range.
Import will start after the last date in your journal file.

The final noteworthy feature of this project is a simple GUI for building up a transaction that adjusts your budget.
```
$ ledger.bash mkbudget
```

This will open a browser with your current budget balance. The account highlighted in green is adjusted to a desired amount by typing the number and hitting enter.
The difference is taken from the account highlighted in grey.
Move the highlight up and down with j/k.
Toggle moving the green/grey account with the space bar.
The transaction that you can copy into your journal file is in the text box at the bottom.

Other commands:

  - List transactions in CSV format
  - List accounts
  - List payees
  - Open SQLite database with transactions table (date, payee, account, amount).

Note: ledger.bash finds the journal file through environment variables:

  - `LEDGER_BASH_FILE` or
  - `LEDGER_DIR` with `LEDGER_EXT`

For example you could have

  - `LEDGER_DIR=$HOME/Documents/finance`
  - `LEDGER_EXT=dat`

And name journal files by year `2020.dat`.

