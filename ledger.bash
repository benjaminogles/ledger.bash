#!/bin/bash

shopt -s nocasematch

report="$1"
shift
flat=0
depth=0
budget=0
plot=0
nototal=0
monthly=0
yearly=0
nopretty=0
context=0
empty=0
accounts=""
start_date=""
end_date=""
bank_csv=""
import_results=""
ledger_file=""

if ! declare -f assign_payee_and_account > /dev/null
then
  assign_payee_and_account_src="${LEDGER_IMPORT_HELPER:-$HOME/.local/share/ledger/import_helper.bash}"
  if [[ -f "$assign_payee_and_account_src" ]]
  then
    source "$assign_payee_and_account_src"
  fi
fi
if ! declare -f assign_payee_and_account > /dev/null
then
  echo "using default (no-op) assign_payee_and_account function"
  assign_payee_and_account() {
    payee=""
    account=""
  }
fi

exit_with_error() {
  echo "$1"
  exit 1
}

user_input() {
  IFS= read -p "$1 " < /dev/tty
  echo "" >> /dev/tty
  echo $REPLY
}

yes_no() {
  if [[ "$(user_input "$1")" =~ ^n ]]
  then
    return 1
  else
    return 0
  fi
}

pick() {
  local picked=$(fzf --height 10)
  if [[ -z "$picked" ]]
  then
    picked=$(user_input "$1")
  fi
  echo "$picked"
}

transactions_raw() {
  awk -f transactions.awk -v OFS=, -v filter="$1" -v start="$2" -v end="$3" -v budget="$4" "$ledger_file" | sort -k 1 -t ,
}

all_transactions() {
  transactions_raw "" "" "" 0
}

default_transactions() {
  transactions_raw "$accounts" "$start_date" "$end_date" $budget
}

transactions_col() {
  awk -F, "{ print \$$1 }"
}

all_accounts() {
  all_transactions | transactions_col 3 | sort -u
}

accounts_report() {
  default_transactions | transactions_col 3 | sort -u
}

all_payees() {
  all_transactions | transactions_col 2 | sort -u
}

payees_report() {
  default_transactions | transactions_col 2 | sort -u
}

pick_account() {
  all_accounts | pick "Account"
}

pick_payee() {
  all_payees | pick "Payee"
}

confirm_payee_and_account() {
  echo "Payee: $payee" >> /dev/tty
  echo "Account: $account" >> /dev/tty
  echo "$(user_input "Correct?")"
}

transactions_report() {
  default_transactions | awk -f cents-to-dollars.awk -F, -v OFS=, -v col=4
}

bal_raw() {
  awk -f bal.awk -F, -v monthly="$1" -v yearly="$2" -v nototal="$3"
}

default_bal() {
  bal_raw $monthly $yearly $nototal
}

monthly_bal() {
  bal_raw 1 0 1
}

yearly_bal() {
  bal_raw 0 1 1
}

bal_format_raw() {
  awk -f bal-annotate.awk | awk -f bal-format.awk -v depth="$1" -v flat="$2" -v empty="$3" -v context="$4" -v nopretty="$5"
}

default_bal_format() {
  bal_format_raw "$depth" $flat $empty $context $nopretty
}

monthly_yearly_bal_format() {
  bal_format_raw "$depth" 1 $empty 1 $nopretty | awk '{ print $1, $3, $2 }' | sort -k 2,2 -k 1
}

bal_report() {
  default_transactions | default_bal | default_bal_format
}

normalize_date() {
  if [[ "$1" =~ [0-9]{4}$ ]]
  then
    echo "$1/01/01"
  elif [[ "$1" =~ [0-9]{4}\/[0-9]{2}$ ]]
  then
    echo "$1/01"
  else
    echo "$1"
  fi
}

monthly_bal_report() {
  default_transactions | monthly_bal | monthly_yearly_bal_format
}

yearly_bal_report() {
  default_transactions | yearly_bal | monthly_yearly_bal_format
}

last_account_date() {
  echo "$(normalize_date "$(transactions_raw "$1" "" "" 0 | transactions_col 1 | tail -n 1)")"
}

