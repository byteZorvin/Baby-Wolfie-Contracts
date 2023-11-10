module owner::NFTCollection {
    use aptos_framework::fungible_asset;
    use aptos_framework::object;
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use std::option::{Self, Option};
    use std::string::{Self, String};

    const CHARACTER_COLLECTION_NAME: vector<u8> = b"CHARACTER Collection Name";
    /// The CHARACTER collection description
    const CHARACTER_COLLECTION_DESCRIPTION: vector<u8> = b"CHARACTER Collection Description";
    /// The CHARACTER collection URI
    const CHARACTER_COLLECTION_URI: vector<u8> = b"https://CHARACTER.collection.uri";
    const RABBIT_TOKEN_NAME: vector<u8> = b"Rabbit Token";
    const BABY_WOLFIE_TOKEN_NAME: vector<u8> = b"Baby Wolfie Token";

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
            string::utf8(b"RABBIT"),
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
            string::utf8(b"BABY WOLFIE"),
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

}