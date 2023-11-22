module owner::FURToken {

    use std::option;
    use std::string::{Self};
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    friend owner::new_stake;
    friend owner::NFTCollection;
    #[test_only]
    friend owner::Test;

    #[test_only]
    use aptos_framework::account;


    struct FurToken has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    const ASSET_NAME: vector<u8> = b"FUR Token";
    const ASSET_SYMBOL: vector<u8> = b"FUR";

    fun init_module(
        account: &signer
    ) {
        let constructor_ref = &object::create_named_object(account, b"FUR");  
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(ASSET_NAME),
            string::utf8(ASSET_SYMBOL),
            8,
            string::utf8(b"http://example.com/favicon.ico"),
            string::utf8(b"http://example.com"),
        );

        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);
        // let metadata = object::address_to_object<Metadata>(object::address_from_constructor_ref(constructor_ref));
        
        move_to(&metadata_object_signer, FurToken {
            mint_ref, 
            transfer_ref, 
            burn_ref
        })
        // (metadata_object_signer, mint_ref, transfer_ref, burn_ref, metadata)
    }

    #[view]
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@owner, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }


    public entry fun mint(to: address, amount: u64) acquires FurToken {
        let metadata = get_metadata();
        let refs = borrow_global<FurToken>(object::object_address(&metadata));
        let primary_store = primary_fungible_store::ensure_primary_store_exists(to, fungible_asset::mint_ref_metadata(&refs.mint_ref));
        fungible_asset::mint_to(&refs.mint_ref, primary_store, amount);
    }

    public entry fun burn(to: address, amount: u64) acquires FurToken{
        let metadata = get_metadata();
        let refs = borrow_global<FurToken>(object::object_address(&metadata));
        let primary_store = primary_fungible_store::primary_store(to, fungible_asset::burn_ref_metadata(&refs.burn_ref));
        fungible_asset::burn_from(&refs.burn_ref, primary_store, amount);
    }


    fun transfer(  // can not be called externally
        from: address,      // Why not signer here ??
        to: address,
        amount: u64
    ) acquires FurToken {
        let metadata = get_metadata();
        let refs = borrow_global<FurToken>(object::object_address(&metadata));

        let from_primary_store = primary_fungible_store::primary_store(
            from, 
            fungible_asset::transfer_ref_metadata(&refs.transfer_ref)
        );

        let to_primary_store = primary_fungible_store::ensure_primary_store_exists(
            to, 
            fungible_asset::transfer_ref_metadata(&refs.transfer_ref)
        );
        
        fungible_asset::transfer_with_ref(
            &refs.transfer_ref, 
            from_primary_store, 
            to_primary_store, 
            amount
        );
    }

    
    #[test_only]
    use std::signer;
    // use std::debug;

    #[test(creator=@owner)]
    fun e2e_ok(creator: &signer) acquires FurToken{
        // let issuer = account::create_account_for_test(creator);
        let alice = account::create_account_for_test(@0xA);
        let bob = account::create_account_for_test(@0xB);

        init_module(creator);
        let metadata = get_metadata();
        // debug::print(&metadata);
        mint(signer::address_of(&alice), 100);
        transfer(
            signer::address_of(&alice),
            signer::address_of(&bob),
            10
        );
        burn(
            signer::address_of(&alice),
            10
        );

        primary_fungible_store::transfer(
            &alice,
            metadata,
            signer::address_of(&bob),
            20
        );
       
        // let fa = fungible_asset::mint(&furToken.mint_ref, 10000);
        // primary_fungible_store::deposit(signer::address_of(&alice), fa);
        // assert!(primary_fungible_store::balance(signer::address_of(&alice), metadata) == 10000, 0);

        // primary_fungible_store::transfer(&alice, metadata, signer::address_of(&bob), 10000);
        // assert!(primary_fungible_store::balance(signer::address_of(&bob), metadata) == 10000, 0);

        // let fa = primary_fungible_store::withdraw(&bob, metadata, 10000);
        // assert!(fungible_asset::amount(&fa) == 10000, 0);

        // fungible_asset::burn(&furToken.burn_ref, fa);
    }

    #[test_only]
    public fun initialize(sender: &signer) {
        init_module(sender);
    }
}