preprocess_bank_csv() {
  awk -f bank-csv.awk -v unquote="$1" -v header="$2" -v date_col="$3" -v description_col="$4" -v amount_col="$5" -v after="$6" "$bank_csv"
}

preprocess_chase_csv() {
  preprocess_bank_csv 0 1 2 3 4 "$1"
}

preprocess_wells_fargo_csv() {
  preprocess_bank_csv 1 0 1 5 2 "$1"
}

preprocess_chase_credit_csv() {
  preprocess_bank_csv 0 1 2 3 6 "$1"
}

fresh_file() {
  if [[ -f "$1" ]]
  then
    rm "$1"
  fi
  echo "$1"
}

create_sqlite_db() {
  db=$(fresh_file /tmp/ledger.db)
  sqlite3 $db 'create table transactions (date text not null, payee text not null, account text not null, amount text not null);'
  transactions_report > /tmp/ledger.csv
  sqlite3 $db <<< "
.separator ,
.import /tmp/ledger.csv transactions
"
  echo $db
}

bank_sqlite_db() {
  db=$(create_sqlite_db)
  bank_transactions=$(fresh_file /tmp/bank.csv)
  preprocess_"$1"_csv 0 > $bank_transactions
  sqlite3 $db <<< "
create table bank_transactions (date text not null, description text not null, amount text not null);
.separator ,
.import $bank_transactions bank_transactions
"
echo $db
}

check_bank_csv() {
  db=$(bank_sqlite_db "$1")
  bank_account="$2"
  problems=$(fresh_file /tmp/ledger.problems)
  sqlite3 $db <<< "
create table combined (date text not null, amount real not null);
create table bank_combined (date text not null, amount real not null);
insert into combined select date, sum(cast(amount as real)) from transactions where account = '$bank_account' group by date;
insert into bank_combined select date, sum(cast(amount as real)) from bank_transactions group by date;
.mode csv
.output $problems
.headers on
select Date, Expected, Actual from (
  select
    b.date as Date,
    b.amount as Expected,
    case t.amount when null then 0 else t.amount end as Actual
  from bank_combined b left outer join combined t on b.date = t.date
  where abs(b.amount - t.amount) > .01 or t.date is null
  );
"
  if [[ -s $problems ]]
  then
    echo Potential problems with $bank_account
    cat $problems | column -t -s,
  fi
}

import_bank_csv() {
  bank_transactions=$(fresh_file /tmp/bank.csv)
  bank_account="$2"
  preprocess_"$1"_csv "$3" > $bank_transactions
  import_results="$(fresh_file "$1-imported.dat")"
  while IFS=, read dt desc amt
  do
    echo ===============================================
    echo "$dt, $desc, $amt"
    if ! yes_no "Process?"
    then
      if ! yes_no "Confirm. Process?"
      then
        continue
      fi
    fi

    assign_payee_and_account "$dt" "$desc" "$amt" 
    if [[ ! -z "$payee" ]] && [[ ! -z "$account" ]]
    then
      reply="$(confirm_payee_and_account)"
    elif [[ -z "$payee" ]] && [[ ! -z "$account" ]]
    then
      reply="p"
    elif [[ -z "$account" ]] && [[ ! -z "$payee" ]]
    then
      reply="a"
    else
      reply="n"
    fi

    while [[ ! -z "$reply" ]] && [[ ! "$reply" =~ y ]]
    do
      case "$reply" in
        p) payee=$(pick_payee) ;;
        a) account=$(pick_account) ;;
        *) payee=$(pick_payee); account=$(pick_account) ;;
      esac
      reply="$(confirm_payee_and_account)"
    done

    case "$amt" in
      -*) cat>>"$import_results"<<EOF
$dt $payee
    $account  \$${amt/-/}
    $bank_account
EOF
      ;;
      *) cat>>"$import_results"<<EOF
$dt $payee
    $bank_account  \$$amt
    $account
EOF
      ;;
    esac
  done < $bank_transactions
}

