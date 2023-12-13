// module owner::new_stake {

//     use std::signer;
//     use aptos_std::smart_table;
//     use aptos_framework::object;
//     use aptos_framework::timestamp;
//     use aptos_framework::object::{ConstructorRef, ExtendRef, DeleteRef, Object};
//     use aptos_framework::primary_fungible_store;
//     use std::string::{Self};
//     use std::debug;
//     use std::vector;
//     use owner::config;
//     use owner::random;
//     use owner::NFTCollection::{ get_metadata, Character };
//     use owner::FURToken;

//     struct StakePoolRegistry has key {                      
//         fungible_asset_to_stake_pool: smart_table::SmartTable<address, address>
//     }

//     struct WolfStakerRegistry has key {
//         wolf_staker_addresses: vector<address>,
//         wolf_staker_indices: smart_table::SmartTable<address, u64>
//     }

    
//     struct RabbitPool has key {
//         extend_ref: ExtendRef,
//         delete_ref: DeleteRef,
//         rabbit_staked_amount: u64,
//         unclaimed_rabbit_earnings: u64,
//         last_update: u64,
//     }

//     struct WolfPool has key {
//         extend_ref: ExtendRef,
//         delete_ref: DeleteRef,
//         baby_wolf_staked_amount: u64,
//     } 

//     struct TaxPool has key {
//         extend_ref: ExtendRef,
//         total_asset: u64,
//         total_shares: u64
//     }

//     /// Staking not initialized for this account
//     const E_NO_STAKE_REGISTRY: u64 = 1;

//     /// Pool not found at object address
//     const E_NO_POOL_AT_ADDRESS: u64 = 2;

//     /// Not enough funds in account to stake the amount given
//     const E_NOT_ENOUGH_FUNDS_TO_STAKE: u64 = 3;
//     /// Not enough funds in the pool to unstake the amount given
//     const E_NOT_ENOUGH_FUNDS_TO_UNSTAKE: u64 = 4;

    

//     fun init_module(owner: &signer) {
//         let owner_constructor : ConstructorRef = object::create_named_object(owner, b"staking_module");
//         let owner_signer = object::generate_signer(&owner_constructor);
//         let extend_ref = object::generate_extend_ref(&owner_constructor);
//         let tax_pool_info = TaxPool {
//             extend_ref,
//             total_asset: 0,
//             total_shares: 0
//         };
//         let wolf_staker_registry = WolfStakerRegistry {
//             wolf_staker_addresses: vector::empty<address>(),
//             wolf_staker_indices: smart_table::new()
//         };
//         move_to(&owner_signer, wolf_staker_registry);
//         move_to(&owner_signer, tax_pool_info);
//     }

//     #[view]
//     // Convert shares(rabbit amount) to equivalent furtoken
//     fun get_exchange_rate(): (u64, u64) acquires TaxPool {
//         let tax_pool = borrow_global_mut<TaxPool>(object::create_object_address(&@owner, b"staking_module"));
//         let numerator = tax_pool.total_asset;
//         let denominator = tax_pool.total_shares;
//         if(denominator == 0) {
//             denominator = 1;
//             numerator = 0;
//         };

//         return (numerator, denominator)
//     }

//     fun update_exchange_rate(amount: u64, fur_amount: u64): bool  acquires TaxPool {
//         let tax_pool = borrow_global_mut<TaxPool>(object::create_object_address(&@owner, b"staking_module"));
//         tax_pool.total_asset = tax_pool.total_asset + fur_amount;
//         tax_pool.total_shares = tax_pool.total_shares + amount;
//         return true
//     }


//     /// Adds stake to a pool
//     public entry fun stake(
//         staker: &signer,
//         asset_metadata_object: Object<Character>,
//         amount: u64
//     ) acquires StakePoolRegistry, RabbitPool, WolfPool, TaxPool, WolfStakerRegistry {
        
//         let staker_addr = signer::address_of(staker);
        
//         // Ensure you can actually stake this amount
//         assert!(
//             primary_fungible_store::balance(staker_addr, asset_metadata_object) >= amount,
//             E_NOT_ENOUGH_FUNDS_TO_STAKE
//         );


//         // Ensure stake pool registry exists
//         if (!exists<StakePoolRegistry>(staker_addr)) {
//             debug::print(&string::utf8(b"No stake registry found, creating!!"));
//             create_stake_registry(staker);
//         };

//         // Use the existing pool if it exists or create a new one
//         let pool_address =  create_or_retrieve_stake_pool_address(staker, asset_metadata_object);
//         debug::print(&string::utf8(b"Pool address: "));
//         debug::print(&pool_address);
    
    
//         let tax_pool_address = object::create_object_address(&@owner, b"staking_module");

