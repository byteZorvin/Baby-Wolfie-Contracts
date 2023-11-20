#[test_only]
module owner::Test {
    use aptos_framework::primary_fungible_store;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_std::table::{Self, Table};
    use owner::config;
    use owner::FURToken;
    use owner::NFTCollection;
    use owner::Stake;


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

    
    public fun init_module_for_test(creator: &signer) {
        NFTCollection::initialize(creator);
    }
    

    #[test(creator=@owner, framework=@0x1, user1=@0xcafe)] 
    fun test_mint(creator: &signer, framework: &signer, user1: &signer) {
        // Setup accounts
        let framework_addr = signer::address_of(framework);
        let framework_acc = &account::create_account_for_test(framework_addr);

        let creator_addr = signer::address_of(creator);
        let _creator_acc = &account::create_account_for_test(creator_addr);

        // Initialise aptos parameters
        block::initialize_for_test(framework_acc, 10000);
        timestamp::set_time_has_started_for_testing(framework);
        debug::print(&string::utf8(b"time initially: "));
        debug::print(&timestamp::now_seconds());

        init_module_for_test(creator);

        let account_addr = signer::address_of(user1);
        account::create_account_for_test(account_addr);


        //---------Set up for AptosCoin(APT) transfer---------
        coin::register<AptosCoin>(user1);
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosCoin>(
            framework,
            string::utf8(b"APT"),
            string::utf8(b"APT"),
            8,
            false,
        );
        let coins = coin::mint<AptosCoin>(1000000000, &mint_cap);
        coin::deposit(signer::address_of(user1), coins);
        let balance = coin::balance<AptosCoin>(signer::address_of(user1));
        debug::print(&string::utf8(b"Balance after AptosCoin Deposit"));
        debug::print(&balance);

        coin::register<AptosCoin>(creator);
        let owner_balance = coin::balance<AptosCoin>(signer::address_of(creator));
        debug::print(&string::utf8(b"Owner Balance before mint"));
        debug::print(&owner_balance);
        
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_burn_cap(burn_cap);
        NFTCollection::mint(user1, signer::address_of(user1), 1u64);

        let owner_balance = coin::balance<AptosCoin>(signer::address_of(creator));
        debug::print(&string::utf8(b"Owner Balance after mint"));
        debug::print(&owner_balance);

        // -----------*--------------


        // -------------Set up for FurToken transfer --------
        FURToken::initialize(creator);
        FURToken::mint(signer::address_of(user1), 900000_0000_0000);
        
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
        NFTCollection::mint(user1, signer::address_of(user1), 1u64);

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

        timestamp::update_global_time_for_test_secs(100);
        debug::print(&string::utf8(b"time afterwards: "));
        debug::print(&timestamp::now_seconds());

        // --------------------*------------------
        Stake::initialize(creator);
        Stake::stake_rabbit(user1, 1u64);
        Stake::unstake_rabbit(user1, 1u64);
    }
}