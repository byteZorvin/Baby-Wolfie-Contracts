module owner::NFTCollection {
    use aptos_framework::fungible_asset;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::debug;
    use std::signer;
    
    use owner::random;

    const ENOT_CREATOR: u64 = 0;
    const CHARACTER_COLLECTION_NAME: vector<u8> = b"CHARACTER Collection Name";
    /// The CHARACTER collection description
    const CHARACTER_COLLECTION_DESCRIPTION: vector<u8> = b"CHARACTER Collection Description";
    /// The CHARACTER collection URI
    const CHARACTER_COLLECTION_URI: vector<u8> = b"https://CHARACTER.collection.uri";
    const RABBIT_TOKEN_NAME: vector<u8> = b"Rabbit Token";
    const BABY_WOLFIE_TOKEN_NAME: vector<u8> = b"Baby Wolfie Token";


    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Represents the common fields for a collection.
    struct Collection has key {
        /// The creator of this collection.
        // creator: address,
        // /// A brief description of the collection.
        // description: String,
        // /// An optional categorization of similar token.
        // name: String,
        // /// The Uniform Resource Identifier (uri) pointing to the JSON file stored in off-chain
        // /// storage; the URL length will likely need a maximum any suggestions?
        // uri: String,

        mutator_ref: collection::MutatorRef,
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

    fun init_module(sender: &signer) {
        create_character_collection(sender);
        create_chracter_token_as_fungible_token(
            sender,
            string::utf8(b"Rabbit Token Description"),
            string::utf8(RABBIT_TOKEN_NAME),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            option::some(13500u128),
            string::utf8(b"Rabbit"),
            string::utf8(b"RB"),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            string::utf8(b"https://www.aptoslabs.com"),
        );
        create_chracter_token_as_fungible_token(
            sender,
            string::utf8(b"Baby Wolfie Token Description"),
            string::utf8(BABY_WOLFIE_TOKEN_NAME),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            option::some(1500u128),
            string::utf8(b"Baby Wolfie"),
            string::utf8(b"BWOLF"),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            string::utf8(b"https://www.aptoslabs.com"),
        )
    }

    fun create_character_collection(creator: &signer) {
        // Constructs the strings from the bytes.
        let description = string::utf8(CHARACTER_COLLECTION_DESCRIPTION);
        let name = string::utf8(CHARACTER_COLLECTION_NAME);
        let uri = string::utf8(CHARACTER_COLLECTION_URI);
        let maxSupply = 15000;

        // Creates the collection with fixed supply
        let constructor_ref = collection::create_fixed_collection(
            creator,
            description,
            maxSupply,
            name,
            option::none(),
            uri,
        );

        let object_signer = object::generate_signer(&constructor_ref);
        let collection = Collection {
            mutator_ref : collection::generate_mutator_ref(&constructor_ref)
        };

        move_to(&object_signer, collection)
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
        let collection = string::utf8(CHARACTER_COLLECTION_NAME);

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
        token::create_token_address(&@owner, &string::utf8(CHARACTER_COLLECTION_NAME), &string::utf8(RABBIT_TOKEN_NAME))
    }

    #[view]
    public fun baby_wolfie_token_address(): address {
        token::create_token_address(&@owner, &string::utf8(CHARACTER_COLLECTION_NAME), &string::utf8(BABY_WOLFIE_TOKEN_NAME))
    }

    // #[view]
    // /// Returns the balance of the food token of the owner
    // public fun token_balance(creator: address, token: Object<Character>): u64 {
    //     let metadata = object::convert<Character, Metadata>(food);
    //     let store = primary_fungible_store::ensure_primary_store_exists(creator, metadata);
    //     fungible_asset::balance(store)
    // }
    
    const RABBIT_PROBABILITY: u64 = 90;
    public entry fun mint(creator: &signer, receiver: address, amount: u64) acquires Character {
        let random_number = random::rand_u64_range_no_sender(0, 100);
        let is_sheep = random_number <= RABBIT_PROBABILITY;
        debug::print(&random_number);
        if(is_sheep) {
            let rabbit_token = object::address_to_object<Character>(rabbit_token_address());
            mint_internal(creator, rabbit_token, receiver, amount);
        } else {
            let baby_wolfie_token = object::address_to_object<Character>(baby_wolfie_token_address());
            mint_internal(creator, baby_wolfie_token, receiver, amount);
        };
    }

    fun mint_internal(_creator: &signer, token: Object<Character>, receiver: address, amount: u64) acquires Character {
        
        let token_address = object::object_address(&token);
        let character_token = borrow_global<Character>(token_address);
        let fa = fungible_asset::mint(&character_token.fungible_asset_mint_ref, amount);
        primary_fungible_store::deposit(receiver, fa);

        // let collection_addr = collection::create_collection_address(&signer::address_of(creator), &string::utf8(CHARACTER_COLLECTION_NAME));
        // // let supply = borrow_global<collection:: FixedSupply>(collection_addr).current_supply;
        // debug::print(&string::utf8(b"Current supply is: "));
        // debug::print(&supply);
        
        
        // let collection = object::address_to_object<>(collection_addr);
        // let count = collection::count(collection);
        // debug::print(&string::utf8(b"Count:"));
        // debug::print(&count);
        let supply = fungible_asset::supply(token);
        debug::print(&supply);
    }


    #[test_only]
    use aptos_framework::block;

    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    use aptos_framework::account;

    #[test(creator=@owner)]
    public fun init_module_for_test(creator: &signer) {
        init_module(creator);
    }
     
    #[test(creator=@owner, framework=@0x1, user1=@0xcafe, user2=@0x89)] 
    fun test_mint(creator: &signer, framework: &signer, user1: &signer, user2: &signer) acquires Character {
        
        let framework_addr = signer::address_of(framework);
        let framework_acc = &account::create_account_for_test(framework_addr);

        block::initialize_for_test(framework_acc, 10000);
        timestamp::set_time_has_started_for_testing(framework);
        debug::print(&string::utf8(b"time initially: "));
        debug::print(&timestamp::now_seconds());

        init_module(creator);
        mint(user1, signer::address_of(user2), 1u64);

        timestamp::update_global_time_for_test_secs(100);
        debug::print(&string::utf8(b"time afterwards: "));
        debug::print(&timestamp::now_seconds());
    }

}