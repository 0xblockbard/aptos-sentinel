#[test_only]
module sentinel_addr::kyc_controller_test {

    use sentinel_addr::kyc_controller;
    
    use std::string::{String};
    use std::option::{Self, Option};

    use aptos_std::smart_table::{SmartTable};
    
    use aptos_framework::object;
    use aptos_framework::event::{ was_event_emitted };

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
    const ERROR_TRANSACTION_COUNT_VELOCITY_MAX_EXCEEDED: u64            = 20;
    const ERROR_TRANSACTION_AMOUNT_VELOCITY_MAX_EXCEEDED: u64           = 21;

    // -----------------------------------
    // Constants
    // -----------------------------------


    // -----------------------------------
    // Structs
    // -----------------------------------

    struct Identity has key, store, drop {
        country: u16,               
        investor_status: u8,        
        kyc_registrar : address,
        is_frozen: bool
    }

    struct KycRegistrar has key, store, drop {
        registrar_address : address,
        name : String,
        description : String,
        image_url: String,
        active : bool,
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

            // transaction count velocity
            apply_transaction_count_velocity,
            transaction_count_velocity_timeframe,
            transaction_count_velocity_max,

            // transaction amount velocity
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
    // Admin KYC Registrar Tests
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_add_new_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        // // set up initial values for KYC Registrar
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");
        let image_url       = std::string::utf8(b"https://placehold.co/400x400");

        // call add_or_update_kyc_registrar
        kyc_controller::add_or_update_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // check event emits expected info
        let new_kyc_registrar_event = kyc_controller::test_NewKycRegistrarEvent(
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&new_kyc_registrar_event), 100);

        // verify that is_kyc_registrar returns true
        let (
            is_kyc_registrar
        ) = kyc_controller::is_kyc_registrar(kyc_registrar_one_addr);
        assert!(is_kyc_registrar == true, 101);

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_update_existing_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        // // set up initial values for KYC Registrar
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");
        let image_url       = std::string::utf8(b"https://placehold.co/400x400");

        // call add_or_update_kyc_registrar
        kyc_controller::add_or_update_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // set updated name and description
        name            = std::string::utf8(b"KYC Registrar One Updated");
        description     = std::string::utf8(b"Kyc Registrar One Description Updated");
        image_url       = std::string::utf8(b"https://placehold.co/500x500");

