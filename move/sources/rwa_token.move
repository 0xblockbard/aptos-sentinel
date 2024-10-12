module sentinel_addr::rwa_token {
    
    use sentinel_addr::kyc_controller;

    use std::event;
    use std::signer;
    use std::timestamp;
    use std::option::{Self};
    use std::string::{Self, utf8};

    // use aptos_std::smart_table::{Self, SmartTable};

    use aptos_framework::function_info;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset, FungibleStore };

    // -----------------------------------
    // Seeds
    // -----------------------------------

    const ASSET_SYMBOL : vector<u8>          = b"KYCRWA";
    const KYC_CONTROLLER_SEED : vector<u8>   = b"SENTINEL";

    // -----------------------------------
    // Constants
    // -----------------------------------

    const ASSET_NAME: vector<u8>      = b"KYC RWA Token Asset";
    const ASSET_ICON: vector<u8>      = b"http://example.com/favicon.ico";
    const ASSET_WEBSITE: vector<u8>   = b"http://example.com";

    // -----------------------------------
    // Errors
    // note: my preference for this convention for better clarity and readability
    // (e.g. ERROR_MIN_CONTRIBUTION_AMOUNT_NOT_REACHED vs EMinContributionAmountNotReached)
    // -----------------------------------

    // KYC Controller Errors
    const ERROR_NOT_ADMIN: u64                                          = 1;
    const ERROR_NOT_KYC_REGISTRAR: u64                                  = 2;
    const ERROR_IDENTITY_NOT_FOUND: u64                                 = 3;
    const ERROR_KYC_REGISTRAR_NOT_FOUND: u64                            = 4;
    const ERROR_USER_NOT_KYC: u64                                       = 5;
    const ERROR_SENDER_NOT_KYC: u64                                     = 6;
    const ERROR_RECEIVER_NOT_KYC: u64                                   = 7;
    const ERROR_KYC_REGISTRAR_INACTIVE: u64                             = 8;
    const ERROR_INVALID_KYC_REGISTRAR_PERMISSION: u64                   = 9;
    const ERROR_USER_IS_FROZEN: u64                                     = 10;
    const ERROR_SENDER_IS_FROZEN: u64                                   = 11;
    const ERROR_RECEIVER_IS_FROZEN: u64                                 = 12;
    const ERROR_SENDER_TRANSACTION_POLICY_CANNOT_SEND: u64              = 13;
    const ERROR_RECEIVER_TRANSACTION_POLICY_CANNOT_RECEIVE: u64         = 14;
    const ERROR_SENDER_COUNTRY_IS_BLACKLISTED: u64                      = 15;
    const ERROR_RECEIVER_COUNTRY_IS_BLACKLISTED: u64                    = 16;
    const ERROR_COUNTRY_NOT_FOUND: u64                                  = 17;
    const ERROR_INVESTOR_STATUS_NOT_FOUND: u64                          = 18;
    const ERROR_SEND_AMOUNT_GREATER_THAN_MAX_TRANSACTION_AMOUNT: u64    = 19;
    const ERROR_TRANSACTION_COUNT_VELOCITY_MAX_EXCEEDED: u64            = 20;
    const ERROR_TRANSACTION_AMOUNT_VELOCITY_MAX_EXCEEDED: u64           = 21;

    // RWA Token Errors
    const ERROR_TRANSFER_KYC_FAIL: u64                                  = 22;
    const ERROR_SEND_NOT_ALLOWED: u64                                   = 23;
    const ERROR_RECEIVE_NOT_ALLOWED: u64                                = 24;
    const ERROR_MAX_TRANSACTION_AMOUNT_EXCEEDED: u64                    = 25;

    // -----------------------------------
    // Structs
    // -----------------------------------

    /* Resources */
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Management has key {
        extend_ref: ExtendRef,
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
    }

    struct AdminInfo has key {
        admin_address: address,
    }

    struct Identity has key, store, drop {
        country: u16,               
        investor_status: u8,        
        kyc_registrar : address,
        is_frozen: bool,

        // transaction count velocity timestamp record
        transaction_count_velocity_timestamp: u64,
        cumulative_transaction_count: u64,

        // transaction amount velocity record
        transaction_amount_velocity_timestamp: u64,
        cumulative_transaction_amount: u64
    }

    struct TransactionPolicy has key, store, drop {
        blacklist_countries: vector<u16>, 
        can_send: bool,                  
        can_receive: bool,               
        max_transaction_amount: u64,  

        // transaction count velocity
        apply_transaction_count_velocity: bool,
        transaction_count_velocity_timeframe: u64,   // in seconds
        transaction_count_velocity_max: u64,         // max number of transactions within given velocity timeframe

        // transaction amount velocity
        apply_transaction_amount_velocity: bool,
        transaction_amount_velocity_timeframe: u64,  // in seconds
        transaction_amount_velocity_max: u64,        // cumulative max amount within given velocity timeframe
    }

    struct TransactionPolicyKey has key, copy, drop, store {
        country: u16,
        investor_status: u8,
    }

    // struct TransactionPolicyTable has key, store {
    //     policies: SmartTable<TransactionPolicyKey, TransactionPolicy>  
    // }

    // -----------------------------------
    // Events
    // -----------------------------------

    /* Events */
    #[event]
    struct Mint has drop, store {
        minter: address,
        to: address,
        amount: u64,
    }

    #[event]
    struct Burn has drop, store {
        minter: address,
        from: address,
        amount: u64,
    }

    // -----------------------------------
    // Views
    // -----------------------------------

    /* View Functions */
    #[view]
    public fun metadata_address(): address {
        object::create_object_address(&@sentinel_addr, ASSET_SYMBOL)
    }

    #[view]
    public fun metadata(): Object<Metadata> {
        object::address_to_object(metadata_address())
    }

    #[view]
    public fun rwa_token_store(): Object<FungibleStore> {
        primary_fungible_store::ensure_primary_store_exists(@sentinel_addr, metadata())
    }

    // -----------------------------------
    // Init
    // -----------------------------------

    /* Initialization - Asset Creation, Register Dispatch Functions */
    fun init_module(admin: &signer) {
        
        // Create the fungible asset metadata object.
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(ASSET_NAME),
            utf8(ASSET_SYMBOL),
            8,
            utf8(ASSET_ICON),
            utf8(ASSET_WEBSITE),
        );

        // Generate a signer for the asset metadata object.
        let metadata_object_signer = &object::generate_signer(constructor_ref);

        // Generate asset management refs and move to the metadata object.
        move_to(metadata_object_signer, Management {
            extend_ref: object::generate_extend_ref(constructor_ref),
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
            transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
        });

        // set AdminInfo
        move_to(metadata_object_signer, AdminInfo {
            admin_address: signer::address_of(admin),
        });

        // Override the withdraw function.
        let withdraw = function_info::new_function_info(
            admin,
            string::utf8(b"rwa_token"),
            string::utf8(b"withdraw"),
        );

        // Override the deposit function.
        let deposit = function_info::new_function_info(
            admin,
            string::utf8(b"rwa_token"),
            string::utf8(b"deposit"),
        );

        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::some(withdraw),
            option::some(deposit),
            option::none(),
        );
    }

    // -----------------------------------
    // Functions
    // -----------------------------------

    /* Dispatchable Hooks */
    /// Withdraw function override for KYC check
    public fun withdraw<T: key>(
        store: Object<T>,
        amount: u64,
        transfer_ref: &TransferRef,
    ) : FungibleAsset {

        let store_owner = object::owner(store);

        // verify KYC status for the store owner (with amount check)
        let (_, can_receive, valid_amount) = kyc_controller::verify_kyc_user(store_owner, option::some(amount));
        assert!(can_receive, ERROR_RECEIVE_NOT_ALLOWED);
        assert!(valid_amount, ERROR_MAX_TRANSACTION_AMOUNT_EXCEEDED);

        // get user identity
        let (
            country,
            investor_status,
            _kyc_registrar,
            _is_frozen,

            // transaction count velocity timestamp record
            user_transaction_count_velocity_timestamp,
            cumulative_transaction_count,

            // transaction amount velocity record
            user_transaction_amount_velocity_timestamp,
            cumulative_transaction_amount
        ) = kyc_controller::get_identity(store_owner);

        // get transaction policy
        let (
            _blacklist_countries,
            _can_send,
            _can_receive,
            _max_transaction_amount,

            _apply_transaction_count_velocity,
            policy_transaction_count_velocity_timeframe,
            _transaction_count_velocity_max,

            _apply_transaction_amount_velocity,
            policy_transaction_amount_velocity_timeframe,
            _transaction_amount_velocity_max
        ) = kyc_controller::get_transaction_policy(country, investor_status);

        // init current time
        let current_time = timestamp::now_seconds();

        // process transaction count velocity
        let time_since_last_transaction = current_time - user_transaction_count_velocity_timestamp;
        if (time_since_last_transaction > policy_transaction_count_velocity_timeframe) {
            // reset cumulative count and timestamp as the velocity timeframe has passed
            kyc_controller::update_user_identity_transaction_count_velocity(
                store_owner,
                current_time,   // current timestamp
                1               // include current transaction as part of cumulative_transaction_count
            );
        } else {
            // add to cumulative count
            kyc_controller::update_user_identity_transaction_count_velocity(
                store_owner,
                user_transaction_count_velocity_timestamp,  // no change to timestamp
                cumulative_transaction_count + 1            // update count
            );
        };

        // process transaction amount velocity
        let time_since_last_amount_velocity = current_time - user_transaction_amount_velocity_timestamp;
        if (time_since_last_amount_velocity > policy_transaction_amount_velocity_timeframe) {
            // reset cumulative amount and timestamp as the velocity timeframe has passed
            kyc_controller::update_user_identity_transaction_amount_velocity(
                store_owner,
                current_time,   // current timestamp
                amount          // include current transaction amount as part of cumulative_transaction_amount
            );
        } else {
            // add to cumulative amount
            kyc_controller::update_user_identity_transaction_amount_velocity(
                store_owner,
                user_transaction_amount_velocity_timestamp,     // no change to timestamp
                cumulative_transaction_amount + amount          // update cumulative_transaction_acmount
            );
        };
        
        // Withdraw the remaining amount from the input store and return it.
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }


    /// Deposit function override for KYC check
    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &TransferRef,
    ) {

        let store_owner    = object::owner(store);
        let deposit_amount = fungible_asset::amount(&fa);

        // verify KYC status for the store owner (with amount check)
        let (can_send, _, valid_amount) = kyc_controller::verify_kyc_user(store_owner, option::some(deposit_amount));
        assert!(can_send, ERROR_SEND_NOT_ALLOWED);
        assert!(valid_amount, ERROR_MAX_TRANSACTION_AMOUNT_EXCEEDED);

        // get user identity
        let (
            country,
            investor_status,
            _kyc_registrar,
            _is_frozen,

            // transaction count velocity timestamp record
            user_transaction_count_velocity_timestamp,
            cumulative_transaction_count,

            // transaction amount velocity record
            user_transaction_amount_velocity_timestamp,
            cumulative_transaction_amount
        ) = kyc_controller::get_identity(store_owner);

        // get transaction policy
        let (
            _blacklist_countries,
            _can_send,
            _can_receive,
            _max_transaction_amount,

            _apply_transaction_count_velocity,
            policy_transaction_count_velocity_timeframe,
            _transaction_count_velocity_max,

            _apply_transaction_amount_velocity,
            policy_transaction_amount_velocity_timeframe,
            _transaction_amount_velocity_max
        ) = kyc_controller::get_transaction_policy(country, investor_status);

        // init current time
        let current_time = timestamp::now_seconds();

        // process transaction count velocity
        let time_since_last_transaction = current_time - user_transaction_count_velocity_timestamp;
        if (time_since_last_transaction > policy_transaction_count_velocity_timeframe) {
            // reset cumulative count and timestamp as the velocity timeframe has passed
            kyc_controller::update_user_identity_transaction_count_velocity(
                store_owner,
                current_time,   // current timestamp
                1               // include current transaction as part of cumulative_transaction_count
            );
        } else {
            // add to cumulative count
            kyc_controller::update_user_identity_transaction_count_velocity(
                store_owner,
                user_transaction_count_velocity_timestamp,  // no change to timestamp
                cumulative_transaction_count + 1            // update count
            );
        };

        // process transaction amount velocity
        let time_since_last_amount_velocity = current_time - user_transaction_amount_velocity_timestamp;
        if (time_since_last_amount_velocity > policy_transaction_amount_velocity_timeframe) {
            // reset cumulative amount and timestamp as the velocity timeframe has passed
            kyc_controller::update_user_identity_transaction_amount_velocity(
                store_owner,
                current_time,   // current timestamp
                deposit_amount  // include current transaction amount as part of cumulative_transaction_amount
            );
        } else {
            // add to cumulative amount
            kyc_controller::update_user_identity_transaction_amount_velocity(
                store_owner,
                user_transaction_amount_velocity_timestamp,     // no change to timestamp
                cumulative_transaction_amount + deposit_amount  // update cumulative_transaction_acmount
            );
        };

        // Deposit the remaining amount from the input store and return it.
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }


    /* Minting and Burning */
    /// Mint new assets to the specified account.
    public entry fun mint(admin: &signer, to: address, amount: u64) acquires Management, AdminInfo {

        let kyc_token_signer_addr = get_token_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_token_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);
        
        let management = borrow_global<Management>(metadata_address());
        let assets = fungible_asset::mint(&management.mint_ref, amount);

        // Verify KYC status for the mint recipient
        let (_, can_receive, _) = kyc_controller::verify_kyc_user(to, option::none());
        assert!(can_receive, ERROR_RECEIVE_NOT_ALLOWED);

        fungible_asset::deposit_with_ref(&management.transfer_ref, primary_fungible_store::ensure_primary_store_exists(to, metadata()), assets);

        event::emit(Mint {
            minter: signer::address_of(admin),
            to,
            amount,
        });
    }


    /// Burn assets from the specified account.
    public entry fun burn(admin: &signer, from: address, amount: u64) acquires Management, AdminInfo{

        let kyc_token_signer_addr = get_token_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_token_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);

        // Withdraw the assets from the account and burn them.
        let management = borrow_global<Management>(metadata_address());
        let assets = withdraw(primary_fungible_store::ensure_primary_store_exists(from, metadata()), amount, &management.transfer_ref);
        fungible_asset::burn(&management.burn_ref, assets);

        event::emit(Burn {
            minter: signer::address_of(admin),
            from,
            amount,
        });
    }

    /* Transfer */
    /// Transfer assets from one account to another.
    public entry fun transfer(from: &signer, to: address, amount: u64) acquires Management {

        // init sender address
        let from_address = signer::address_of(from);

        // Verify KYC between sender and receiver
        // note: verify_kyc_transfer validates sender's transaction_count_velocity_max and transaction_amount_velocity_max
        //       if they are applied in the sender transaction policy
        kyc_controller::verify_kyc_transfer(from_address, to, amount);
        
        // Withdraw the assets from the sender's store and deposit them to the recipient's store.
        let management = borrow_global<Management>(metadata_address());
        let from_store = primary_fungible_store::ensure_primary_store_exists(signer::address_of(from), metadata());
        let to_store   = primary_fungible_store::ensure_primary_store_exists(to, metadata());
        let assets     = withdraw(from_store, amount, &management.transfer_ref);
        
        fungible_asset::deposit_with_ref(&management.transfer_ref, to_store, assets);
    }

    // -----------------------------------
    // Helpers
    // -----------------------------------

    fun get_token_signer_addr() : address {
        object::create_object_address(&@sentinel_addr, ASSET_SYMBOL)
    }

    // -----------------------------------
    // Unit Tests
    // -----------------------------------

    #[test_only]
    public fun setup_test(admin : &signer)  {
        init_module(admin)
    }


    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_RECEIVE_NOT_ALLOWED, location = Self)]
    public fun test_withdraw_should_fail_as_transaction_policy_receive_not_allowed(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    ) acquires Management, AdminInfo {
        
        init_module(kyc_rwa);

        // setup kyc controller environment
        let (
            _kyc_controller_addr, 
            _creator_addr, 
            kyc_registrar_one_addr, 
            kyc_registrar_two_addr, 
            kyc_user_one_addr, 
            _kyc_user_two_addr
        ) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // admin to be able to mint RWA Tokens to KYC-ed user
        let mint_amount = 1000;
        mint(kyc_rwa, kyc_user_one_addr, mint_amount);

        // setup user's fungible store
        let user_store = primary_fungible_store::ensure_primary_store_exists(kyc_user_one_addr, metadata());

        // update transaction policy to can_receive not allowed
        let country_id              = 0; 
        let investor_status_id      = 0; 
        let can_send                = true;
        let can_receive             = false;
        let max_transaction_amount  = 50_000_000_00;
        let blacklist_countries     = vector[]; 

        let apply_transaction_count_velocity        = false;
        let transaction_count_velocity_timeframe    = 86400;
        let transaction_count_velocity_max          = 3;

        let apply_transaction_amount_velocity       = false;
        let transaction_amount_velocity_timeframe   = 86400;
        let transaction_amount_velocity_max         = 5_000_000_00;

        kyc_controller::add_or_update_transaction_policy(
            kyc_rwa,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries,

            apply_transaction_count_velocity,
            transaction_count_velocity_timeframe,
            transaction_count_velocity_max,

            apply_transaction_amount_velocity,
            transaction_amount_velocity_timeframe,
            transaction_amount_velocity_max
        );

        // test withdraw
        let management = borrow_global<Management>(metadata_address());
        let asset      = withdraw(user_store, 10, &management.transfer_ref);

        // burn asset to consume it
        fungible_asset::burn(&management.burn_ref, asset);

    }


    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_MAX_TRANSACTION_AMOUNT_EXCEEDED, location = Self)]
    public fun test_withdraw_should_fail_as_max_transaction_amount_exceeded(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    ) acquires Management, AdminInfo {
        
        init_module(kyc_rwa);

        // setup kyc controller environment
        let (
            _kyc_controller_addr, 
            _creator_addr, 
            kyc_registrar_one_addr, 
            kyc_registrar_two_addr, 
            kyc_user_one_addr, 
            _kyc_user_two_addr
        ) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // admin to be able to mint RWA Tokens to KYC-ed user
        let mint_amount = 1000;
        mint(kyc_rwa, kyc_user_one_addr, mint_amount);

        // setup user's fungible store
        let user_store = primary_fungible_store::ensure_primary_store_exists(kyc_user_one_addr, metadata());

        // update transaction policy max_transaction_amount to 1
        let country_id              = 0; 
        let investor_status_id      = 0; 
        let can_send                = true;
        let can_receive             = true;
        let max_transaction_amount  = 1;
        let blacklist_countries     = vector[]; 

        let apply_transaction_count_velocity        = false;
        let transaction_count_velocity_timeframe    = 86400;
        let transaction_count_velocity_max          = 5;

        let apply_transaction_amount_velocity       = false;
        let transaction_amount_velocity_timeframe   = 86400;
        let transaction_amount_velocity_max         = 500_000_000_00;

        kyc_controller::add_or_update_transaction_policy(
            kyc_rwa,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries,

            apply_transaction_count_velocity,
            transaction_count_velocity_timeframe,
            transaction_count_velocity_max,

            apply_transaction_amount_velocity,
            transaction_amount_velocity_timeframe,
            transaction_amount_velocity_max
        );

        // test withdraw
        let management = borrow_global<Management>(metadata_address());
        let asset      = withdraw(user_store, 10, &management.transfer_ref);

        // burn asset to consume it
        fungible_asset::burn(&management.burn_ref, asset);

    }


    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_SEND_NOT_ALLOWED, location = Self)]
    public fun test_deposit_should_fail_as_transaction_policy_can_send_is_false(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    ) acquires Management, AdminInfo {
        
        init_module(kyc_rwa);

        // setup kyc controller environment
        let (
            _kyc_controller_addr, 
            _creator_addr, 
            kyc_registrar_one_addr, 
            kyc_registrar_two_addr, 
            kyc_user_one_addr, 
            _kyc_user_two_addr
        ) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // admin to be able to mint RWA Tokens to KYC-ed user
        let mint_amount = 1000;
        mint(kyc_rwa, kyc_user_one_addr, mint_amount);

        // setup user's fungible store
        let user_store = primary_fungible_store::ensure_primary_store_exists(kyc_user_one_addr, metadata());

        // update transaction policy to can_send not allowed
        let country_id              = 0; 
        let investor_status_id      = 0; 
        let can_send                = false;
        let can_receive             = true;
        let max_transaction_amount  = 1000;
        let blacklist_countries     = vector[]; 

        let apply_transaction_count_velocity        = false;
        let transaction_count_velocity_timeframe    = 86400;
        let transaction_count_velocity_max          = 5;

        let apply_transaction_amount_velocity       = false;
        let transaction_amount_velocity_timeframe   = 86400;
        let transaction_amount_velocity_max         = 500_000_000_00;

        kyc_controller::add_or_update_transaction_policy(
            kyc_rwa,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries,

            apply_transaction_count_velocity,
            transaction_count_velocity_timeframe,
            transaction_count_velocity_max,

            apply_transaction_amount_velocity,
            transaction_amount_velocity_timeframe,
            transaction_amount_velocity_max
        );

        // test deposit
        let management = borrow_global<Management>(metadata_address());
        let assets     = fungible_asset::mint(&management.mint_ref, 1000);

        // Deposit tokens to user's store
        deposit(user_store, assets, &management.transfer_ref);

    }


    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public fun test_deposit_should_succeed_if_user_is_kyced(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    ) acquires Management, AdminInfo {
        
        init_module(kyc_rwa);

        // setup kyc controller environment
        let (
            _kyc_controller_addr, 
            _creator_addr, 
            kyc_registrar_one_addr, 
            kyc_registrar_two_addr, 
            kyc_user_one_addr, 
            _kyc_user_two_addr
        ) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // admin to be able to mint RWA Tokens to KYC-ed user
        let mint_amount = 100_000;
        mint(kyc_rwa, kyc_user_one_addr, mint_amount);

        // setup user's fungible store
        let user_store = primary_fungible_store::ensure_primary_store_exists(kyc_user_one_addr, metadata());

        // test deposit
        let management      = borrow_global<Management>(metadata_address());
        let deposit_amount  = 1000;
        let assets          = fungible_asset::mint(&management.mint_ref, deposit_amount);

        // get current time
        let current_time = timestamp::now_seconds();

        // Deposit tokens to user's store
        deposit(user_store, assets, &management.transfer_ref);

        // get identity of user
        let (
            _country,
            _investor_status,
            _kyc_registrar,
            _is_frozen,

            // transaction count velocity timestamp record
            user_transaction_count_velocity_timestamp,
            user_cumulative_transaction_count,

            // transaction amount velocity record
            user_transaction_amount_velocity_timestamp,
            user_cumulative_transaction_amount
        ) = kyc_controller::get_identity(kyc_user_one_addr);

        // timestamps set to time of transaction
        assert!(user_transaction_count_velocity_timestamp  == current_time , 100);
        assert!(user_transaction_amount_velocity_timestamp == current_time , 101);

        assert!(user_cumulative_transaction_count     == 1                 , 103);
        assert!(user_cumulative_transaction_amount    == deposit_amount    , 104);

        // fast forward to end of velocity timeframe
        let policy_duration = 86400;
        timestamp::fast_forward_seconds(policy_duration + 1);

        // get updated future time
        let future_time         = timestamp::now_seconds();
        let deposit_amount_2    = 5000;

        let management_2 = borrow_global<Management>(metadata_address());
        let assets_2     = fungible_asset::mint(&management_2.mint_ref, deposit_amount_2);

        // Deposit tokens to user's store to reset velocity timeframe
        deposit(user_store, assets_2, &management_2.transfer_ref);

        // get updated identity of user
        let (
            _country,
            _investor_status,
            _kyc_registrar,
            _is_frozen,

            // transaction count velocity timestamp record
            user_transaction_count_velocity_timestamp,
            user_cumulative_transaction_count,

            // transaction amount velocity record
            user_transaction_amount_velocity_timestamp,
            user_cumulative_transaction_amount
        ) = kyc_controller::get_identity(kyc_user_one_addr);

        // timestamps set to time of transaction
        assert!(user_transaction_count_velocity_timestamp  == future_time , 105);
        assert!(user_transaction_amount_velocity_timestamp == future_time , 106);

        assert!(user_cumulative_transaction_count     == 1                , 107);
        assert!(user_cumulative_transaction_amount    == deposit_amount_2 , 108);

    }


    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_MAX_TRANSACTION_AMOUNT_EXCEEDED, location = Self)]
    public fun test_deposit_should_fail_if_max_transaction_amount_exceeded(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    ) acquires Management, AdminInfo {
        
        init_module(kyc_rwa);

        // setup kyc controller environment
        let (
            _kyc_controller_addr, 
            _creator_addr, 
            kyc_registrar_one_addr, 
            kyc_registrar_two_addr, 
            kyc_user_one_addr, 
            _kyc_user_two_addr
        ) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // admin to be able to mint RWA Tokens to KYC-ed user
        let mint_amount = 99_000_000_00;
        mint(kyc_rwa, kyc_user_one_addr, mint_amount);

        // setup user's fungible store
        let user_store = primary_fungible_store::ensure_primary_store_exists(kyc_user_one_addr, metadata());

        // test deposit
        let management = borrow_global<Management>(metadata_address());
        let assets     = fungible_asset::mint(&management.mint_ref, mint_amount);

        // deposit should fail as max transaction amount exceeded
        deposit(user_store, assets, &management.transfer_ref);

    }

    // -----------------------------------
    // Test KYC Controller Helper Functions
    // -----------------------------------

    #[test_only]
    use std::string::{String};
    #[test_only]
    use std::option::{Option};

    // Helper function: Set up the KYC registrar
    #[test_only]
    public fun setup_kyc_registrar(
        kyc_controller: &signer,
        kyc_registrar_addr: address,
        name: String,
        description: String,
        image_url: String
    ) {
        kyc_controller::add_or_update_kyc_registrar(
            kyc_controller,
            kyc_registrar_addr,
            name,
            description,
            image_url
        );
    }

    // Helper function: Set up valid countries
    #[test_only]
    public fun setup_valid_country(kyc_controller: &signer, country: String, counter: Option<u16>) {
        kyc_controller::add_or_update_valid_country(
            kyc_controller,
            country,
            counter
        );
    }

    // Helper function: Set up valid investor status
    #[test_only]
    public fun setup_valid_investor_status(kyc_controller: &signer, investor_status: String, counter: Option<u8>) {
        kyc_controller::add_or_update_valid_investor_status(
            kyc_controller,
            investor_status,
            counter
        );
    }

    


    #[test_only]
    public fun setup_kyc_for_test(
        kyc_controller: &signer,
        kyc_registrar_one_addr: address,
        kyc_registrar_two_addr: address
    ) {
        
        // set up initial values for KYC Registrar
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");
        let image_url       = std::string::utf8(b"https://placehold.co/400x400");

        // Set up KYC registrar one
        setup_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // set up initial values for KYC Registrar
        name            = std::string::utf8(b"KYC Registrar Two");
        description     = std::string::utf8(b"Kyc Registrar Two Description");

        // Set up KYC registrar
        setup_kyc_registrar(
            kyc_controller,
            kyc_registrar_two_addr,
            name,
            description,
            image_url
        );

        // Set up valid countries
        let counterU16 : Option<u16> = option::none();
        setup_valid_country(kyc_controller, std::string::utf8(b"usa"), counterU16);
        setup_valid_country(kyc_controller, std::string::utf8(b"thailand"), counterU16);
        setup_valid_country(kyc_controller, std::string::utf8(b"japan"), counterU16);
        
        // Set up valid investor status
        let counterU8 : Option<u8>   = option::none();
        setup_valid_investor_status(kyc_controller, std::string::utf8(b"standard"), counterU8);
        setup_valid_investor_status(kyc_controller, std::string::utf8(b"accredited"), counterU8);

        // setup standard transaction policies
        let country_id              = 0; // usa
        let investor_status_id      = 0; // standard
        let can_send                = true;
        let can_receive             = true;
        let max_transaction_amount  = 10000;
        let blacklist_countries     = vector[];

        let apply_transaction_count_velocity        = false;
        let transaction_count_velocity_timeframe    = 86400;
        let transaction_count_velocity_max          = 3;

        let apply_transaction_amount_velocity       = false;
        let transaction_amount_velocity_timeframe   = 86400;
        let transaction_amount_velocity_max         = 5_000_000_00;

        kyc_controller::add_or_update_transaction_policy(
            kyc_controller,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries,

            apply_transaction_count_velocity,
            transaction_count_velocity_timeframe,
            transaction_count_velocity_max,

            apply_transaction_amount_velocity,
            transaction_amount_velocity_timeframe,
            transaction_amount_velocity_max
        );

        country_id              = 0; // usa
        investor_status_id      = 1; // accredited
        kyc_controller::add_or_update_transaction_policy(
            kyc_controller,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries,

            apply_transaction_count_velocity,
            transaction_count_velocity_timeframe,
            transaction_count_velocity_max,

            apply_transaction_amount_velocity,
            transaction_amount_velocity_timeframe,
            transaction_amount_velocity_max
        );

        country_id              = 1; // thailand
        investor_status_id      = 0; // standard
        kyc_controller::add_or_update_transaction_policy(
            kyc_controller,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries,

            apply_transaction_count_velocity,
            transaction_count_velocity_timeframe,
            transaction_count_velocity_max,

            apply_transaction_amount_velocity,
            transaction_amount_velocity_timeframe,
            transaction_amount_velocity_max
        );

        country_id              = 1; // thailand
        investor_status_id      = 1; // accredited
        kyc_controller::add_or_update_transaction_policy(
            kyc_controller,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries,

            apply_transaction_count_velocity,
            transaction_count_velocity_timeframe,
            transaction_count_velocity_max,

            apply_transaction_amount_velocity,
            transaction_amount_velocity_timeframe,
            transaction_amount_velocity_max
        );

        country_id              = 2; // japan
        investor_status_id      = 0; // standard
        kyc_controller::add_or_update_transaction_policy(
            kyc_controller,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries,

            apply_transaction_count_velocity,
            transaction_count_velocity_timeframe,
            transaction_count_velocity_max,

            apply_transaction_amount_velocity,
            transaction_amount_velocity_timeframe,
            transaction_amount_velocity_max
        );

        country_id                          = 2; // japan
        investor_status_id                  = 1; // accredited
        apply_transaction_count_velocity    = true;
        apply_transaction_amount_velocity   = true;
        kyc_controller::add_or_update_transaction_policy(
            kyc_controller,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries,

            apply_transaction_count_velocity,
            transaction_count_velocity_timeframe,
            transaction_count_velocity_max,

            apply_transaction_amount_velocity,
            transaction_amount_velocity_timeframe,
            transaction_amount_velocity_max
        );

    }

}
