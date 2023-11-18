module owner::config {
    use std::string::{Self, String};
    friend owner::NFTCollection;
    friend owner::Stake;

    const CHARACTER_COLLECTION_NAME: vector<u8> = b"CHARACTER Collection Name";
    const CHARACTER_COLLECTION_DESCRIPTION: vector<u8> = b"CHARACTER Collection Description";
    const CHARACTER_COLLECTION_URI: vector<u8> = b"https://CHARACTER.collection.uri";
    
    const RABBIT_TOKEN_NAME: vector<u8> = b"Rabbit Token";
    const RABBIT_SYMBOL_NAME: vector<u8> = b"RB";

    const BABY_WOLFIE_TOKEN_NAME: vector<u8> = b"Baby Wolfie Token";
    const BABY_WOLFIE_SYMBOL_NAME: vector<u8> = b"BW";

    const Gen0_Max: u128 = 1u128;
    const Gen1_Max: u128 = 20u128;
    const Gen2_Max: u128 = 40u128;

    public fun collection_name(): String {
        string::utf8(CHARACTER_COLLECTION_NAME)
    }

    public fun collection_description(): String {
        string::utf8(CHARACTER_COLLECTION_DESCRIPTION)
    }

    public fun collection_uri(): String {
        string::utf8(CHARACTER_COLLECTION_URI)
    }

    public fun rabbit_token_name(): String {
        string::utf8(RABBIT_TOKEN_NAME)
    }

    public fun rabbit_symbol_name(): String {
        string::utf8(RABBIT_SYMBOL_NAME)
    }

    public fun baby_wolfie_token_name(): String {
        string::utf8(BABY_WOLFIE_TOKEN_NAME)
    }

    public fun baby_wolfie_symbol_name(): String {
        string::utf8(BABY_WOLFIE_SYMBOL_NAME)
    }

    public fun gen0_max(): u128 {
        Gen0_Max
    }

    public fun gen1_max(): u128 {
        Gen1_Max
    }

    public fun gen2_max(): u128 {
        Gen2_Max
    }

}