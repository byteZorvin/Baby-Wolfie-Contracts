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
