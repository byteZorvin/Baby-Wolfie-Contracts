module owner::NFTCollection {
    use aptos_framework::fungible_asset;
    use aptos_framework::object::{Self, Object, ConstructorRef, ExtendRef, DeleteRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::event;
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use aptos_framework::aptos_coin::AptosCoin;
    use std::math64::{pow};
    use aptos_framework::coin;
    use aptos_framework::account;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::debug;
    use std::signer;
    use aptos_std::smart_table;
    use aptos_framework::timestamp;
    use std::vector;
    use owner::random;
    use owner::FURToken;
    use owner::config;

    //Error codes
    const ENOT_CREATOR: u64 = 0;

    /// All NFTs of Gen0 have been minted 
    const EALL_MINTED: u64 = 1;
    
    // Insufficient apt balance to mint the NFT
    const EINSUFFICIENT_APT_BALANCE: u64 = 2;

    /// Staking not initialized for this account
    const E_NO_STAKE_REGISTRY: u64 = 1;

    /// Pool not found at object address
    const E_NO_POOL_AT_ADDRESS: u64 = 2;

    /// Not enough funds in account to stake the amount given
    const E_NOT_ENOUGH_FUNDS_TO_STAKE: u64 = 3;

    /// Not enough funds in the pool to unstake the amount given
    const E_NOT_ENOUGH_FUNDS_TO_UNSTAKE: u64 = 4;


    struct AssetMintingEvent has drop, store {
        receiver: address,
        asset_minted: address,
    } 

    struct StakingEvent has drop, store {
        staker: address,
        asset_staked: address,
        amount: u64,
    }

    struct UnstakingEvent has drop, store {
        staker: address,
        asset_unstaked: address,
        amount: u64,
    }

    struct WolfEarningEvent has drop, store {
        staker: address,
        staker_earning: u64,
    }

    struct Events has key {
        asset_minting_events: event::EventHandle<AssetMintingEvent>,
        staking_events: event::EventHandle<StakingEvent>,
        unstaking_events: event::EventHandle<UnstakingEvent>,
        wolf_earning_event: event::EventHandle<WolfEarningEvent>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Character has key {
        /// Used to mutate properties
        property_mutator_ref: property_map::MutatorRef,
        /// Used to mint fungible assets.
        fungible_asset_mint_ref: fungible_asset::MintRef,
        /// Used to burn fungible assets.
        fungible_asset_burn_ref: fungible_asset::BurnRef,
    }

    struct StakePoolRegistry has key {                      
        fungible_asset_to_stake_pool: smart_table::SmartTable<address, address>
    }

    struct WolfStakerRegistry has key {
        wolf_staker_addresses: vector<address>,
        wolf_staker_indices: smart_table::SmartTable<address, u64>
    }
    
    struct RabbitPool has key {
        extend_ref: ExtendRef,
        delete_ref: DeleteRef,
        rabbit_staked_amount: u64,
        unclaimed_rabbit_earnings: u64,
        last_update: u64,
    }

    struct WolfPool has key {
        extend_ref: ExtendRef,
        delete_ref: DeleteRef,
        baby_wolf_staked_amount: u64,
    } 

    struct TaxPool has key {
        extend_ref: ExtendRef,
        total_asset: u64,
        total_shares: u64
    }

    fun init_module(owner: &signer) {
        let owner_constructor : ConstructorRef = object::create_named_object(owner, b"staking_module");
        let owner_signer = object::generate_signer(&owner_constructor);
        let extend_ref = object::generate_extend_ref(&owner_constructor);
        let tax_pool_info = TaxPool {
            extend_ref,
            total_asset: 0,
            total_shares: 0
        };
        let wolf_staker_registry = WolfStakerRegistry {
            wolf_staker_addresses: vector::empty<address>(),
            wolf_staker_indices: smart_table::new()
        };
        create_character_collection(owner);
        create_chracter_token_as_fungible_token(
            owner,
            string::utf8(b"Rabbit Token Description"),
            config::rabbit_token_name(),
            string::utf8(b"https://bafybeiafmuce635heed7zzqontthynbosin743cmsm6fa76gutb2p67mpm.ipfs.dweb.link/?filename=rabbit.png"),
            option::some(13500u128),
            string::utf8(b"Rabbit"),
            config::rabbit_symbol_name(),
            string::utf8(b"https://bafybeiafmuce635heed7zzqontthynbosin743cmsm6fa76gutb2p67mpm.ipfs.dweb.link/?filename=rabbit.png"),
            string::utf8(b"https://www.aptoslabs.com"),
        );
        create_chracter_token_as_fungible_token(
            owner,
            string::utf8(b"Baby Wolfie Token Description"),
            config::baby_wolfie_token_name(),
            string::utf8(b"https://bafybeidl6etzb2yc4qmbla7ualpngepastit4pyin2uxrapc4qjqlib6wm.ipfs.dweb.link/wolf.png"),
            option::some(1500u128),
            string::utf8(b"Baby Wolfie"),
            config::baby_wolfie_symbol_name(),
            string::utf8(b"https://bafybeidl6etzb2yc4qmbla7ualpngepastit4pyin2uxrapc4qjqlib6wm.ipfs.dweb.link/wolf.png"),
            string::utf8(b"https://www.aptoslabs.com"),
        );
        move_to(&owner_signer, wolf_staker_registry);
        move_to(&owner_signer, tax_pool_info);
        move_to(owner, Events {
            asset_minting_events: account::new_event_handle<AssetMintingEvent>(owner),
            staking_events: account::new_event_handle<StakingEvent>(owner),
            unstaking_events: account::new_event_handle<UnstakingEvent>(owner),
            wolf_earning_event: account::new_event_handle<WolfEarningEvent>(owner),
        });
    }


    fun create_character_collection(creator: &signer) {
        // Constructs the strings from the bytes.
        let description = config::collection_description();
        let name = config::collection_name();
        let uri = config::collection_uri();
        let maxSupply = 2;    // No of different tokens (wolf n rabbit)

        // Creates the collection with fixed supply
        collection::create_fixed_collection(
            creator,
            description,
            maxSupply,
            name,
            option::none(),
            uri,
        );
    }

    fun create_chracter_token_as_fungible_token(
        creator: &signer,
        description: String,
        name: String,
        uri: String,
        max_supply: Option<u128>,
        fungible_asset_name: String,
        fungible_asset_symbol: String,
        icon_uri: String,
        project_uri: String,
    ) {
        // The collection name is used to locate the collection object and to create a new token object.
        let collection = config::collection_name();

        let constructor_ref = token::create_named_token(
            creator,
            collection,
            description,
            name,
            option::none(),
            uri,
        );

        // Generates the object signer and the refs. The object signer is used to publish a resource
        // under the token object address. The refs are used to manage the token.
        let object_signer = object::generate_signer(&constructor_ref);
        let property_mutator_ref = property_map::generate_mutator_ref(&constructor_ref);

        // Creates the fungible asset.
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            max_supply,
            fungible_asset_name,
            fungible_asset_symbol,
            0,
            icon_uri,
            project_uri,
        );

        let fungible_asset_mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let fungible_asset_burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);

        // Publishes the Character resource with the refs.
        let character_token = Character {
            property_mutator_ref,
            fungible_asset_mint_ref,
            fungible_asset_burn_ref,
        };
        move_to(&object_signer, character_token);
    }

    #[view]
    public fun rabbit_token_address(): address {
        token::create_token_address(&@owner, &config::collection_name(), &config::rabbit_token_name())
    }

    #[view]
    public fun baby_wolfie_token_address(): address {
        token::create_token_address(&@owner, &config::collection_name(), &config::baby_wolfie_token_name())
    }
    
    #[view]
    public fun get_balance_rabbit(user: address): u64{
        primary_fungible_store::balance(user, get_metadata(config::rabbit_token_name()))
    }

    #[view]
    public fun get_balance_baby_wolfie(user: address): u64 {
        primary_fungible_store::balance(user, get_metadata(config::baby_wolfie_token_name()))
    }  

    #[view]
    public fun get_wolfie_supply(): Option<u128> {
        let wolfie_metadata = get_metadata(config::baby_wolfie_token_name());
        fungible_asset::supply(wolfie_metadata)
    }

    #[view]
    public fun get_rabbit_supply(): Option<u128> {
        let rabbit_metadata = get_metadata(config::rabbit_token_name());
        fungible_asset::supply(rabbit_metadata)
    }

    #[view]
    public fun get_total_supply(): u128 {
        let wolf_supply = option::destroy_some<u128>(get_wolfie_supply());
        let rabbit_supply = option::destroy_some<u128>(get_rabbit_supply());
        return wolf_supply + rabbit_supply
    }
    
    public entry fun mint(creator: &signer, receiver: address, amount: u64) acquires Character, Events, WolfStakerRegistry {
        let i = 1;
        while (i <= amount) {
            let random_number_for_mint = random::rand_u64_range_no_sender(0, 101);
            let is_rabbit = random_number_for_mint <= config::rabbit_probability();

            let random_number_for_steal = random::rand_u64_range(signer::address_of(creator), 0, 101);
            let is_steal = random_number_for_steal <= config::steal_probability();

            debug::print(&string::utf8(b"Random number for mint generated in NFTCollection::mint() is: "));
            debug::print(&random_number_for_mint);

            debug::print(&string::utf8(b"Random number for steal generated in NFTCollection::mint() is: "));
            debug::print(&random_number_for_steal);

            if(is_rabbit) {
                let wolf_players = get_wolf_players();
                debug::print(&string::utf8(b"Wolf player vec length"));
                debug::print(&vector::length(&wolf_players));
                if(vector::length(&wolf_players) > 0 && is_steal) {
                    debug::print(&string::utf8(b"Stealing the rabbit"));
                    let _random_wolf_index = random::rand_u64_range_no_sender(0, vector::length(&wolf_players));
                    let wolf_staker_address = vector::borrow(&wolf_players, _random_wolf_index);
                    debug::print(&string::utf8(b"Wolf staker address is: "));
                    debug::print(wolf_staker_address);
                    receiver = *wolf_staker_address;
                };
                let rabbit_token: Object<Character> = object::address_to_object<Character>(rabbit_token_address());
                mint_internal(creator, rabbit_token, receiver);
            } else {
                let baby_wolfie_token: Object<Character> = object::address_to_object<Character>(baby_wolfie_token_address());
                mint_internal(creator, baby_wolfie_token, receiver);
            };

            i = i + 1
        };
    }


    fun mint_internal(sender: &signer, token: Object<Character>, receiver: address) acquires Character, Events {
        let token_address = object::object_address(&token);
        let character_token = borrow_global<Character>(token_address);
        
        //Total token supply 
        let token_current_supply = option::destroy_some<u128>(fungible_asset::supply(token));

        if(token_current_supply < config::gen0_max()) {
            debug::print(&string::utf8(b"token supply less than gen0_max"));
            debug::print(&token_current_supply);
            assert!(token_current_supply + 1u128 <= config::gen0_max(), EALL_MINTED);
            let price = 1;
            debug::print(&price);
            assert!(coin::balance<AptosCoin>(receiver) >= config::gen0_mint_price(), EINSUFFICIENT_APT_BALANCE);
            coin::transfer<AptosCoin>(sender, @owner, config::gen0_mint_price());
        }
        else {
            debug::print(&string::utf8(b"Supply greater than 10k"));
            let price = mint_cost(token_current_supply);
            debug::print(&string::utf8(b"Price"));
            debug::print(&price);
            
            let asset = FURToken::get_metadata();
            let decimals = fungible_asset::decimals(asset);
            let decimal_offset = pow(10u64, (decimals as u64)); 

            debug::print(&string::utf8(b"decimals"));
            debug::print(&decimals);
            debug::print(&string::utf8(b"decimal offset"));
            debug::print(&decimal_offset);
            let amount_with_decimals = price*decimal_offset;

            primary_fungible_store::transfer(sender, asset, @owner, amount_with_decimals); 
        };

        let fa = fungible_asset::mint(&character_token.fungible_asset_mint_ref, 1);
        if (token_address == rabbit_token_address() ){
            debug::print(&string::utf8(b"Rabbit minted !!"));
        }
        else if (token_address == baby_wolfie_token_address()) {
            debug::print(&string::utf8(b"Baby wolfie minted !!"));
        };
        primary_fungible_store::deposit(receiver, fa);
        event::emit_event<AssetMintingEvent>(
            &mut borrow_global_mut<Events>(@owner).asset_minting_events, 
            AssetMintingEvent {
                receiver,
                asset_minted: token_address, 
            },
        );
        
    }

    // TODO: Before mainnet deployment
    #[view]
    public fun mint_cost(current_supply: u128): u64 {
        if (current_supply < config::gen0_max()) {
            return 0u64
        } else if (current_supply <= config::gen1_max()) {
            return 2u64
        } else if (current_supply <= config::gen2_max()) {
            return 4u64
        };
        8u64
    }

    #[view]
    public fun get_metadata(token_name: String): Object<Character> {
        let asset_address: address = token::create_token_address(&@owner, &config::collection_name(), &token_name);
        let token = object::address_to_object<Character>(asset_address);
        return token
    }

    #[view]
    // Convert shares(rabbit amount) to equivalent furtoken
    public  fun get_exchange_rate(): (u64, u64) acquires TaxPool {
        let tax_pool = borrow_global_mut<TaxPool>(object::create_object_address(&@owner, b"staking_module"));
        let numerator = tax_pool.total_asset;
        let denominator = tax_pool.total_shares;
        if(denominator == 0) {
            denominator = 1;
            numerator = 0;
        };

        return (numerator, denominator)
    }

    fun update_exchange_rate(amount: u64, fur_amount: u64, increase: bool) acquires TaxPool {
        let tax_pool = borrow_global_mut<TaxPool>(object::create_object_address(&@owner, b"staking_module"));
        if(increase) {
            tax_pool.total_asset = tax_pool.total_asset + fur_amount;
            tax_pool.total_shares = tax_pool.total_shares + amount;
        }
        else if(!increase) {
            tax_pool.total_asset = tax_pool.total_asset - fur_amount;
            tax_pool.total_shares = tax_pool.total_shares - amount;
        }
    }


    /// Adds stake to a pool
    // When a wolf is staked they have to provide fur as well according to the current 
    // exchange rate of the tax pool, to ensure every staker ges the fair amount of earnings
    public entry fun stake(
        staker: &signer,
        asset_metadata_object: Object<Character>,
        amount: u64
    ) acquires StakePoolRegistry, RabbitPool, WolfPool, TaxPool, WolfStakerRegistry, Events {
        let asset_metadata_address = object::object_address(&asset_metadata_object);
        let staker_addr = signer::address_of(staker);
        
        // Ensure you can actually stake this amount
        assert!(
            primary_fungible_store::balance(staker_addr, asset_metadata_object) >= amount,
            E_NOT_ENOUGH_FUNDS_TO_STAKE
        );


        // Ensure stake pool registry exists
        if (!exists<StakePoolRegistry>(staker_addr)) {
            debug::print(&string::utf8(b"No stake registry found, creating!!"));
            create_stake_registry(staker);
        };

        // Use the existing pool if it exists or create a new one
        let pool_address =  create_or_retrieve_stake_pool_address(staker, asset_metadata_object);
        debug::print(&string::utf8(b"Pool address: "));
        debug::print(&pool_address);
    
    
        let tax_pool_address = object::create_object_address(&@owner, b"staking_module");

        if(get_metadata(config::rabbit_token_name()) == asset_metadata_object) {
            update_earnings(&pool_address);  
            let rabbit_pool = borrow_global_mut<RabbitPool>(pool_address);
            let rabbit_pool_signer = object::generate_signer_for_extending(&rabbit_pool.extend_ref);
            let rabbit_pool = borrow_global_mut<RabbitPool>(signer::address_of(&rabbit_pool_signer));
            rabbit_pool.rabbit_staked_amount = rabbit_pool.rabbit_staked_amount+amount;
            // debug::print(&string::utf8(b"Rabbit amount after staking: "));
            // debug::print(&pool.rabbit_staked_amount);

            // Now that we have the pool address, add stake
            primary_fungible_store::transfer(staker, asset_metadata_object, pool_address, amount);

            let staker_nft_balance_after_staking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
            debug::print(&string::utf8(b"Staker Rabbit NFT balance after staking: "));
            debug::print(&staker_nft_balance_after_staking);
        }
        else if (get_metadata(config::baby_wolfie_token_name()) == asset_metadata_object) {    
            let wolf_pool = borrow_global_mut<WolfPool>(pool_address);        
            let wolf_pool_signer = object::generate_signer_for_extending(&wolf_pool.extend_ref);
            let wolf_pool = borrow_global_mut<WolfPool>(signer::address_of(&wolf_pool_signer));
            wolf_pool.baby_wolf_staked_amount = wolf_pool.baby_wolf_staked_amount+amount;
            // debug::print(&string::utf8(b"Baby Wolfie amount after staking: "));
            // debug::print(&pool.baby_wolf_staked_amount);
            
            // Now that we have the pool address, add stake
            let (num, deno) = get_exchange_rate();
            let fur_amount = amount*num/deno;

            if(fur_amount > 0) {
                primary_fungible_store::transfer(staker, FURToken::get_metadata(), tax_pool_address, fur_amount);
            };
            primary_fungible_store::transfer(staker, asset_metadata_object, pool_address, amount);
            update_exchange_rate(amount, fur_amount, true);

            let staker_nft_balance_after_staking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
            debug::print(&string::utf8(b"Staker Wolf NFT balance after staking: "));
            debug::print(&staker_nft_balance_after_staking);

            push_staker(staker_addr);
        };
        event::emit_event<StakingEvent>(
            &mut borrow_global_mut<Events>(@owner).staking_events, 
            StakingEvent {
                staker: staker_addr,
                asset_staked: asset_metadata_address,
                amount
            }
        );
    }

    // Address in vector is stored at x-1 if map gives x for the same address
    fun push_staker(staker: address) acquires WolfStakerRegistry {
        let wolf_staker_registry_address = object::create_object_address(&@owner, b"staking_module");
        let wolf_staker_registry = borrow_global_mut<WolfStakerRegistry>(wolf_staker_registry_address);
        if(!smart_table::contains(&wolf_staker_registry.wolf_staker_indices, staker)) {
            vector::push_back(&mut wolf_staker_registry.wolf_staker_addresses, staker); 
            smart_table::add(&mut wolf_staker_registry.wolf_staker_indices, staker, vector::length(&wolf_staker_registry.wolf_staker_addresses));
        };
    }

    fun pop_staker(staker: address) acquires WolfStakerRegistry, RabbitPool, WolfPool, StakePoolRegistry {
        let wolf_staker_registry_address = object::create_object_address(&@owner, b"staking_module");
        let wolf_staker_registry = borrow_global_mut<WolfStakerRegistry>(wolf_staker_registry_address);
        let balance = get_staking_balance(staker, config::baby_wolfie_token_name());
        if(balance == 0) {
            if(smart_table::contains(&wolf_staker_registry.wolf_staker_indices, staker)) {
                let index = smart_table::borrow(&wolf_staker_registry.wolf_staker_indices, staker);
                let i = *index;
                vector::swap_remove(&mut wolf_staker_registry.wolf_staker_addresses, i-1);  
                   
                let vector_len = vector::length(&wolf_staker_registry.wolf_staker_addresses);
                smart_table::remove(&mut wolf_staker_registry.wolf_staker_indices, staker);
                if(vector_len > 0) {
                    let last_staker = vector::borrow(&wolf_staker_registry.wolf_staker_addresses, i-1u64);
                    smart_table::upsert(&mut wolf_staker_registry.wolf_staker_indices, *last_staker, i);
                }
            }
        };
    }

    #[view]
    public fun get_staking_balance(staker: address, asset_name: String): u64 acquires RabbitPool, WolfPool, StakePoolRegistry{
        let asset_metadata_object = get_metadata(asset_name);
        let asset_metadata_address = object::object_address(&asset_metadata_object);
        let pool_address = retrieve_stake_pool_address(staker, asset_metadata_address);
    
        let staking_balance = 0;
        if(config::baby_wolfie_token_name() == asset_name) {
            let wolfie_pool_amt = borrow_global_mut<WolfPool>(pool_address).baby_wolf_staked_amount;
            debug::print(&string::utf8(b"Wolfie Staking amount: "));
            debug::print(&wolfie_pool_amt);
            staking_balance = wolfie_pool_amt;
        }
        else if(config::rabbit_token_name() == asset_name) {
            let rabbit_pool_amt = borrow_global_mut<RabbitPool>(pool_address).rabbit_staked_amount;
            debug::print(&string::utf8(b"Rabbit Staking amount: "));
            debug::print(&rabbit_pool_amt);
            staking_balance = rabbit_pool_amt; 
        };
        staking_balance
    }

    #[view]
    public fun get_wolf_players(): vector<address> acquires WolfStakerRegistry {
        let wolf_staker_registry_address = object::create_object_address(&@owner, b"staking_module");
        let wolf_staker_registry = borrow_global<WolfStakerRegistry>(wolf_staker_registry_address);
        wolf_staker_registry.wolf_staker_addresses
    }

    // Update earnings of furtoken for rabbit staked
    fun update_earnings(pool_address: &address) acquires RabbitPool {
        let pool = borrow_global_mut<RabbitPool>(*pool_address);
        let pool_signer = object::generate_signer_for_extending(&pool.extend_ref);
        let pool = borrow_global_mut<RabbitPool>(signer::address_of(&pool_signer));

        let time_elapsed = timestamp::now_seconds() - pool.last_update;
        // let rabbit_earnings = (pool.rabbit_staked_amount * config::daily_earning_rate() * time_elapsed) / 86400u64;
        let rabbit_earnings = (pool.rabbit_staked_amount * config::daily_earning_rate() * time_elapsed);
    
        pool.unclaimed_rabbit_earnings = pool.unclaimed_rabbit_earnings + rabbit_earnings;
        debug::print(&string::utf8(b"Unclaimed Rabbit Earning"));
        debug::print(&pool.unclaimed_rabbit_earnings);
        pool.last_update = timestamp::now_seconds();
    }

    #[view]
    public fun claimable_fur(staker_addr: address): u64 acquires RabbitPool, StakePoolRegistry {
        let asset_metadata_object = get_metadata(config::rabbit_token_name());
        let asset_metadata_address = object::object_address(&asset_metadata_object);
        let pool_address = retrieve_stake_pool_address(staker_addr, asset_metadata_address);
        let pool = borrow_global_mut<RabbitPool>(pool_address);

        let time_elapsed = timestamp::now_seconds() - pool.last_update;
        let rabbit_earnings = (pool.rabbit_staked_amount * config::daily_earning_rate() * time_elapsed);
        pool.unclaimed_rabbit_earnings + rabbit_earnings
    }

    public entry fun claim_rabbit_fur_earnings(pool_address: address, staker_addr: address, all_stolen: bool) acquires RabbitPool, TaxPool {
        debug::print(&string::utf8(b"inside rabbit claim fun"));
        update_earnings(&pool_address);
        let pool = borrow_global_mut<RabbitPool>(pool_address);
        let tax_pool_addr = object::create_object_address(&@owner, b"staking_module");
        debug::print(&string::utf8(b"Unclaimed Rabbit Earning to be claimed"));
        debug::print(&pool.unclaimed_rabbit_earnings);
        let tax_share = pool.unclaimed_rabbit_earnings * config::rabbit_tax_rate() / 100u64;
        debug::print(&string::utf8(b"Tax Share"));
        debug::print(&tax_share);
        if(all_stolen == true) {
            tax_share = pool.unclaimed_rabbit_earnings;
        };
        if(pool.unclaimed_rabbit_earnings > 0 && !all_stolen) {
            FURToken::mint(staker_addr, pool.unclaimed_rabbit_earnings - tax_share);
        }; 
        if(tax_share>0) {
            FURToken::mint(tax_pool_addr, tax_share);
        }; 
        pool.unclaimed_rabbit_earnings = 0;
        pool.last_update = timestamp::now_seconds();
        update_exchange_rate(0, tax_share, true);
    }

    fun disburse_wolf_tax_earnings(staker: address, amount: u64) acquires TaxPool, Events {
        let tax_pool = borrow_global_mut<TaxPool>(object::create_object_address(&@owner, b"staking_module")); 
        let tax_pool_signer = object::generate_signer_for_extending(&tax_pool.extend_ref);  
        let (assets, shares) = get_exchange_rate();
        let staker_earning = (assets*amount)/shares;
        if(staker_earning > 0) {
            primary_fungible_store::transfer(&tax_pool_signer, FURToken::get_metadata(), staker, staker_earning);
        };
        update_exchange_rate(amount, staker_earning, false);
        event::emit_event<WolfEarningEvent>(
            &mut borrow_global_mut<Events>(@owner).wolf_earning_event, 
            WolfEarningEvent {
                staker,
                staker_earning, 
            }
        );
    }

    /// Removes stake from the pool
    public entry fun unstake(
        staker: &signer,
        asset_metadata_object: Object<Character>,
        amount: u64
    ) acquires StakePoolRegistry, RabbitPool, WolfPool, WolfStakerRegistry, TaxPool, Events {
        let asset_metadata_address = object::object_address(&asset_metadata_object);
        let pool_address = retrieve_stake_pool_address(signer::address_of(staker), asset_metadata_address);
        let staker_addr = signer::address_of(staker);  

        // Check that we have enough to remove
        assert!(
            primary_fungible_store::balance(pool_address, asset_metadata_object) >= amount,
            E_NOT_ENOUGH_FUNDS_TO_UNSTAKE
        );

        if(get_metadata(config::rabbit_token_name()) == asset_metadata_object) {
            let rabbit_pool = borrow_global_mut<RabbitPool>(pool_address);
            let rabbit_pool_signer = object::generate_signer_for_extending(&rabbit_pool.extend_ref);
            rabbit_pool.rabbit_staked_amount = rabbit_pool.rabbit_staked_amount-amount;
            // debug::print(&string::utf8(b"Rabbit amount in the pool after unstaking: "));
            // debug::print(&pool.rabbit_staked_amount);

            // Now that we have the pool address, remove stake
            primary_fungible_store::transfer(&rabbit_pool_signer, asset_metadata_object, staker_addr, amount);

            let staker_nft_balance_after_unstaking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
            debug::print(&string::utf8(b"Staker Rabbit NFT balance after unstaking: "));
            debug::print(&staker_nft_balance_after_unstaking);
            
            let random_number = random::rand_u64_range_no_sender(0, 2);
            debug::print(&string::utf8(b"Random number: "));
            debug::print(&random_number);
            if(random_number == 0) {
                claim_rabbit_fur_earnings(pool_address, staker_addr, true);
            }
            else {
                claim_rabbit_fur_earnings(pool_address, staker_addr, false);
            }
            // Transfer the owner with its fur earnings
        }
        else if (get_metadata(config::baby_wolfie_token_name()) == asset_metadata_object) {
            let wolf_pool = borrow_global_mut<WolfPool>(pool_address);
            let wolf_pool_signer = object::generate_signer_for_extending(&wolf_pool.extend_ref);
            wolf_pool.baby_wolf_staked_amount = wolf_pool.baby_wolf_staked_amount - amount;
            // debug::print(&string::utf8(b"Baby Wolfie amount in the pool after unstaking: "));
            // debug::print(&pool.baby_wolf_staked_amount);

            // Now that we have the pool address, remove stake
            primary_fungible_store::transfer(&wolf_pool_signer, asset_metadata_object, staker_addr, amount);
            let staker_nft_balance_after_unstaking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
            debug::print(&string::utf8(b"Staker Wolf NFT balance after unstaking: "));
            debug::print(&staker_nft_balance_after_unstaking);

            pop_staker(staker_addr);

            // Transfer the user with its tax earnings
            disburse_wolf_tax_earnings(staker_addr, amount)
        };
        event::emit_event<UnstakingEvent>(
            &mut borrow_global_mut<Events>(@owner).unstaking_events, 
            UnstakingEvent {
                staker: staker_addr,
                asset_unstaked: asset_metadata_address,
                amount
            }
        );
    }

    fun create_stake_registry(staker: &signer) {
        let stake_pool_registry = StakePoolRegistry {
            fungible_asset_to_stake_pool: smart_table::new()
        };
        move_to<StakePoolRegistry>(staker, stake_pool_registry);
    }
    
    #[view]
    public fun retrieve_stake_pool_address(
        staker: address,
        asset_metadata_address: address
    ): address acquires StakePoolRegistry {

        // Ensure stake pool registry exists
        assert!(exists<StakePoolRegistry>(staker), E_NO_STAKE_REGISTRY);
        let stake_info = borrow_global<StakePoolRegistry>(staker);

        assert!(smart_table::contains(
            &stake_info.fungible_asset_to_stake_pool,
            asset_metadata_address
        ), E_NO_POOL_AT_ADDRESS);

        *smart_table::borrow(&stake_info.fungible_asset_to_stake_pool, asset_metadata_address)
    }

    fun create_or_retrieve_stake_pool_address(
        staker: &signer,
        asset_metadata_object: Object<Character>,
    ): address acquires StakePoolRegistry {
        let staker_addr = signer::address_of(staker);
        let stake_info = borrow_global_mut<StakePoolRegistry>(staker_addr);
        let asset_metadata_address = object::object_address(&asset_metadata_object);


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
        

            if(get_metadata(config::rabbit_token_name()) == asset_metadata_object) {

                let rabbit_pool = RabbitPool {
                    extend_ref,
                    delete_ref,
                    rabbit_staked_amount: 0u64,
                    unclaimed_rabbit_earnings: 0u64,
                    last_update: timestamp::now_seconds(),
                };
                move_to<RabbitPool>(&pool_signer, rabbit_pool);
            }
            else if(get_metadata(config::baby_wolfie_token_name()) == asset_metadata_object) {
                let wolf_pool = WolfPool {
                    extend_ref,
                    delete_ref,
                    baby_wolf_staked_amount: 0u64,
                };
                move_to<WolfPool>(&pool_signer, wolf_pool);
            };
            smart_table::add(
                &mut stake_info.fungible_asset_to_stake_pool,
                asset_metadata_address,
                pool_address
            );
            pool_address
        }
    }


    #[test_only]
    public fun initialize(sender: &signer) {
        init_module(sender);
    }
}
