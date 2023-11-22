module owner::new_stake {

    use std::signer;
    use aptos_std::smart_table;
    use aptos_framework::object;
    use aptos_framework::timestamp;
    use aptos_framework::object::{ConstructorRef, ExtendRef, DeleteRef, Object};
    use aptos_framework::primary_fungible_store;
    use std::string::{Self};
    use std::debug;
    use owner::config;
    use owner::NFTCollection::{ get_metadata, Character };
    use owner::FURToken;

    struct StakePoolRegistry has key {                      
        fungible_asset_to_stake_pool: smart_table::SmartTable<address, address>
    }

    /// Any pool metadata that's associated here
    /// This is not necessary if you want to use a bare secondary fungible store
    struct Pool has key {
        extend_ref: ExtendRef,
        delete_ref: DeleteRef,

        rabbit_staked_amount: u64,
        baby_wolf_staked_amount: u64,

        unclaimed_rabbit_earnings: u64,
        last_update: u64,
    }

    struct TaxPool has key {
        extend_ref: ExtendRef,
        // delete_ref: DeleteRef,
        total_asset: u64,
        total_shares: u64
    }

    /// Staking not initialized for this account
    const E_NO_STAKE_REGISTRY: u64 = 1;

    /// Pool not found at object address
    const E_NO_POOL_AT_ADDRESS: u64 = 2;

    /// Not enough funds in account to stake the amount given
    const E_NOT_ENOUGH_FUNDS_TO_STAKE: u64 = 3;
    /// Not enough funds in the pool to unstake the amount given
    const E_NOT_ENOUGH_FUNDS_TO_UNSTAKE: u64 = 4;

    

    fun init_module(owner: &signer) {
        let owner_constructor : ConstructorRef = object::create_named_object(owner, b"TaxPool");
        let owner_signer = object::generate_signer(&owner_constructor);
        let extend_ref = object::generate_extend_ref(&owner_constructor);
        // let delete_ref = object::generate_delete_ref(&owner_constructor);
        let tax_pool_info = TaxPool {
            extend_ref,
            // delete_ref,
            total_asset: 0,
            total_shares: 0
        };
        move_to(&owner_signer, tax_pool_info);
    }

    fun wolf_claim_and_unstake(staker: &signer, amount: u64) acquires TaxPool, Pool, StakePoolRegistry {
        let tax_pool = borrow_global_mut<TaxPool>(object::create_object_address(&@owner, b"TaxPool")); 
        let _tax_pool_signer = object::generate_signer_for_extending(&tax_pool.extend_ref);

        let asset_metadata_object = get_metadata(config::baby_wolfie_token_name());
        let asset_metadata_address = object::object_address(&asset_metadata_object);
        let pool_address = retrieve_stake_pool_address(staker, asset_metadata_address);
        let _staker_pool_info = borrow_global_mut<Pool>(pool_address);   
        unstake(staker, asset_metadata_object, amount);
    }

    fun rabbit_claim_and_unstake(staker: &signer, _amount: u64) {

    }

    
    // Convert shares(rabbit amount) to equivalent furtoken
    fun get_exchange_rate(): (u64, u64) acquires TaxPool {
        let tax_pool = borrow_global_mut<TaxPool>(object::create_object_address(&@owner, b"TaxPool"));
        let numerator = tax_pool.total_asset;
        let denominator = tax_pool.total_shares;
        if(denominator == 0) {
            denominator = 1;
            numerator = 0;
        };

        return (numerator, denominator)
    }

    fun update_exchange_rate(amount: u64, fur_amount: u64): bool  acquires TaxPool {
        let tax_pool = borrow_global_mut<TaxPool>(object::create_object_address(&@owner, b"TaxPool"));
        tax_pool.total_asset = tax_pool.total_asset + fur_amount;
        tax_pool.total_shares = tax_pool.total_shares + amount;
        return true
    }


    /// Adds stake to a pool
    public entry fun stake(
        staker: &signer,
        asset_metadata_object: Object<Character>,
        amount: u64
    ) acquires StakePoolRegistry, Pool, TaxPool {
        let staker_addr = signer::address_of(staker);

        // Ensure you can actually stake this amount
        assert!(
            primary_fungible_store::balance(staker_addr, asset_metadata_object) >= amount,
            E_NOT_ENOUGH_FUNDS_TO_STAKE
        );

        let asset_metadata_address = object::object_address(&asset_metadata_object);

        // Ensure stake pool registry exists
        if (!exists<StakePoolRegistry>(staker_addr)) {
            debug::print(&string::utf8(b"No stake registry found, creating!!"));
            create_stake_registry(staker);
        };

        // Use the existing pool if it exists or create a new one
        let pool_address =  create_or_retrieve_stake_pool_address(staker, asset_metadata_address);
        debug::print(&string::utf8(b"Pool address: "));
        debug::print(&pool_address);
    
        let pool = borrow_global_mut<Pool>(pool_address);
        let pool_signer = object::generate_signer_for_extending(&pool.extend_ref);

        let tax_pool_address = object::create_object_address(&@owner, b"TaxPool");

        update_earnings(pool_address);  

        let pool = borrow_global_mut<Pool>(signer::address_of(&pool_signer));
        if(get_metadata(config::rabbit_token_name()) == asset_metadata_object) {
            pool.rabbit_staked_amount = pool.rabbit_staked_amount+amount;
            // debug::print(&string::utf8(b"Rabbit amount after staking: "));
            // debug::print(&pool.rabbit_staked_amount);

            // Now that we have the pool address, add stake
            primary_fungible_store::transfer(staker, asset_metadata_object, pool_address, amount);

            let staker_nft_balance_after_staking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
            debug::print(&string::utf8(b"Staker Rabbit NFT balance after staking: "));
            debug::print(&staker_nft_balance_after_staking);
        }
        else if (get_metadata(config::baby_wolfie_token_name()) == asset_metadata_object) {
            pool.baby_wolf_staked_amount = pool.rabbit_staked_amount+amount;
            // debug::print(&string::utf8(b"Baby Wolfie amount after staking: "));
            // debug::print(&pool.baby_wolf_staked_amount);
            
            // Now that we have the pool address, add stake
            let (num, deno) = get_exchange_rate();
            let fur_amount = amount*num/deno;

            primary_fungible_store::transfer(staker, FURToken::get_metadata(), tax_pool_address, fur_amount);
            primary_fungible_store::transfer(staker, asset_metadata_object, pool_address, amount);
            update_exchange_rate(amount, fur_amount);

            let staker_nft_balance_after_staking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
            debug::print(&string::utf8(b"Staker Wolf NFT balance after staking: "));
            debug::print(&staker_nft_balance_after_staking);
        };
    }

    // fun claim_Fur_earnings(staker: &signer, amount: u64) acquires Pool {
    //     let staker_addr = signer::address_of(staker);
    // }

    fun update_earnings(pool_address: address) acquires Pool {
        let pool = borrow_global_mut<Pool>(pool_address);
        let pool_signer = object::generate_signer_for_extending(&pool.extend_ref);
        let pool = borrow_global_mut<Pool>(signer::address_of(&pool_signer));

        let time_elapsed = timestamp::now_seconds() - pool.last_update;
        let rabbit_earnings = (pool.rabbit_staked_amount * config::daily_earning_rate() * time_elapsed) / 86400u64;
    
        pool.unclaimed_rabbit_earnings = pool.unclaimed_rabbit_earnings + rabbit_earnings;
        pool.last_update = timestamp::now_seconds();
    }

    /// Removes stake from the pool
    public entry fun unstake(
        staker: &signer,
        asset_metadata_object: Object<Character>,
        amount: u64
    ) acquires StakePoolRegistry, Pool {
        let asset_metadata_address = object::object_address(&asset_metadata_object);
        let pool_address = retrieve_stake_pool_address(staker, asset_metadata_address);

        
        let staker_addr = signer::address_of(staker);

        let pool = borrow_global_mut<Pool>(pool_address);
        let pool_signer = object::generate_signer_for_extending(&pool.extend_ref);

        // Check that we have enough to remove
        assert!(
            primary_fungible_store::balance(pool_address, asset_metadata_object) >= amount,
            E_NOT_ENOUGH_FUNDS_TO_UNSTAKE
        );

        if(get_metadata(config::rabbit_token_name()) == asset_metadata_object) {
            pool.rabbit_staked_amount = pool.rabbit_staked_amount-amount;
            // debug::print(&string::utf8(b"Rabbit amount after unstaking: "));
            // debug::print(&pool.rabbit_staked_amount);

            // Now that we have the pool address, remove stake
            primary_fungible_store::transfer(&pool_signer, asset_metadata_object, staker_addr, amount);

            let staker_nft_balance_after_unstaking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
            debug::print(&string::utf8(b"Staker Rabbit NFT balance after unstaking: "));
            debug::print(&staker_nft_balance_after_unstaking);
        }
        else if (get_metadata(config::baby_wolfie_token_name()) == asset_metadata_object) {
            pool.baby_wolf_staked_amount = pool.rabbit_staked_amount-amount;
            // debug::print(&string::utf8(b"Baby Wolfie amount after unstaking: "));
            // debug::print(&pool.baby_wolf_staked_amount);

            // Now that we have the pool address, remove stake
            primary_fungible_store::transfer(&pool_signer, asset_metadata_object, staker_addr, amount);
            //Claim Tax 
            let staker_nft_balance_after_unstaking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
            debug::print(&string::utf8(b"Staker Wolf NFT balance after unstaking: "));
            debug::print(&staker_nft_balance_after_unstaking);
        };
    }

    fun create_stake_registry(staker: &signer) {
        let stake_pool_registry = StakePoolRegistry {
            fungible_asset_to_stake_pool: smart_table::new()
        };
        move_to<StakePoolRegistry>(staker, stake_pool_registry);
    }
    
    fun retrieve_stake_pool_address(
        staker: &signer,
        asset_metadata_address: address
    ): address acquires StakePoolRegistry {
        let staker_addr = signer::address_of(staker);

        // Ensure stake pool registry exists
        assert!(exists<StakePoolRegistry>(staker_addr), E_NO_STAKE_REGISTRY);
        let stake_info = borrow_global<StakePoolRegistry>(staker_addr);

        assert!(smart_table::contains(
            &stake_info.fungible_asset_to_stake_pool,
            asset_metadata_address
        ), E_NO_POOL_AT_ADDRESS);

        *smart_table::borrow(&stake_info.fungible_asset_to_stake_pool, asset_metadata_address)
    }

    fun create_or_retrieve_stake_pool_address(
        staker: &signer,
        asset_metadata_address: address
    ): address acquires StakePoolRegistry {
        let staker_addr = signer::address_of(staker);
        let stake_info = borrow_global_mut<StakePoolRegistry>(staker_addr);

        if(smart_table::contains(
            &stake_info.fungible_asset_to_stake_pool,
            asset_metadata_address
        )) {
            *smart_table::borrow(&stake_info.fungible_asset_to_stake_pool, asset_metadata_address)
            // debug::print(&string::utf8(b"Pool already exists (inside) !!"));
        } else {

            let pool_constructor: ConstructorRef = object::create_object_from_account(staker);
            let pool_signer = object::generate_signer(&pool_constructor);
            let extend_ref = object::generate_extend_ref(&pool_constructor);
            let delete_ref = object::generate_delete_ref(&pool_constructor);

            let pool_address = object::address_from_constructor_ref(&pool_constructor);
            let pool = Pool {
                extend_ref,
                delete_ref,
                
                rabbit_staked_amount: 0u64, 
                baby_wolf_staked_amount: 0u64,

                unclaimed_rabbit_earnings: 0u64,
                last_update: timestamp::now_seconds(),
            };
            smart_table::add(
                &mut stake_info.fungible_asset_to_stake_pool,
                asset_metadata_address,
                pool_address
            );
            move_to<Pool>(&pool_signer, pool);
            pool_address
        }
    }

    #[test_only]
    public fun initialize(sender: &signer) {
        init_module(sender);
    }
}