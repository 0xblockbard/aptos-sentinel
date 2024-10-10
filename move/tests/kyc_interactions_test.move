#[test_only]
module kyc_rwa_addr::kyc_interactions_test {

    use kyc_rwa_addr::kyc_controller;
    use kyc_rwa_addr::rwa_token;
    use std::option::{Self, Option};

    // use std::signer;
    use std::string::{String};

    use aptos_std::smart_table::{SmartTable};
    
    use aptos_framework::object;
    // use aptos_framework::event::{ was_event_emitted };

    // -----------------------------------
    // Errors
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
    
    // RWA Token Errors
    const ERROR_TRANSFER_KYC_FAIL: u64                                  = 20;
    const ERROR_SEND_NOT_ALLOWED: u64                                   = 21;
    const ERROR_RECEIVE_NOT_ALLOWED: u64                                = 22;
    const ERROR_MAX_TRANSACTION_AMOUNT_EXCEEDED: u64                    = 23;

    // -----------------------------------
    // Structs
    // -----------------------------------

    struct Identity has key, store, drop {
        country: u16,               
        investor_status: u8,        
        kyc_registrar : address,
        is_frozen: bool
    }

    struct IdentityTable has key, store {
        identities : SmartTable<address, Identity>
    }

    struct KycRegistrar has key, store, drop {
        registrar_address : address,
        name : String,
        description : String,
        active : bool,
    }

    struct KycRegistrarTable has key, store {
        kyc_registrars : SmartTable<address, KycRegistrar>, 
    }

    struct ValidCountryTable has key, store {
        countries : SmartTable<u16, String>, 
        counter: u16
    }

    struct ValidInvestorStatusTable has key, store {
        investor_status : SmartTable<u8, String>, 
        counter: u8
    }

    struct TransactionPolicy has key, store, drop {
        blacklist_countries: vector<u16>, 
        can_send: bool,                  
        can_receive: bool,               
        max_transaction_amount: u64,     
    }

    struct TransactionPolicyKey has key, copy, drop, store {
        country: u16,
        investor_status: u8,
    }

    struct TransactionPolicyTable has key, store {
        policies: SmartTable<TransactionPolicyKey, TransactionPolicy>  
    }

    struct KycControllerSigner has key, store {
        extend_ref : object::ExtendRef,
    }

    struct AdminInfo has key {
        admin_address: address,
    }

    // -----------------------------------
    // Test Constants
    // -----------------------------------

    // NIL

    // -----------------------------------
    //
    // Unit Tests
    //
    // -----------------------------------

    // -----------------------------------
    // Helper Functions
    // -----------------------------------

    // Helper function: Set up the KYC registrar
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
    public fun setup_valid_country(kyc_controller: &signer, country: String, counter: Option<u16>) {
        kyc_controller::add_or_update_valid_country(
            kyc_controller,
            country,
            counter
        );
    }

    // Helper function: Set up valid investor status
    public fun setup_valid_investor_status(kyc_controller: &signer, investor_status: String, counter: Option<u8>) {
        kyc_controller::add_or_update_valid_investor_status(
            kyc_controller,
            investor_status,
            counter
        );
    }

    // Helper function: Add transaction policy
    public fun setup_transaction_policy(
        kyc_controller: &signer,
        country_id: u16,
        investor_status_id: u8,
        can_send: bool,
        can_receive: bool,
        max_transaction_amount: u64,
        blacklist_countries: vector<u16>,

        // transaction count velocity
        apply_transaction_count_velocity: bool,
        transaction_count_velocity_timeframe: u64,   // in seconds
        transaction_count_velocity_max: u64,         // max number of transactions within given velocity timeframe

        // transaction amount velocity
        apply_transaction_amount_velocity: bool,
        transaction_amount_velocity_timeframe: u64,  // in seconds
        transaction_amount_velocity_max: u64,        // cumulative max amount within given velocity timeframe
    ) {
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

    // Helper function: setup kyc registrars, valid country, valid investor status, and transaction policies
    public fun setup_basic_kyc_for_test(
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
        let transaction_count_velocity_max          = 5;

        let apply_transaction_amount_velocity       = false;
        let transaction_amount_velocity_timeframe   = 86400;
        let transaction_amount_velocity_max         = 500_000_000_00;

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

        country_id              = 2; // japan
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

    }

    // -----------------------------------
    // KYC + RWA Token Tests - Test Transaction Policies
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_controller=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_kyced_users_can_transfer_to_each_other(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_controller);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new users
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_two_addr,
            0,
            0,
            false
        );