//         if(get_metadata(config::rabbit_token_name()) == asset_metadata_object) {
//             update_earnings(&pool_address);  
//             let rabbit_pool = borrow_global_mut<RabbitPool>(pool_address);
//             let rabbit_pool_signer = object::generate_signer_for_extending(&rabbit_pool.extend_ref);
//             let rabbit_pool = borrow_global_mut<RabbitPool>(signer::address_of(&rabbit_pool_signer));
//             rabbit_pool.rabbit_staked_amount = rabbit_pool.rabbit_staked_amount+amount;
//             // debug::print(&string::utf8(b"Rabbit amount after staking: "));
//             // debug::print(&pool.rabbit_staked_amount);

//             // Now that we have the pool address, add stake
//             primary_fungible_store::transfer(staker, asset_metadata_object, pool_address, amount);

//             let staker_nft_balance_after_staking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
//             debug::print(&string::utf8(b"Staker Rabbit NFT balance after staking: "));
//             debug::print(&staker_nft_balance_after_staking);
//         }
//         else if (get_metadata(config::baby_wolfie_token_name()) == asset_metadata_object) {    
//             let wolf_pool = borrow_global_mut<WolfPool>(pool_address);        
//             let wolf_pool_signer = object::generate_signer_for_extending(&wolf_pool.extend_ref);
//             let wolf_pool = borrow_global_mut<WolfPool>(signer::address_of(&wolf_pool_signer));
//             wolf_pool.baby_wolf_staked_amount = wolf_pool.baby_wolf_staked_amount+amount;
//             // debug::print(&string::utf8(b"Baby Wolfie amount after staking: "));
//             // debug::print(&pool.baby_wolf_staked_amount);
            
//             // Now that we have the pool address, add stake
//             let (num, deno) = get_exchange_rate();
//             let fur_amount = amount*num/deno;

//             if(fur_amount > 0) {
//                 primary_fungible_store::transfer(staker, FURToken::get_metadata(), tax_pool_address, fur_amount);
//             };
//             primary_fungible_store::transfer(staker, asset_metadata_object, pool_address, amount);
//             update_exchange_rate(amount, fur_amount);

//             let staker_nft_balance_after_staking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
//             debug::print(&string::utf8(b"Staker Wolf NFT balance after staking: "));
//             debug::print(&staker_nft_balance_after_staking);

//             push_staker(staker_addr);
//         };
//     }

//     fun push_staker(staker: address) acquires WolfStakerRegistry {
//         let wolf_staker_registry_address = object::create_object_address(&@owner, b"staking_module");
//         let wolf_staker_registry = borrow_global_mut<WolfStakerRegistry>(wolf_staker_registry_address);
//         if(!smart_table::contains(&wolf_staker_registry.wolf_staker_indices, staker)) {
//             vector::push_back(&mut wolf_staker_registry.wolf_staker_addresses, staker);
//             smart_table::add(&mut wolf_staker_registry.wolf_staker_indices, staker, vector::length(&wolf_staker_registry.wolf_staker_addresses));
//         };
//     }

//     fun pop_staker(staker: address) acquires WolfStakerRegistry {
//         let wolf_staker_registry_address = object::create_object_address(&@owner, b"staking_module");
//         let wolf_staker_registry = borrow_global_mut<WolfStakerRegistry>(wolf_staker_registry_address);
//         let balance = get_staking_balance(staker, config::baby_wolfie_token_name());
//         if(balance == 0) {
//             if(smart_table::contains(&wolf_staker_registry.wolf_staker_indices, staker)) {
//                 let index = smart_table::borrow(&wolf_staker_registry.wolf_staker_indices, staker);

//                 vector::
//                 vector::pop_back(&mut wolf_staker_registry.wolf_staker_addresses);
//             }
//         };
//     }

//     #[view]
//     public fun get_staking_balance(staker: address, asset_name: String): u64 acquires RabbitPool, WolfPool, StakePoolRegistry{
//         let asset_metadata_object = get_metadata(asset_name);
//         let asset_metadata_address = object::object_address(&asset_metadata_object);
//         let pool_address = retrieve_stake_pool_address(staker, asset_metadata_address);

//         if(config::baby_wolfie_token_name() == asset_name) {
//             let wolfie_pool_amt = borrow_global_mut<WolfPool>(wolfie_pool_address).baby_wolf_staked_amount;
//             debug::print(&string::utf8(b"Wolfie Staking amount: "));
//             debug::print(&wolfie_pool_amt);
//             wolfie_pool_amt

