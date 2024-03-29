module owner::config {
    use std::string::{Self, String};
    friend owner::NFTCollection;

    const CHARACTER_COLLECTION_NAME: vector<u8> = b"Baby Wolfie Game Collection";
    const CHARACTER_COLLECTION_DESCRIPTION: vector<u8> = b"Baby Wolfie Collection NFTs that allow you to play and earn";
    const CHARACTER_COLLECTION_URI: vector<u8> = b"https://baby-wolfie-game.vercel.app/";
    
    const RABBIT_TOKEN_NAME: vector<u8> = b"Rabbit Token";
    const RABBIT_SYMBOL_NAME: vector<u8> = b"RB";

    const BABY_WOLFIE_TOKEN_NAME: vector<u8> = b"Baby Wolfie Token";
    const BABY_WOLFIE_SYMBOL_NAME: vector<u8> = b"BW";

    const RABBIT_PROBABILITY: u64 = 90;
    const STEAL_PROBABILITY: u64 = 50;

    const Gen0_Max: u128 = 10000u128;
    const Gen1_Max: u128 = 20000u128;
    const Gen2_Max: u128 = 40000u128;
    const Gen0_Mint_Price: u64 = 1000000000000000000u64;

    const DAILY_EARNING_RATE: u64 = 1000000; // 0.01 furtoken per day

    public fun rabbit_probability(): u64 {
        RABBIT_PROBABILITY
    }

    public fun steal_probability(): u64 {
        STEAL_PROBABILITY
    }

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

    public fun gen0_mint_price(): u64 {
        Gen0_Mint_Price
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

    public fun daily_earning_rate(): u64 {
        DAILY_EARNING_RATE
    }

    public fun rabbit_tax_rate(): u64 {
        20
    }

}