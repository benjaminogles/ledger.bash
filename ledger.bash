#!/bin/bash

shopt -s nocasematch

report="$1"
shift
real=0
flat=0
depth=0
budget=0
plot=0
accounts=""
bank_csv=""
import_results=""

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

transactions_raw_report() {
  awk -f transactions.awk -v OFS=, -v real="$1" -v budget="$2" -v filter="$3" $LEDGER_FILE | sort -k 1 -t ,
}

all_transactions() {
  transactions_raw_report 0 0 ""
}

default_transactions() {
  transactions_raw_report $real $budget "$accounts"
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
  default_transactions | awk -f cents-to-dollars.awk -F, -v OFS=, -v col=4 -v pretty=${1:-1}
}

bal_raw_report() {
  default_transactions | awk -F, -f bal.awk
}

bal_report() {
  bal_raw_report | awk -f bal-annotate.awk | awk -f bal-format.awk -v flat=$flat -v depth="$depth"
}

preprocess_bank_csv() {
  thresh=$(all_transactions | awk -F, '{print $1}' | tail -n 1)
  awk -f bank-csv.awk -v date_col=1 -v description_col=5 -v amount_col=2 -v unquote=1 -v after="${2:-$thresh}" "$1"
}

fresh_file() {
  if [[ -f "$1" ]]
  then
    if [[ $2 -eq 1 ]]
    then
      read -p "$1 exists, ok to replace?"
      if [[ "$REPLY" =~ n ]]
      then
        exit_with_error "$1 already exists"
      fi
    fi
    rm "$1"
  fi
  echo "$1"
}

create_sqlite_db() {
  db=$(fresh_file /tmp/ledger.db)
  sqlite3 $db 'create table transactions (date text not null, payee text not null, account text not null, amount text not null);'
  transactions_report 0 > /tmp/ledger.csv
  sqlite3 $db <<< "
.separator ,
.import /tmp/ledger.csv transactions
"
  echo $db
}

bank_sqlite_db() {
  db=$(create_sqlite_db)
  bank_transactions=$(fresh_file /tmp/bank.csv)
  preprocess_bank_csv "$1" 0 > $bank_transactions
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

import_one() {
  local dt="$1"
  local desc="$2"
  local amt="$3"
  echo ===============================================
  echo "$dt, $desc, $amt"
  if ! yes_no "Process?"
  then
    if ! yes_no "Confirm. Process?"
    then
      return
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
}

import_bank_csv() {
  bank_transactions=$(fresh_file /tmp/bank.csv)
  preprocess_bank_csv "$1" > $bank_transactions
  import_results=$(fresh_file ledger-imported.dat 1)
  bank_account="$2"
  while IFS=, read dt desc amt
  do
    import_one "$dt" "$desc" "$amt"
  done < $bank_transactions
  check_bank_csv "$1"
}

usage() {
  echo "Usage: $0 <command> [options] <arguments>"
  echo "Commands"
  echo "  bal <accounts> Report account balances"
  echo "  csv <accounts> Report transactions in csv format"
  echo "  accounts       Report list of accounts"
  echo "  payees         Report list of payees"
  echo "  db <accounts>  Open SQLite database of transactions"
  echo "  import <file>  Import bank transactions from csv file"
  echo "  check <file>   Validate bank transactions from csv file are recorded correctly"
  echo "Options"
  echo "  --flat         Flatten account tree in bal report"
  echo "  --depth <num>  Limit depth of account tree in bal report"
  echo "  --real         Don't print budget accounts"
  echo "  --budget       Only print budget accounts"
  echo "  --plot         Plot report"
  exit 1
}

while [[ ! -z "$1" ]]
do
  case "$1" in
    --flat) flat=1 ;;
    --real) real=1 ;;
    --budget) budget=1 ;;
    --plot) plot=1 ;;
    --depth) depth="$2"; shift ;;
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

case "$report" in
  bal) bal_report ;;
  rawbal) bal_raw_report ;;
  csv) transactions_report ;;
  rawcsv) default_transactions ;;
  db) sqlite3 $(create_sqlite_db) ;;
  bankdb) sqlite3 $(bank_sqlite_db "$bank_csv") ;;
  import) import_bank_csv "$bank_csv" $(pick_account) ;;
  check) check_bank_csv "$bank_csv" ${accounts:-$(pick_account)} ;;
  accounts) accounts_report ;;
  payees) payees_report ;;
  bankcsv) preprocess_bank_csv "$bank_csv" ;;
  *) usage
esac