        // admin to mint RWA Tokens to KYC-ed users
        let mint_amount = 1000;
        rwa_token::mint(kyc_controller, kyc_user_one_addr, mint_amount);
        rwa_token::mint(kyc_controller, kyc_user_two_addr, mint_amount);

        // kyc user one can transfer to kyc user two
        let transfer_amount = 100;
        rwa_token::transfer(kyc_user_one, kyc_user_two_addr, transfer_amount);
        
    }

    #[test(aptos_framework = @0x1, kyc_controller=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_RECEIVER_NOT_KYC, location = kyc_controller)]
    public entry fun test_kyc_user_cannot_transfer_to_non_kyc_user(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_controller);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new users
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // admin to mint RWA Tokens to KYC-ed users
        let mint_amount = 1000;
        rwa_token::mint(kyc_controller, kyc_user_one_addr, mint_amount);

        // kyc user one cannot transfer to kyc user two
        let transfer_amount = 100;
        rwa_token::transfer(kyc_user_one, kyc_user_two_addr, transfer_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_controller=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_SENDER_NOT_KYC, location = kyc_controller)]
    public entry fun test_non_kyc_user_cannot_transfer(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, _kyc_user_one_addr, kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_controller);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc user one cannot transfer to kyc user two
        let transfer_amount = 100;
        rwa_token::transfer(kyc_user_one, kyc_user_two_addr, transfer_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_controller=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_USER_IS_FROZEN, location = kyc_controller)]
    public entry fun test_frozen_kyc_user_cannot_send_to_another_user(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_controller);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            true
        );

        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_two_addr,
            0,
            0,
            false
        );

        // admin to mint RWA Tokens to KYC-ed users
        let mint_amount = 1000;
        rwa_token::mint(kyc_controller, kyc_user_one_addr, mint_amount);
        rwa_token::mint(kyc_controller, kyc_user_two_addr, mint_amount);

        // sender is frozen
        let transfer_amount = 100;
        rwa_token::transfer(kyc_user_one, kyc_user_two_addr, transfer_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_controller=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_USER_IS_FROZEN, location = kyc_controller)]
    public entry fun test_kyc_user_cannot_send_to_a_frozen_user(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_controller);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_two_addr,
            0,
            0,
            true
        );

        // admin to mint RWA Tokens to KYC-ed users
        let mint_amount = 1000;
        rwa_token::mint(kyc_controller, kyc_user_one_addr, mint_amount);
        rwa_token::mint(kyc_controller, kyc_user_two_addr, mint_amount);

        // receiver is frozen
        let transfer_amount = 100;
        rwa_token::transfer(kyc_user_one, kyc_user_two_addr, transfer_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_controller=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_SENDER_TRANSACTION_POLICY_CANNOT_SEND, location = kyc_controller)]
    public entry fun test_transfer_fail_as_sender_transaction_policy_can_send_is_false(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_controller);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_two_addr,
            1,
            1,
            false
        );

        // update transaction policy
        let country_id              = 0; 
        let investor_status_id      = 0; 
        let can_send                = false;
        let can_receive             = true;
        let max_transaction_amount  = 10000;
        let blacklist_countries     = vector[];

        let apply_transaction_count_velocity        = false;
        let transaction_count_velocity_timeframe    = 86400;
        let transaction_count_velocity_max          = 5;

        let apply_transaction_amount_velocity       = false;
        let transaction_amount_velocity_timeframe   = 86400;
        let transaction_amount_velocity_max         = 500_000_000_00;

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

        // admin to mint RWA Tokens to KYC-ed users
        let mint_amount = 1000;
        rwa_token::mint(kyc_controller, kyc_user_one_addr, mint_amount);
        rwa_token::mint(kyc_controller, kyc_user_two_addr, mint_amount);

        // sender can_send is false
        let transfer_amount = 100;
        rwa_token::transfer(kyc_user_one, kyc_user_two_addr, transfer_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_controller=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_RECEIVER_TRANSACTION_POLICY_CANNOT_RECEIVE, location = kyc_controller)]
    public entry fun test_transfer_fail_as_receiver_transaction_policy_can_receive_is_false(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_controller);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            1,
            1,
            false
        );

        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_two_addr,
            0,
            0,
            false
        );

        // admin to mint RWA Tokens to KYC-ed users
        let mint_amount = 1000;
        rwa_token::mint(kyc_controller, kyc_user_one_addr, mint_amount);
        rwa_token::mint(kyc_controller, kyc_user_two_addr, mint_amount);

        // update transaction policy
        let country_id              = 0; 
        let investor_status_id      = 0; 
        let can_send                = true;
        let can_receive             = false;
        let max_transaction_amount  = 10000;
        let blacklist_countries     = vector[];

        let apply_transaction_count_velocity        = false;
        let transaction_count_velocity_timeframe    = 86400;
        let transaction_count_velocity_max          = 5;

        let apply_transaction_amount_velocity       = false;
        let transaction_amount_velocity_timeframe   = 86400;
        let transaction_amount_velocity_max         = 500_000_000_00;

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

        // receiver can_receive is false
        let transfer_amount = 100;
        rwa_token::transfer(kyc_user_one, kyc_user_two_addr, transfer_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_controller=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_SENDER_COUNTRY_IS_BLACKLISTED, location = kyc_controller)]
    public entry fun test_transfer_fail_as_sender_country_is_blacklisted_by_receiver_country(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_controller);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // sender
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            1,
            1,
            false
        );

        // receiver
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_two_addr,
            0,
            0,
            false
        );

        // admin to mint RWA Tokens to KYC-ed users
        let mint_amount = 1000;
        rwa_token::mint(kyc_controller, kyc_user_one_addr, mint_amount);
        rwa_token::mint(kyc_controller, kyc_user_two_addr, mint_amount);

        // update transaction policy
        let country_id              = 0; 
        let investor_status_id      = 0; 
        let can_send                = true;
        let can_receive             = true;
        let max_transaction_amount  = 10000;
        let blacklist_countries     = vector[1]; // add sender country to blacklist

        let apply_transaction_count_velocity        = false;
        let transaction_count_velocity_timeframe    = 86400;
        let transaction_count_velocity_max          = 5;

        let apply_transaction_amount_velocity       = false;
        let transaction_amount_velocity_timeframe   = 86400;
        let transaction_amount_velocity_max         = 500_000_000_00;

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

        // sender country blacklisted
        let transfer_amount = 100;
        rwa_token::transfer(kyc_user_one, kyc_user_two_addr, transfer_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_controller=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_RECEIVER_COUNTRY_IS_BLACKLISTED, location = kyc_controller)]
    public entry fun test_transfer_fail_as_receiver_country_is_blacklisted_by_sender_country(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_controller);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // sender
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            1,
            1,
            false
        );

        // receiver
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_two_addr,
            0,
            0,
            false
        );

        // admin to mint RWA Tokens to KYC-ed users
        let mint_amount = 1000;
        rwa_token::mint(kyc_controller, kyc_user_one_addr, mint_amount);
        rwa_token::mint(kyc_controller, kyc_user_two_addr, mint_amount);

        // update transaction policy
        let country_id              = 1; 
        let investor_status_id      = 1; 
        let can_send                = true;
        let can_receive             = true;
        let max_transaction_amount  = 10000;
        let blacklist_countries     = vector[0]; // add receiver country to blacklist

        let apply_transaction_count_velocity        = false;
        let transaction_count_velocity_timeframe    = 86400;
        let transaction_count_velocity_max          = 5;

        let apply_transaction_amount_velocity       = false;
        let transaction_amount_velocity_timeframe   = 86400;
        let transaction_amount_velocity_max         = 500_000_000_00;

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

        // receiver country blacklisted
        let transfer_amount = 100;
        rwa_token::transfer(kyc_user_one, kyc_user_two_addr, transfer_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_controller=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_SEND_AMOUNT_GREATER_THAN_MAX_TRANSACTION_AMOUNT, location = kyc_controller)]
    public entry fun test_transfer_fail_as_max_transaction_amount_exceeded(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_controller);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // sender
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            1,
            1,
            false
        );

        // receiver
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_two_addr,
            0,
            0,
            false
        );

        // admin to mint RWA Tokens to KYC-ed users
        let mint_amount = 1000;
        rwa_token::mint(kyc_controller, kyc_user_one_addr, mint_amount);
        rwa_token::mint(kyc_controller, kyc_user_two_addr, mint_amount);

        // update transaction policy
        let country_id              = 1; 
        let investor_status_id      = 1; 
        let can_send                = true;
        let can_receive             = true;
        let max_transaction_amount  = 10; // change to a low number
        let blacklist_countries     = vector[]; 

        let apply_transaction_count_velocity        = false;
        let transaction_count_velocity_timeframe    = 86400;
        let transaction_count_velocity_max          = 5;

        let apply_transaction_amount_velocity       = false;
        let transaction_amount_velocity_timeframe   = 86400;
        let transaction_amount_velocity_max         = 500_000_000_00;

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

        // max transaction amount exceeded
        let transfer_amount = 100;
        rwa_token::transfer(kyc_user_one, kyc_user_two_addr, transfer_amount);
        
    }


}