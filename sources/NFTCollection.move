module owner::NFTCollection {
    use aptos_framework::fungible_asset;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use aptos_framework::aptos_coin::AptosCoin;
    use std::math64::{pow};
    use aptos_framework::coin;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::debug;
    // use std::signer;
    use owner::random;
    use owner::FURToken;
    use owner::config;

    //Error codes
    const ENOT_CREATOR: u64 = 0;
    const EALL_MINTED: u64 = 1;
    const EINSUFFICIENT_APT_BALANCE: u64 = 2;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Represents the common fields for a collection.
    struct Collection has key {
        /// The creator of this collection.
        // creator: {address},
        // A brief description of the collection.
        // description: String,
        //  An optional categorization of similar token.
        // name: String,
        // The Uniform Resource Identifier (uri) pointing to the JSON file stored in off-chain
        // storage; the URL length will likely need a maximum any suggestions?
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
            config::rabbit_token_name(),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            option::some(45000u128),
            string::utf8(b"Rabbit"),
            config::rabbit_symbol_name(),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            string::utf8(b"https://www.aptoslabs.com"),
        );
        create_chracter_token_as_fungible_token(
            sender,
            string::utf8(b"Baby Wolfie Token Description"),
            config::baby_wolfie_token_name(),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            option::some(5000u128),
            string::utf8(b"Baby Wolfie"),
            config::baby_wolfie_symbol_name(),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            string::utf8(b"https://www.aptoslabs.com"),
        ) 
    }

    fun create_character_collection(creator: &signer) {
        // Constructs the strings from the bytes.
        let description = config::collection_description();
        let name = config::collection_name();
        let uri = config::collection_uri();
        let maxSupply = 2;    // No of different tokens

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
    
    
    public entry fun mint(creator: &signer, receiver: address, amount: u64) acquires Character {
        let i = 1;
        while (i <= amount) {
            
            let random_number = random::rand_u64_range_no_sender(0, 101);
            let is_sheep = random_number <= config::rabbit_probability();
            debug::print(&string::utf8(b"Random number generated in NFTCollection::mint() is: "));
            debug::print(&random_number);
            if(is_sheep) {
                let rabbit_token: Object<Character> = object::address_to_object<Character>(rabbit_token_address());
                mint_internal(creator, rabbit_token, receiver);
            } else {
                let baby_wolfie_token: Object<Character> = object::address_to_object<Character>(baby_wolfie_token_address());
                mint_internal(creator, baby_wolfie_token, receiver);
            };

            i = i + 1
        };
    }


    fun mint_internal(sender: &signer, token: Object<Character>, receiver: address) acquires Character {
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
            debug::print(&string::utf8(b"Metadata"));
            debug::print(&asset);

            primary_fungible_store::transfer(sender, asset, @owner, amount_with_decimals); 
        };

        let fa = fungible_asset::mint(&character_token.fungible_asset_mint_ref, 1);
        primary_fungible_store::deposit(receiver, fa);
        
    }

    #[view]
    public fun mint_cost(current_supply: u128): u64 {
        if (current_supply < config::gen0_max()) {
            return 0u64
        } else if (current_supply <= config::gen1_max()) {
            return 20u64
        } else if (current_supply <= config::gen2_max()) {
            return 40u64
        };
        80u64
    }

    #[view]
    public fun get_metadata(token_name: String): Object<Character> {
        let asset_address: address = token::create_token_address(&@owner, &config::collection_name(), &token_name);
        let token = object::address_to_object<Character>(asset_address);
        return token
    }

    #[test_only]
    public fun initialize(sender: &signer) {
        init_module(sender);
    }

}