        // call add_or_update_kyc_registrar again to update registrar
        kyc_controller::add_or_update_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // check event emits expected info
        let kyc_registrar_updated_event = kyc_controller::test_KycRegistrarUpdatedEvent(
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&kyc_registrar_updated_event), 100);

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_remove_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        // // set up initial values for KYC Registrar
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");
        let image_url       = std::string::utf8(b"https://placehold.co/400x400");

        // call add_or_update_kyc_registrar
        kyc_controller::add_or_update_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // call remove_kyc_registrar again to remove registrar
        kyc_controller::remove_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr
        );

        // check event emits expected info
        let kyc_registrar_removed_event = kyc_controller::test_KycRegistrarRemovedEvent(
            kyc_registrar_one_addr
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&kyc_registrar_removed_event), 100);

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_KYC_REGISTRAR_NOT_FOUND, location = kyc_controller)]
    public entry fun test_admin_cannot_remove_kyc_registrar_that_does_not_exists(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        // call remove_kyc_registrar on non-existent kyc registrar (not added yet)
        kyc_controller::remove_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_KYC_REGISTRAR_NOT_FOUND, location = kyc_controller)]
    public entry fun test_admin_cannot_toggle_pause_on_kyc_registrar_that_does_not_exists(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        // call toggle_kyc_registrar on non-existent kyc registrar (not added yet)
        let active_bool = false;
        kyc_controller::toggle_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            active_bool
        );
        
    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = kyc_controller)]
    public entry fun test_non_admin_cannot_add_new_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        // // set up initial values for KYC Registrar
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");
        let image_url       = std::string::utf8(b"https://placehold.co/400x400");

        // call add_or_update_kyc_registrar
        kyc_controller::add_or_update_kyc_registrar(
            creator,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

    }

    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = kyc_controller)]
    public entry fun test_non_admin_cannot_update_existing_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        // // set up initial values for KYC Registrar
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");
        let image_url       = std::string::utf8(b"https://placehold.co/400x400");

        // call add_or_update_kyc_registrar
        kyc_controller::add_or_update_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // set updated name and description
        name            = std::string::utf8(b"KYC Registrar One Updated");
        description     = std::string::utf8(b"Kyc Registrar One Description Updated");
        image_url       = std::string::utf8(b"https://placehold.co/500x500");

        // call add_or_update_kyc_registrar again to update registrar
        kyc_controller::add_or_update_kyc_registrar(
            creator,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );
    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = kyc_controller)]
    public entry fun test_non_admin_cannot_remove_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        // // set up initial values for KYC Registrar
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");
        let image_url       = std::string::utf8(b"https://placehold.co/400x400");

        // call add_or_update_kyc_registrar
        kyc_controller::add_or_update_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // call remove_kyc_registrar again to remove registrar
        kyc_controller::remove_kyc_registrar(
            creator,
            kyc_registrar_one_addr
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_toggle_active_for_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        // // set up initial values for KYC Registrar
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");
        let image_url       = std::string::utf8(b"https://placehold.co/400x400");

        // call add_or_update_kyc_registrar
        kyc_controller::add_or_update_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // call toggle_kyc_registrar to set active to true or false
        let active_bool = false;
        kyc_controller::toggle_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            active_bool
        );

        // check event emits expected info
        let toggle_kyc_registrar_event = kyc_controller::test_ToggleKycRegistrarEvent(
            kyc_registrar_one_addr,
            active_bool
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&toggle_kyc_registrar_event), 100);

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = kyc_controller)]
    public entry fun test_non_admin_cannot_toggle_active_for_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        // // set up initial values for KYC Registrar
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");
        let image_url       = std::string::utf8(b"https://placehold.co/400x400");

        // call add_or_update_kyc_registrar
        kyc_controller::add_or_update_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            name,
            description,
            image_url
        );

        // call toggle_kyc_registrar to set active to true or false
        let active_bool = false;
        kyc_controller::toggle_kyc_registrar(
            creator,
            kyc_registrar_one_addr,
            active_bool
        );

    }
    
    // -----------------------------------
    // Valid Country / Investor Status Tests
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_add_or_update_valid_country(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        let counterU16 : Option<u16> = option::none();
        let country                  = std::string::utf8(b"usa");

        // add new valid country
        kyc_controller::add_or_update_valid_country(
            kyc_controller,
            country,
            counterU16
        );

        country     = std::string::utf8(b"japan");

        // update new valid country
        kyc_controller::add_or_update_valid_country(
            kyc_controller,
            country,
            option::some(0)
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_remove_valid_country(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        let counterU16 : Option<u16> = option::none();
        let country                  = std::string::utf8(b"usa");

        // add new valid country
        kyc_controller::add_or_update_valid_country(
            kyc_controller,
            country,
            counterU16
        );

        // remove valid country
        kyc_controller::remove_valid_country(
            kyc_controller,
            0 
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = kyc_controller)]
    public entry fun test_non_admin_cannot_add_or_update_valid_country(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        let counterU16 : Option<u16> = option::none();
        let country                  = std::string::utf8(b"usa");

        // add new valid country
        kyc_controller::add_or_update_valid_country(
            creator,
            country,
            counterU16
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = kyc_controller)]
    public entry fun test_non_admin_cannot_remove_valid_country(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        let counterU16 : Option<u16> = option::none();
        let country                  = std::string::utf8(b"usa");

        // add new valid country
        kyc_controller::add_or_update_valid_country(
            kyc_controller,
            country,
            counterU16
        );

        // remove valid country
        kyc_controller::remove_valid_country(
            creator,
            0 
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_add_or_update_valid_investor_status(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        let counterU8 : Option<u8> = option::none();
        let investor_status        = std::string::utf8(b"standard");

        // add new valid investor_status
        kyc_controller::add_or_update_valid_investor_status(
            kyc_controller,
            investor_status,
            counterU8
        );

        investor_status     = std::string::utf8(b"accredited");

        // update valid investor status
        kyc_controller::add_or_update_valid_investor_status(
            kyc_controller,
            investor_status,
            option::some(0)
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = kyc_controller)]
    public entry fun test_non_admin_cannot_add_or_update_valid_investor_status(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        let counterU8 : Option<u8> = option::none();
        let investor_status        = std::string::utf8(b"standard");

        // add new valid investor_status
        kyc_controller::add_or_update_valid_investor_status(
            creator,
            investor_status,
            counterU8
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_remove_valid_investor_status(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        let counterU8 : Option<u8> = option::none();
        let investor_status        = std::string::utf8(b"standard");

        // add new valid investor_status
        kyc_controller::add_or_update_valid_investor_status(
            kyc_controller,
            investor_status,
            counterU8
        );

        // remove valid investor status
        kyc_controller::remove_valid_investor_status(
            kyc_controller,
            0
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = kyc_controller)]
    public entry fun test_non_admin_cannot_remove_valid_investor_status(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        let counterU8 : Option<u8> = option::none();
        let investor_status        = std::string::utf8(b"standard");

        // add new valid investor_status
        kyc_controller::add_or_update_valid_investor_status(
            kyc_controller,
            investor_status,
            counterU8
        );

        // remove valid investor status
        kyc_controller::remove_valid_investor_status(
            creator,
            0
        );

    }

    // -----------------------------------
    // Transaction Policy Tests
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_add_or_update_transaction_policy(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

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

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = kyc_controller)]
    public entry fun test_non_admin_cannot_add_or_update_transaction_policy(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

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
            creator,
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


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_COUNTRY_NOT_FOUND, location = kyc_controller)]
    public entry fun test_admin_cannot_add_transaction_policy_with_invalid_country(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

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
        let country_id              = 99; // invalid
        let investor_status_id      = 0;  // standard
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

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_INVESTOR_STATUS_NOT_FOUND, location = kyc_controller)]
    public entry fun test_admin_cannot_add_transaction_policy_with_invalid_investor_status(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

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
        let country_id              = 0;  // usa
        let investor_status_id      = 99; // invalid
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

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_remove_transaction_policy(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

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

        // remove transaction policy
        kyc_controller::remove_transaction_policy(
            kyc_controller,
            country_id,
            investor_status_id
        );

        // check event emits expected info
        let transaction_policy_removed_event = kyc_controller::test_TransactionPolicyRemovedEvent(
            country_id,
            investor_status_id
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&transaction_policy_removed_event), 100);

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = kyc_controller)]
    public entry fun test_non_admin_cannot_remove_transaction_policy(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

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

        // remove transaction policy
        kyc_controller::remove_transaction_policy(
            creator,
            country_id,
            investor_status_id
        );

    }

    // -----------------------------------
    // KYC Registrar Tests
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_kyc_registrar_can_add_or_update_kyc_for_user(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // kyc registrar to update KYC for existing user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            true
        );

        // check event emits expected info
        let identity_updated_event = kyc_controller::test_IdentityUpdatedEvent(
            kyc_registrar_one_addr,
            kyc_user_one_addr,
            0,
            0,
            true
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&identity_updated_event), 100);

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_KYC_REGISTRAR, location = kyc_controller)]
    public entry fun test_non_kyc_registrar_cannot_add_kyc_for_user(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // non kyc registrar cannot KYC new users
        kyc_controller::add_or_update_user_identity(
            creator,
            kyc_user_one_addr,
            0,
            0,
            false
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_USER_NOT_KYC, location = kyc_controller)]
    public entry fun test_cannot_get_identity_for_non_kyced_user(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // non kyc registrar cannot KYC new users
        kyc_controller::get_identity(
            kyc_user_one_addr
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_COUNTRY_NOT_FOUND, location = kyc_controller)]
    public entry fun test_kyc_registrar_cannot_add_invalid_country_for_user_kyc(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // invalid country
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            99, // invalid
            0,
            false
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_INVESTOR_STATUS_NOT_FOUND, location = kyc_controller)]
    public entry fun test_kyc_registrar_cannot_add_invalid_investor_status_for_user_kyc(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // invalid investor status
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0, 
            99, // invalid
            false
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_KYC_REGISTRAR_INACTIVE, location = kyc_controller)]
    public entry fun test_inactive_kyc_registrar_cannot_add_kyc_for_user(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // set kyc registrar to inactive
        let active_bool = false;
        kyc_controller::toggle_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            active_bool
        );

        // inactive kyc registrar cannot KYC new users
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0, 
            0, 
            false
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_INVALID_KYC_REGISTRAR_PERMISSION, location = kyc_controller)]
    public entry fun test_kyc_registrar_cannot_change_kyc_for_user_added_by_another_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar one adds new KYC-ed user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0, 
            0, 
            false
        );

        // kyc registrar two cannot change details for KYC-ed user added by registrar one
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_two,
            kyc_user_one_addr,
            0, 
            0, 
            true
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_INVALID_KYC_REGISTRAR_PERMISSION, location = kyc_controller)]
    public entry fun test_kyc_registrar_cannot_add_kyc_for_user_added_by_another_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar one adds new KYC-ed user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0, 
            0, 
            false
        );

        // kyc registrar two cannot change details for KYC-ed user added by registrar one
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_two,
            kyc_user_one_addr,
            0, 
            0, 
            true
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_kyc_registrar_can_remove_kyc_for_user(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // kyc registrar to remove KYC for existing user
        kyc_controller::remove_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
        );

        // check event emits expected info
        let identity_removed_event = kyc_controller::test_IdentityRemovedEvent(
            kyc_registrar_one_addr,
            kyc_user_one_addr
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&identity_removed_event), 100);

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_IDENTITY_NOT_FOUND, location = kyc_controller)]
    public entry fun test_kyc_registrar_can_remove_kyc_for_user_that_does_not_have_an_identity(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to remove KYC for user that does not have identity
        kyc_controller::remove_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr
        );

        // check event emits expected info
        let identity_removed_event = kyc_controller::test_IdentityRemovedEvent(
            kyc_registrar_one_addr,
            kyc_user_one_addr
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&identity_removed_event), 100);

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_KYC_REGISTRAR, location = kyc_controller)]
    public entry fun test_non_kyc_registrar_cannot_remove_kyc_for_user(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // non kyc registrar cannot remove KYC for existing user
        kyc_controller::remove_user_identity(
            creator,
            kyc_user_one_addr,
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_INVALID_KYC_REGISTRAR_PERMISSION, location = kyc_controller)]
    public entry fun test_kyc_registrar_cannot_remove_kyc_for_user_from_another_kyc_registrar(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar one to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // kyc registrar two cannot remove KYC for existing user
        kyc_controller::remove_user_identity(
            kyc_registrar_two,
            kyc_user_one_addr,
        );

    }


    #[test(aptos_framework = @0x1, kyc_controller=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_KYC_REGISTRAR_INACTIVE, location = kyc_controller)]
    public entry fun test_inactive_kyc_registrar_cannot_remove_kyc_for_user(
        aptos_framework: &signer,
        kyc_controller: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two) = kyc_controller::setup_test(aptos_framework, kyc_controller, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

        setup_basic_kyc_for_test(kyc_controller, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar one to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // call toggle_kyc_registrar to set active to true or false
        let active_bool = false;
        kyc_controller::toggle_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            active_bool
        );

        // inactive kyc registrar cannot remove KYC for existing user
        kyc_controller::remove_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
        );

    }


    


}