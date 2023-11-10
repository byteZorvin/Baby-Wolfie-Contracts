module owner::NFTCollection {
    use aptos_framework::fungible_asset;
    use aptos_framework::object;
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use std::option;
    use std::string;

    const CHARACTER_COLLECTION_NAME: vector<u8> = b"CHARACTER Collection Name";
    /// The CHARACTER collection description
    const CHARACTER_COLLECTION_DESCRIPTION: vector<u8> = b"CHARACTER Collection Description";
    /// The CHARACTER collection URI
    const CHARACTER_COLLECTION_URI: vector<u8> = b"https://CHARACTER.collection.uri";

    fun init_module(sender: &signer) {
        create_character_collection(sender);
    }

    fun create_character_collection(creator: &signer) {
        // Constructs the strings from the bytes.
        let description = string::utf8(CHARACTER_COLLECTION_DESCRIPTION);
        let name = string::utf8(CHARACTER_COLLECTION_NAME);
        let uri = string::utf8(CHARACTER_COLLECTION_URI);
        let maxSupply = 15000;

        // Creates the collection with unlimited supply and without establishing any royalty configuration.
        collection::create_fixed_collection(
            creator,
            description,
            maxSupply,
            name,
            option::none(),
            uri,
        );

        
    }

}