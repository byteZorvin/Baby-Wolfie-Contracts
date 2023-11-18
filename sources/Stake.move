module owner::Stake {
    // use aptos_framework::fungible_asset;
    use aptos_framework::primary_fungible_store;
    // use aptos_token_objects::token;
    // use aptos_framework::aptos_coin::AptosCoin;
    // use aptos_framework::coin;
    // use std::option::{Self};
    // use std::string::{Self, String};
    use std::signer;
    use aptos_std::table::{Self, Table};
    use owner::NFTCollection::{get_metadata};
    use std::timestamp;
    use owner::config;

    // const RABBIT_TOKEN_NAME: vector<u8> = b"Rabbit Token";
    // const RABBIT_SYMBOL_NAME: vector<u8> = b"RB";

    // const BABY_WOLFIE_TOKEN_NAME: vector<u8> = b"Baby Wolfie Token";
    // const BABY_WOLFIE_SYMBOL_NAME: vector<u8> = b"BW";
    
    struct RabbitStakeInfo has store {
        staker: address,
        amount: u64,
        last_claimed_timestamp: u64,
        unclaimed_amount: u64
    }

    struct BabyWolfieStakeInfo has store {
        staker: address,
        amount: u64,
        last_claimed_timestamp: u64,
        unclaimed_amount: u64,
        last_updated_timestamp: u64
    }

    struct Forest has key {
        rabbit_stake_table: Table<address, RabbitStakeInfo>,
        baby_wolfie_table: Table<address, BabyWolfieStakeInfo>
    }

    fun init_module(sender: &signer) {
        move_to<Forest>(sender, Forest {
            rabbit_stake_table: table::new<address, RabbitStakeInfo>(),
            baby_wolfie_table: table::new<address, BabyWolfieStakeInfo>()   
        });
    }

    public fun stake_rabbit(user: &signer, amount: u64) acquires Forest{
        primary_fungible_store::transfer(user, get_metadata(config::rabbit_token_name()), @owner, amount);
        let forest = borrow_global_mut<Forest>(@owner);
        let rabbit_stake_info = RabbitStakeInfo {
            staker: signer::address_of(user),
            amount: amount,
            last_claimed_timestamp: timestamp::now_seconds(),
            unclaimed_amount: 0,
        };
        table::add(&mut forest.rabbit_stake_table, signer::address_of(user), rabbit_stake_info);
    }

    public fun unstake_rabbit(user: &signer, amount: u64) {
        primary_fungible_store::transfer(user, get_metadata(config::rabbit_token_name()), @owner, amount);
    }

    
}
