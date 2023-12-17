#[test_only]
module owner::Test {
    use aptos_framework::primary_fungible_store;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    // use aptos_std::table::{Self, Table};
    use aptos_framework::block;
    use std::string::{Self};
    use std::features;
    use std::math64::{pow};
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::fungible_asset;
    use std::signer;
    use std::debug;
    use std::option;
    // use std::object;
    use owner::config;
    use owner::FURToken;
    use owner::NFTCollection;
    // use owner::new_stake;
    
    public fun init_module_for_test_collection(creator: &signer) {
        NFTCollection::initialize(creator);
    }

    public fun init_module_for_test_fur(creator: &signer) {
        FURToken::initialize(creator);
    }

    // public fun init_module_for_test_stake(creator: &signer) {
    //     new_stake::initialize(creator);
    // }
    

    #[test(creator=@owner, framework=@0x1, user1=@0xcafe, user2=@0x789)] 
    fun test_mint(creator: &signer, framework: &signer, user1: &signer, user2: &signer) {
        // 1. Setup accounts

        debug::print(&string::utf8(b"Creating test accounts"));
        let framework_addr = signer::address_of(framework);
        let framework_acc = &account::create_account_for_test(framework_addr);

        let creator_addr = signer::address_of(creator);
        let _creator_acc = &account::create_account_for_test(creator_addr);

        let user1_addr = signer::address_of(user1);
        account::create_account_for_test(user1_addr);

        let user2_addr = signer::address_of(user2);
        account::create_account_for_test(user2_addr);

        debug::print(&string::utf8(b"Initialising blockchain\n"));
        // 2. Initialise aptos parameters
        block::initialize_for_test(framework_acc, 10000);
        timestamp::set_time_has_started_for_testing(framework);
        debug::print(&string::utf8(b"time initially: "));
        debug::print(&timestamp::now_seconds());
        features::change_feature_flags(framework, vector[features::get_module_event_feature()], vector[]);

        debug::print(&string::utf8(b"Initialising modules"));
        init_module_for_test_collection(creator);
        init_module_for_test_fur(creator);

        // 3. ---------Set up for AptosCoin(APT) transfer---------

        debug::print(&string::utf8(b"Registering Aptos coin for users"));
        // 3.1 Register accounts for AptosCoin
        coin::register<AptosCoin>(user1);
        coin::register<AptosCoin>(user2);
        coin::register<AptosCoin>(creator);

        // 3.2 Mint APTs for user1 and user2
        debug::print(&string::utf8(b"Minting APT to users!!"));
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosCoin>(
            framework,
            string::utf8(b"APT"),
            string::utf8(b"APT"),
            8,
            false,
        );
        let coins_minted = coin::mint<AptosCoin>(1000, &mint_cap);
        coin::deposit(user1_addr, coins_minted);
        coin::transfer<AptosCoin>(user1, user2_addr, 500);

        let balance_user1 = coin::balance<AptosCoin>(user1_addr);
        let balance_user2 = coin::balance<AptosCoin>(user2_addr);
        assert!(balance_user1 == 500, 1);
        assert!(balance_user2 == 500, 2);

        debug::print(&string::utf8(b"Successfully Minted APT to users!! "));

        let owner_before_balance = coin::balance<AptosCoin>(creator_addr);
        assert!(owner_before_balance == 0, 3);
        
        debug::print(&string::utf8(b"Destroying capabilities of APT coin \n"));
        // 3.3 Destroy capabilities for AptosCoin
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_burn_cap(burn_cap);

        let wolfie_metadata = NFTCollection::get_metadata(config::baby_wolfie_token_name());
        let token_current_supply_before_mint = option::destroy_some<u128>(fungible_asset::supply(wolfie_metadata));
        let mint_cost = config::gen0_mint_price();
        assert!(token_current_supply_before_mint == 0, 4);

        debug::print(&string::utf8(b"Minting Rabbit/Wolfie to users in gen0 "));

        // 4.1 Mint Rabbit Token for user1
        NFTCollection::mint(user1, user1_addr, 1u64);   //Wolf minted
        
        // Checking if user 1 had to pay the correct amount of apt
        let balance_user1_after_mint_gen0 = coin::balance<AptosCoin>(user1_addr);
        assert!(balance_user1_after_mint_gen0 == balance_user1 - mint_cost, 5);

        // Supply should increase by one
        let token_current_supply_after_one_mint = option::destroy_some<u128>(fungible_asset::supply(wolfie_metadata));
        assert!(token_current_supply_after_one_mint == token_current_supply_before_mint + 1, 6);

        // Minting cost should not change after this mint as its still gen 0
        let mint_cost_after_one_mint = config::gen0_mint_price();
        assert!(mint_cost == mint_cost_after_one_mint, 7);

        // 4.2 Mint Rabbit Token for user2
        NFTCollection::mint(user2, user2_addr, 1u64);    //Wolf minted

        // Checking if user 2 had to pay the correct amount of apt
        let balance_user2_after_mint_gen0 = coin::balance<AptosCoin>(user2_addr);
        assert!(balance_user2_after_mint_gen0 == balance_user2 - mint_cost_after_one_mint, 8);

        let owner_after_mint_balance = coin::balance<AptosCoin>(creator_addr);
        assert!(owner_after_mint_balance == owner_before_balance + mint_cost*2, 9);
        debug::print(&string::utf8(b"Successfully minted digital asset!!"));

        // -----------*--------------


        // 5. ---------------- Setup and Mint FurToken to users --------
        debug::print(&string::utf8(b"Minting fur to users"));
        let asset = FURToken::get_metadata();
        let furtoken_decimals = fungible_asset::decimals(asset);
        assert!(furtoken_decimals == 8, 10);

        let furtoken_decimal_offset = pow(10u64, (furtoken_decimals as u64)); 
        FURToken::mint(user1_addr, 100000*furtoken_decimal_offset);
        FURToken::mint(user2_addr, 100000*furtoken_decimal_offset);

        debug::print(&string::utf8(b"Successfully minted fur"));
        
        let owner_furToken_balance_before = primary_fungible_store::balance(creator_addr, FURToken::get_metadata());
        let user1_furToken_balance_before = primary_fungible_store::balance(user1_addr, FURToken::get_metadata());
        let user1_rabbit_character_balance_before = primary_fungible_store::balance(user1_addr, NFTCollection::get_metadata(config::rabbit_token_name()));
        let user1_wolf_character_balance_before = primary_fungible_store::balance(user1_addr, NFTCollection::get_metadata(config::baby_wolfie_token_name()));
        let token_current_supply_before_mint = option::destroy_some<u128>(fungible_asset::supply(wolfie_metadata));

        debug::print(&string::utf8(b"Minting Rabbit/Wolf to user1 and user2 in gen 1"));

        // Minting 1 token in gen 1
        let user1_mint_amt = 3u64;
        NFTCollection::mint(user1, user1_addr, user1_mint_amt);      //Wolf minted 

        debug::print(&string::utf8(b"Successfully Minted Rabbit/Wolf to user1 and user2 in gen 1"));
        
        let owner_furToken_balance_after = primary_fungible_store::balance(creator_addr, FURToken::get_metadata());
        let user1_furToken_balance_after = primary_fungible_store::balance(user1_addr, FURToken::get_metadata());
        let user1_rabbit_character_balance_after = primary_fungible_store::balance(user1_addr, NFTCollection::get_metadata(config::rabbit_token_name()));
        let user1_wolf_character_balance_after = primary_fungible_store::balance(user1_addr, NFTCollection::get_metadata(config::baby_wolfie_token_name()));
        let mint_cost = NFTCollection::mint_cost(token_current_supply_before_mint);

        assert!(owner_furToken_balance_after == owner_furToken_balance_before + user1_mint_amt*mint_cost*furtoken_decimal_offset, 11);
        assert!(user1_furToken_balance_after == user1_furToken_balance_before - user1_mint_amt*mint_cost*furtoken_decimal_offset, 12);
        assert!(user1_rabbit_character_balance_after == user1_rabbit_character_balance_before + 0, 13);
        assert!(user1_wolf_character_balance_after == user1_wolf_character_balance_before + user1_mint_amt, 14);
        
        let user2_mint_amt = 3u64;
        NFTCollection::mint(user2, signer::address_of(user2), user2_mint_amt);  //Wolf minted before forwarding time
        // --------------------*------------------

        // timestamp::update_global_time_for_test_secs(100);
        debug::print(&string::utf8(b"time before fastforward: "));
        debug::print(&timestamp::now_seconds());

        timestamp::fast_forward_seconds(100);
        debug::print(&string::utf8(b"time after fastforward: "));
        debug::print(&timestamp::now_seconds());

        debug::print(&string::utf8(b"Mint after forwarding time"));
        NFTCollection::mint(user2, signer::address_of(user2), 1u64);     //Rabbit minted after forwarding time for user 2
        NFTCollection::mint(user1, signer::address_of(user1), 1u64);     //Rabbit minted after forwarding time for user 1
        // --------------------*------------------

        // 6 --------------- Staking module ------------------

        // init_module_for_test_stake(creator);


        
        debug::print(&string::utf8(b"Rabbit stake"));
        debug::print(&string::utf8(b"User1 stakes"));
        NFTCollection::stake(user1, NFTCollection::get_metadata(config::rabbit_token_name()), 1);
        timestamp::fast_forward_seconds(43200);
        // new_stake::stake(user2, NFTCollection::get_metadata(config::rabbit_token_name()), 1);
        // new_stake::stake(user2, NFTCollection::get_metadata(config::baby_wolfie_token_name()), 1);
        debug::print(&string::utf8(b"User1 unstakes"));
        // debug::print(&string::utf8(b"User2 unstakes"));
        // timestamp::fast_forward_seconds(2*86400);
        NFTCollection::unstake(user1, NFTCollection::get_metadata(config::rabbit_token_name()), 1);

        // new_stake::unstake(user2, NFTCollection::get_metadata(config::rabbit_token_name()), 1);


        
        // let rabbit_metadata = NFTCollection::get_metadata(config::rabbit_token_name());
        // let wolf_metadata = NFTCollection::get_metadata(config::baby_wolfie_token_name());
        // let rabbit_address = object::object_address(&rabbit_metadata);
        // let wolf_address = object::object_address(&wolf_metadata);
        // let user1_rabbit_pool = new_stake::create_or_retrieve_stake_pool_address(user1 , rabbit_address);
        // let user1_wolf_pool = new_stake::create_or_retrieve_stake_pool_address(user1, wolf_address);

        // assert!(user1_rabbit_pool == user1_wolf_pool, 15);
        // new_stake::stake(user1, NFTCollection::get_metadata(config::rabbit_token_name()), 1);   


        debug::print(&string::utf8(b"Wolf stake"));
        debug::print(&string::utf8(b"User1 stakes"));
        NFTCollection::stake(user1, NFTCollection::get_metadata(config::baby_wolfie_token_name()), 1);
        
        timestamp::fast_forward_seconds(2*86400);

        debug::print(&string::utf8(b"Stealing by user1"));

        let user1_rabbit_before_steal = primary_fungible_store::balance(user1_addr, NFTCollection::get_metadata(config::rabbit_token_name()));
        debug::print(&string::utf8(b"User1 rabbit before steal: "));
        debug::print(&user1_rabbit_before_steal);

        NFTCollection::mint(user1, signer::address_of(user1), 1u64);

        let user1_rabbit_after_steal = primary_fungible_store::balance(user1_addr, NFTCollection::get_metadata(config::rabbit_token_name()));
        debug::print(&string::utf8(b"User1 rabbit after steal: "));
        debug::print(&user1_rabbit_after_steal);
        // debug::print(&string::utf8(b"User2 stakes"));
        // new_stake::stake(user2, NFTCollection::get_metadata(config::baby_wolfie_token_name()), 2);
        // debug::print(&string::utf8(b"User1 unstakes"));
        // new_stake::unstake(user1, NFTCollection::get_metadata(config::baby_wolfie_token_name()), 1);
        // debug::print(&string::utf8(b"User2 unstakes"));
        // new_stake::unstake(user2, NFTCollection::get_metadata(config::baby_wolfie_token_name()), 1);
        // new_stake::stake(user1, NFTCollection::get_metadata(config::baby_wolfie_token_name()), 3);   

        // ----------------------------------------------

        // let rabbit_address = object::object_address(&NFTCollection::get_metadata(config::rabbit_token_name()));
        // let rabbit_pool_address = new_stake::retrieve_stake_pool_address(user1, rabbit_address);
        // new_stake::claim_rabbit_fur_earnings(rabbit_pool_address, signer::address_of(user1), false);


        //Staked balance for user 1
        let _rabbit_staking_balance = NFTCollection::get_staking_balance(user1_addr, config::rabbit_token_name());
        let _wolf_staking_balance = NFTCollection::get_staking_balance(user1_addr, config::baby_wolfie_token_name());

        let wolf_players = NFTCollection::get_wolf_players();
        debug::print(&string::utf8(b"Wolf players after staking"));
        debug::print(&wolf_players);

        NFTCollection::unstake(user1, NFTCollection::get_metadata(config::baby_wolfie_token_name()), 1);

        let wolf_players = NFTCollection::get_wolf_players();
        debug::print(&string::utf8(b"Wolf players after unstaking"));
        debug::print(&wolf_players);

    }

}