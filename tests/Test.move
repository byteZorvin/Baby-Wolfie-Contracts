#[test_only]
module owner::Test {
    use aptos_framework::primary_fungible_store;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    // use aptos_std::table::{Self, Table};
    use owner::config;
    use owner::FURToken;
    use owner::NFTCollection;
    // use owner::old_stake;
    use owner::new_stake;

    #[test_only]
    use aptos_framework::block;

    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    use aptos_framework::account;

    #[test_only]
    use std::string::{Self};

    #[test_only]
    use std::debug;

    #[test_only]
    use std::signer;

    #[test_only]
    use std::error;

    
    public fun init_module_for_test(creator: &signer) {
        NFTCollection::initialize(creator);
    }

    public fun init_module_for_test_fur(creator: &signer) {
        FURToken::initialize(creator);
    }

    public fun init_module_for_test_stake(creator: &signer) {
        new_stake::initialize(creator);
    }
    

    #[test(creator=@owner, framework=@0x1, user1=@0xcafe, user2=@0x789)] 
    fun test_mint(creator: &signer, framework: &signer, user1: &signer, user2: &signer) {
        // 1. Setup accounts
        let framework_addr = signer::address_of(framework);
        let framework_acc = &account::create_account_for_test(framework_addr);

        let creator_addr = signer::address_of(creator);
        let _creator_acc = &account::create_account_for_test(creator_addr);

        let user1_addr = signer::address_of(user1);
        account::create_account_for_test(user1_addr);

        let user2_addr = signer::address_of(user2);
        account::create_account_for_test(user2_addr);


        // 2. Initialise aptos parameters
        block::initialize_for_test(framework_acc, 10000);
        timestamp::set_time_has_started_for_testing(framework);
        debug::print(&string::utf8(b"time initially: "));
        debug::print(&timestamp::now_seconds());
        

        init_module_for_test(creator);


        // 3. ---------Set up for AptosCoin(APT) transfer---------

        // 3.1 Register accounts for AptosCoin
        coin::register<AptosCoin>(user1);
        coin::register<AptosCoin>(user2);
        coin::register<AptosCoin>(creator);

        // 3.2 Mint APTs for user1 and user2
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosCoin>(
            framework,
            string::utf8(b"APT"),
            string::utf8(b"APT"),
            8,
            false,
        );
        let coins = coin::mint<AptosCoin>(1000, &mint_cap);
        coin::deposit(user1_addr, coins);
        coin::transfer<AptosCoin>(user1, user2_addr, 500);

        let balance = coin::balance<AptosCoin>(signer::address_of(user1));
        assert!(balance == 1000, error::invalid_state(1));

        debug::print(&string::utf8(b"Balance after AptosCoin Deposit"));
        debug::print(&balance);

        let owner_balance = coin::balance<AptosCoin>(signer::address_of(creator));
        debug::print(&string::utf8(b"Owner Balance before mint"));
        debug::print(&owner_balance);
        

        // 3.3 Destroy capabilities for AptosCoin
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_burn_cap(burn_cap);

        // 4.1 Mint Rabbit Token for user1
        NFTCollection::mint(user1, signer::address_of(user1), 1u64);
        // 4.2 Mint Rabbit Token for user2
        NFTCollection::mint(user2, signer::address_of(user2), 1u64);


        let owner_balance = coin::balance<AptosCoin>(signer::address_of(creator));
        debug::print(&string::utf8(b"Owner Balance after mint"));
        debug::print(&owner_balance);

        // -----------*--------------


        // 5. ---------------- Setup and Mint FurToken to users --------
        init_module_for_test_fur(creator);
        FURToken::mint(signer::address_of(user1), 100000_0000_0000);
        FURToken::mint(signer::address_of(user2), 100000_0000_0000);
        
        let owner_furToken_before = primary_fungible_store::balance(signer::address_of(creator), FURToken::get_metadata());
        debug::print(&string::utf8(b"Owner balance before FurToken mint"));
        debug::print(&owner_furToken_before);

        let balance_furToken_before = primary_fungible_store::balance(signer::address_of(user1), FURToken::get_metadata());
        let balance_character_before = primary_fungible_store::balance(signer::address_of(user1), NFTCollection::get_metadata(config::rabbit_token_name()));

        debug::print(&string::utf8(b"Furtoken Balance before character mint"));
        debug::print(&balance_furToken_before);
        debug::print(&string::utf8(b"Character Balance before character mint"));
        debug::print(&balance_character_before);

        // Minting 1 token in gen 1
        NFTCollection::mint(user1, signer::address_of(user1), 3u64);
        NFTCollection::mint(user2, signer::address_of(user2), 3u64);


        let owner_furToken_after = primary_fungible_store::balance(signer::address_of(creator), FURToken::get_metadata());
        debug::print(&string::utf8(b"Owner balance after FurToken mint"));
        debug::print(&owner_furToken_after);
        
        let balance_furToken_after = primary_fungible_store::balance(signer::address_of(user1), FURToken::get_metadata());
        let balance_character_after = primary_fungible_store::balance(signer::address_of(user1), NFTCollection::get_metadata(config::rabbit_token_name()));
        
        debug::print(&string::utf8(b"Furtoken Balance after character mint"));
        debug::print(&balance_furToken_after);
        debug::print(&string::utf8(b"Character Balance after character mint"));
        debug::print(&balance_character_after);
        // --------------------*------------------

        // timestamp::update_global_time_for_test_secs(100);
        // debug::print(&string::utf8(b"time before fastforward: "));
        // debug::print(&timestamp::now_seconds());

        // timestamp::fast_forward_seconds(100);
        // debug::print(&string::utf8(b"time after fastforward: "));
        // debug::print(&timestamp::now_seconds());

        // debug::print(&string::utf8(b"Mint after forwarding time"));
        // NFTCollection::mint(user2, signer::address_of(user2), 1u64);

        // --------------------*------------------

        // 6 --------------- Staking module ------------------

        init_module_for_test_stake(creator);

        
        debug::print(&string::utf8(b"User1 stakes"));
        new_stake::stake(user1, NFTCollection::get_metadata(config::rabbit_token_name()), 2);
        debug::print(&string::utf8(b"User2 stakes"));
        new_stake::stake(user2, NFTCollection::get_metadata(config::rabbit_token_name()), 2);
        debug::print(&string::utf8(b"User1 unstakes"));
        new_stake::unstake(user1, NFTCollection::get_metadata(config::rabbit_token_name()), 1);
        debug::print(&string::utf8(b"User2 unstakes"));
        new_stake::unstake(user2, NFTCollection::get_metadata(config::rabbit_token_name()), 1);
        new_stake::stake(user1, NFTCollection::get_metadata(config::rabbit_token_name()), 3);   

        // ----------------------------------------------
    }

}