make_budget_transaction() {
  echo 'var accounts = {' > budget-gui/accounts.js
  transactions_raw "" "" "" 1 | bal_raw 0 0 1 | bal_format_raw "" 1 1 0 1 | \
    tr -d "$," | \
    awk '{print "\"" $2 "\":" $1 ","}' >> budget-gui/accounts.js
  echo '}' >> budget-gui/accounts.js

  python3 -m http.server --bind 127.0.0.1 --directory budget-gui &
  server_pid=$!
  xdg-open "http://127.0.0.1:8000"
  read -p "Enter when done..." ignored
  kill -9 $server_pid
}

usage() {
  echo "Usage: $0 <command> [options] <arguments>"
  echo "Commands"
  echo "  bal <accounts>     Report account balances"
  echo "  monthly <accounts> Report account balances by month"
  echo "  yearly <accounts>  Report account balances by year"
  echo "  csv <accounts>     Report transactions in csv format"
  echo "  accounts           Report list of accounts"
  echo "  payees             Report list of payees"
  echo "  db <accounts>      Open SQLite database of transactions"
  echo "  import <file>      Import bank transactions from csv file"
  echo "  check <file>       Validate bank transactions from csv file are recorded correctly"
  echo "Options"
  echo "  --flat             Flatten account tree in bal report"
  echo "  --depth <num>      Limit depth of account tree in bal report"
  echo "  --start            Start date %Y/%m/%d month and day are optional"
  echo "  --end              Start date %Y/%m/%d month and day are optional"
  echo "  --empty            Include empty accounts in bal report"
  echo "  --no-total         Don't print total in bal report"
  echo "  --budget           Print budget accounts"
  echo "  --parse-bank <arg> One of [chase chase_credit wells_fargo]"
  exit 1
}

while [[ ! -z "$1" ]]
do
  case "$1" in
    --flat) flat=1 ;;
    --budget) budget=1 ;;
    --plot) plot=1 ;;
    --depth) depth="$2"; shift ;;
    --start) start_date="$(normalize_date $2)"; shift ;;
    --end) end_date="$(normalize_date $2)"; shift ;;
    --parse-bank) format="$2"; shift ;;
    --empty) empty=1 ;;
    --no-total) nototal=1 ;;
    --no-pretty) nopretty=1 ;;
    *.csv) bank_csv="$1" ;;
    *)
      if [[ -z "$accounts" ]]
      then
        accounts="$1"
      else
        accounts="$accounts|$1"
      fi
      ;;
  esac
  shift
done

if [[ ! -z "$LEDGER_BASH_FILE" ]]
then
  ledger_file="$LEDGER_BASH_FILE"
else
  ledger_dir=${LEDGER_DIR:-$HOME/Documents/finance}
  ledger_ext=${LEDGER_EXT:-in}
  ledger_file=$(fresh_file /tmp/ledger.dat)
  cat "$ledger_dir"/*."$ledger_ext" > $ledger_file
fi

if [[ ! -z "$bank_csv" ]]
then
    if [[ -z "$format" ]]
    then
      echo "Use --parse-bank to choose one of [chase chase_credit wells_fargo]"
      exit 1
    fi
    if [[ -z "$accounts" ]]
    then
      accounts=$(pick_account)
    fi
fi

case "$report" in
  bal) bal_report ;;
  rawbal) default_transactions | default_bal ;;
  csv) transactions_report ;;
  rawcsv) default_transactions ;;
  db) sqlite3 $(create_sqlite_db) ;;
  bankdb) sqlite3 $(bank_sqlite_db "$format") ;;
  import) import_bank_csv "$format" "$accounts" $(last_account_date "$accounts") ;;
  importall) import_bank_csv "$format" "$accounts" 0 ;;
  check) check_bank_csv "$format" "$accounts" ;;
  accounts) accounts_report ;;
  payees) payees_report ;;
  bankcsv) preprocess_"$format"_csv $(last_account_date "$accounts") ;;
  monthly) monthly_bal_report ;;
  yearly) yearly_bal_report ;;
  mkbudget) make_budget_transaction ;;
  *) usage
esac