//         }
//         else if(config::rabbit_token_name() == asset_name) {
//             let rabbit_pool_amt = borrow_global_mut<RabbitPool>(rabbit_pool_address).rabbit_staked_amount;
//             debug::print(&string::utf8(b"Rabbit Staking amount: "));
//             debug::print(&rabbit_pool_amt);
//             rabbit_pool_amt 
//         };
//     }

//     // fun claim_Fur_earnings(staker: &signer, amount: u64) acquires Pool {
//     //     let staker_addr = signer::address_of(staker);
    
//     // }

//     fun update_earnings(pool_address: &address) acquires RabbitPool {
//         let pool = borrow_global_mut<RabbitPool>(*pool_address);
//         let pool_signer = object::generate_signer_for_extending(&pool.extend_ref);
//         let pool = borrow_global_mut<RabbitPool>(signer::address_of(&pool_signer));

//         let time_elapsed = timestamp::now_seconds() - pool.last_update;
//         let rabbit_earnings = (pool.rabbit_staked_amount * config::daily_earning_rate() * time_elapsed) / 86400u64;
    
//         pool.unclaimed_rabbit_earnings = pool.unclaimed_rabbit_earnings + rabbit_earnings;
//         debug::print(&string::utf8(b"Unclaimed Rabbit Earning"));
//         debug::print(&pool.unclaimed_rabbit_earnings);
//         pool.last_update = timestamp::now_seconds();
//     }


//     public entry fun claim_rabbit_fur_earnings(pool_address: address, staker_addr: address, all_stolen: bool) acquires RabbitPool {
//         debug::print(&string::utf8(b"inside rabbit claim fun"));
//         let pool = borrow_global_mut<RabbitPool>(pool_address);
//         let tax_pool_addr = object::create_object_address(&@owner, b"staking_module");
//         debug::print(&string::utf8(b"Unclaimed Rabbit Earning to be claimed"));
//         debug::print(&pool.unclaimed_rabbit_earnings);
//         let tax_share = pool.unclaimed_rabbit_earnings * config::rabbit_tax_rate() / 100u64;
//         debug::print(&string::utf8(b"Tax Share"));
//         debug::print(&tax_share);
//         if(all_stolen == true) {
//             tax_share = pool.unclaimed_rabbit_earnings;
//         };
//         if(pool.unclaimed_rabbit_earnings > 0) {
//             FURToken::mint(staker_addr, pool.unclaimed_rabbit_earnings - tax_share);
//             FURToken::mint(tax_pool_addr, tax_share);
//         };        
//         pool.unclaimed_rabbit_earnings = 0;
//         pool.last_update = timestamp::now_seconds();
//     }

//     fun disburse_wolf_tax_earnings(_staker: &signer, _amount: u64) acquires TaxPool {
//         let tax_pool = borrow_global_mut<TaxPool>(object::create_object_address(&@owner, b"staking_module")); 
//         let _tax_pool_signer = object::generate_signer_for_extending(&tax_pool.extend_ref);  

//     }

//     /// Removes stake from the pool
//     public entry fun unstake(
//         staker: &signer,
//         asset_metadata_object: Object<Character>,
//         amount: u64
//     ) acquires StakePoolRegistry, RabbitPool, WolfPool {
//         let asset_metadata_address = object::object_address(&asset_metadata_object);
//         let pool_address = retrieve_stake_pool_address(signer::address_of(staker), asset_metadata_address);

        
//         let staker_addr = signer::address_of(staker);  

//         // Check that we have enough to remove
//         assert!(
//             primary_fungible_store::balance(pool_address, asset_metadata_object) >= amount,
//             E_NOT_ENOUGH_FUNDS_TO_UNSTAKE
//         );

//         if(get_metadata(config::rabbit_token_name()) == asset_metadata_object) {
//             update_earnings(&pool_address);
//             let rabbit_pool = borrow_global_mut<RabbitPool>(pool_address);
//             let rabbit_pool_signer = object::generate_signer_for_extending(&rabbit_pool.extend_ref);
//             rabbit_pool.rabbit_staked_amount = rabbit_pool.rabbit_staked_amount-amount;
//             // debug::print(&string::utf8(b"Rabbit amount in the pool after unstaking: "));
//             // debug::print(&pool.rabbit_staked_amount);

//             // Now that we have the pool address, remove stake
//             primary_fungible_store::transfer(&rabbit_pool_signer, asset_metadata_object, staker_addr, amount);

//             let staker_nft_balance_after_unstaking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
//             debug::print(&string::utf8(b"Staker Rabbit NFT balance after unstaking: "));
//             debug::print(&staker_nft_balance_after_unstaking);
            
