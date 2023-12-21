1. Check if the following data structure are properly maintained
-   struct WolfStakerRegistry has key {
        wolf_staker_addresses: vector<address>,
        wolf_staker_indices: smart_table::SmartTable<address, u64>
    }

-   struct TaxPool has key {
        extend_ref: ExtendRef,
        total_asset: u64,
        total_shares: u64
    }

2. Add more events
3. Check if more view functions would be needed
4. Make sure the config has proper values, the probabilities and description/names.
5. check 86400 value of earning rate before deploying
6. Check all config values

Things to be done
1. add claim fn in frontend (handle decimals of claimable fur amount) --- Done
2. add staking n unstaking balance in ui ---- Done
3. add modal for transaction processing/success --- Done
