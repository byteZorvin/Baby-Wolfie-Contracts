module owner::old_stake {
    // use aptos_framework::fungible_asset;
    use aptos_framework::primary_fungible_store;
    // use aptos_token_objects::token;
    // use aptos_framework::aptos_coin::AptosCoin;
    // use aptos_framework::coin;
    // use std::option::{Self};
    // use std::string::{Self};
    use std::debug;
    use std::signer;
    use aptos_std::table::{Self, Table};
    use owner::NFTCollection::{get_metadata};
    use std::timestamp;
    use owner::config;

    const ENOT_STAKED: u64 = 1;
    
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
        // debug::print(&string::utf8(b"Rabbit staked"));
    }

    public fun unstake_rabbit(user: &signer, _amount: u64) acquires Forest{
        let forest = borrow_global<Forest>(@owner);
        assert!(table::contains(&forest.rabbit_stake_table, signer::address_of(user)), ENOT_STAKED);
        // primary_fungible_store::transfer(@owner, get_metadata(config::rabbit_token_name()), user, amount);
    }

    public fun check_if_contains(user: &signer) acquires Forest{
        let forest = borrow_global<Forest>(@owner);
        let rabbit = table::borrow(&forest.rabbit_stake_table, signer::address_of(user));
        debug::print(rabbit);
        assert!(table::contains(&forest.rabbit_stake_table, signer::address_of(user)), ENOT_STAKED);
        // assert!(table::contains(&forest.baby_wolfie_table, signer::address_of(user)), ENOT_STAKED);
    }

    #[test_only]
    public fun initialize(sender: &signer) {
        init_module(sender);
    }
}
