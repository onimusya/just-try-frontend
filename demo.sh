#!/usr/bin/env bash
dfx stop
set -e
trap 'dfx stop' EXIT

echo "===========SETUP========="
dfx start --background --clean
export MINTER=$(dfx --identity anonymous identity get-principal)
export DEFAULT=$(dfx identity get-principal)
dfx deploy icrc1_ledger_canister --argument "(variant { Init =
record {
     token_symbol = \"TRY\";
     token_name = \"Just Try\";
     minting_account = record { owner = principal \"${MINTER}\" };
     transfer_fee = 10_000;
     metadata = vec {};
     initial_balances = vec { record { record { owner = principal \"${DEFAULT}\"; }; 10_000_000_000; }; };
     archive_options = record {
         num_blocks_to_archive = 1000;
         trigger_threshold = 2000;
         controller_id = principal \"${MINTER}\";
     };
 }
})"
dfx canister call icrc1_ledger_canister icrc1_balance_of "(record {
  owner = principal \"${DEFAULT}\";
  }
)"
echo "===========SETUP DONE========="

dfx deploy just-try-backend

dfx canister call icrc1_ledger_canister icrc1_transfer "(record {
  to = record {
    owner = principal \"$(dfx canister id just-try-backend)\";
  };
  amount = 1_000_000_000;
})"

dfx canister call just-try-backend transfer "(record {
  amount = 100_000_000;
  toAccount = record {
    owner = principal \"$(dfx identity get-principal)\";
  };
})"

echo "DONE"