//             let random_number = random::rand_u64_range_no_sender(0, 2);
//             debug::print(&string::utf8(b"Random number: "));
//             debug::print(&random_number);
//             if(random_number == 0) {
//                 claim_rabbit_fur_earnings(pool_address, staker_addr, true);
//             }
//             else {
//                 claim_rabbit_fur_earnings(pool_address, staker_addr, false);
//             }
//             // Transfer the owner with its fur earnings
//         }
//         else if (get_metadata(config::baby_wolfie_token_name()) == asset_metadata_object) {
//             let wolf_pool = borrow_global_mut<WolfPool>(pool_address);
//             let wolf_pool_signer = object::generate_signer_for_extending(&wolf_pool.extend_ref);
//             wolf_pool.baby_wolf_staked_amount = wolf_pool.baby_wolf_staked_amount - amount;
//             // debug::print(&string::utf8(b"Baby Wolfie amount in the pool after unstaking: "));
//             // debug::print(&pool.baby_wolf_staked_amount);

//             // Now that we have the pool address, remove stake
//             primary_fungible_store::transfer(&wolf_pool_signer, asset_metadata_object, staker_addr, amount);
//             let staker_nft_balance_after_unstaking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
//             debug::print(&string::utf8(b"Staker Wolf NFT balance after unstaking: "));
//             debug::print(&staker_nft_balance_after_unstaking);

//             // Transfer the user with its tax earnings
//         };
//     }

//     fun create_stake_registry(staker: &signer) {
//         let stake_pool_registry = StakePoolRegistry {
//             fungible_asset_to_stake_pool: smart_table::new()
//         };
//         move_to<StakePoolRegistry>(staker, stake_pool_registry);
//     }
    
//     #[view]
//     public fun retrieve_stake_pool_address(
//         staker: address,
//         asset_metadata_address: address
//     ): address acquires StakePoolRegistry {

//         // Ensure stake pool registry exists
//         assert!(exists<StakePoolRegistry>(staker), E_NO_STAKE_REGISTRY);
//         let stake_info = borrow_global<StakePoolRegistry>(staker);

//         assert!(smart_table::contains(
//             &stake_info.fungible_asset_to_stake_pool,
//             asset_metadata_address
//         ), E_NO_POOL_AT_ADDRESS);

//         *smart_table::borrow(&stake_info.fungible_asset_to_stake_pool, asset_metadata_address)
//     }

//     fun create_or_retrieve_stake_pool_address(
//         staker: &signer,
//         asset_metadata_object: Object<Character>,
//     ): address acquires StakePoolRegistry {
//         let staker_addr = signer::address_of(staker);
//         let stake_info = borrow_global_mut<StakePoolRegistry>(staker_addr);
//         let asset_metadata_address = object::object_address(&asset_metadata_object);


//         if(smart_table::contains(
//             &stake_info.fungible_asset_to_stake_pool,
//             asset_metadata_address
//         )) {
//             *smart_table::borrow(&stake_info.fungible_asset_to_stake_pool, asset_metadata_address)
//             // debug::print(&string::utf8(b"Pool already exists (inside) !!"));
//         } else {

//             let pool_constructor: ConstructorRef = object::create_object_from_account(staker);
//             let pool_signer = object::generate_signer(&pool_constructor);
//             let extend_ref = object::generate_extend_ref(&pool_constructor);
//             let delete_ref = object::generate_delete_ref(&pool_constructor);

//             let pool_address = object::address_from_constructor_ref(&pool_constructor);
        

//             if(get_metadata(config::rabbit_token_name()) == asset_metadata_object) {

//                 let rabbit_pool = RabbitPool {
//                     extend_ref,
//                     delete_ref,
//                     rabbit_staked_amount: 0u64,
//                     unclaimed_rabbit_earnings: 0u64,
//                     last_update: timestamp::now_seconds(),
//                 };
//                 move_to<RabbitPool>(&pool_signer, rabbit_pool);
//             }
//             else if(get_metadata(config::baby_wolfie_token_name()) == asset_metadata_object) {
//                 let wolf_pool = WolfPool {
//                     extend_ref,
//                     delete_ref,
//                     baby_wolf_staked_amount: 0u64,
//                 };
//                 move_to<WolfPool>(&pool_signer, wolf_pool);
//             };
//             smart_table::add(
//                 &mut stake_info.fungible_asset_to_stake_pool,
//                 asset_metadata_address,
//                 pool_address
//             );
//             pool_address
//         }
//     }

//     #[test_only]
//     public fun initialize(sender: &signer) {
//         init_module(sender);
//     }
// }