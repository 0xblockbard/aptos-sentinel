#[test_only]
module kyc_rwa_addr::rwa_token_test {

    use kyc_rwa_addr::kyc_controller;
    use kyc_rwa_addr::rwa_token;
    use std::option::{Self, Option};

    use std::string::{String};

    use aptos_std::smart_table::{SmartTable};
    
    use aptos_framework::object::{Self};

    // -----------------------------------
    // Errors
    // -----------------------------------

    // KYC Controller Errors
    const ERROR_NOT_ADMIN: u64                                          = 1;
    const ERROR_NOT_KYC_REGISTRAR: u64                                  = 2;
    const ERROR_USER_NOT_KYC: u64                                       = 3;
    const ERROR_SENDER_NOT_KYC: u64                                     = 4;
    const ERROR_RECEIVER_NOT_KYC: u64                                   = 5;
    const ERROR_KYC_REGISTRAR_INACTIVE: u64                             = 6;
    const ERROR_INVALID_KYC_REGISTRAR_PERMISSION: u64                   = 7;
    const ERROR_USER_IS_FROZEN: u64                                     = 8;
    const ERROR_SENDER_IS_FROZEN: u64                                   = 9;
    const ERROR_RECEIVER_IS_FROZEN: u64                                 = 10;
    const ERROR_SENDER_TRANSACTION_POLICY_CANNOT_SEND: u64              = 11;
    const ERROR_RECEIVER_TRANSACTION_POLICY_CANNOT_RECEIVE: u64         = 12;
    const ERROR_SENDER_COUNTRY_IS_BLACKLISTED: u64                      = 13;
    const ERROR_RECEIVER_COUNTRY_IS_BLACKLISTED: u64                    = 14;
    const ERROR_COUNTRY_NOT_FOUND: u64                                  = 15;
    const ERROR_INVESTOR_STATUS_NOT_FOUND: u64                          = 16;
    const ERROR_SEND_AMOUNT_GREATER_THAN_MAX_TRANSACTION_AMOUNT: u64    = 17;
    
    // RWA Token Errors
    const ERROR_TRANSFER_KYC_FAIL: u64                                  = 18;
    const ERROR_SEND_NOT_ALLOWED: u64                                   = 19;
    const ERROR_RECEIVE_NOT_ALLOWED: u64                                = 20;
    const ERROR_MAX_TRANSACTION_AMOUNT_EXCEEDED: u64                    = 21;

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
        description: String
    ) {
        kyc_controller::add_or_update_kyc_registrar(
            kyc_controller,
            kyc_registrar_addr,
            name,
            description
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
        blacklist_countries: vector<u16>
    ) {
        kyc_controller::add_or_update_transaction_policy(
            kyc_controller,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries
        );
    }


    public fun setup_kyc_for_test(
        kyc_controller: &signer,
        kyc_registrar_one_addr: address,
        kyc_registrar_two_addr: address
    ) {
        
        // set up initial values for KYC Registrar
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");

        // Set up KYC registrar one
        setup_kyc_registrar(
            kyc_controller,
            kyc_registrar_one_addr,
            name,
            description
        );

        // set up initial values for KYC Registrar
        name            = std::string::utf8(b"KYC Registrar Two");
        description     = std::string::utf8(b"Kyc Registrar Two Description");

        // Set up KYC registrar
        setup_kyc_registrar(
            kyc_controller,
            kyc_registrar_two_addr,
            name,
            description
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

        kyc_controller::add_or_update_transaction_policy(
            kyc_controller,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries
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
            blacklist_countries
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
            blacklist_countries
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
            blacklist_countries
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
            blacklist_countries
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
            blacklist_countries
        );

    }

    // -----------------------------------
    // Mint Tests 
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_mint_rwa_tokens_to_kyced_user(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_rwa);

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
        rwa_token::mint(kyc_rwa, kyc_user_one_addr, mint_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = rwa_token)]
    public entry fun test_non_admin_cannot_mint_rwa_tokens_to_kyced_user(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_rwa);

        setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // non admin cannot mint
        let mint_amount = 1000;
        rwa_token::mint(creator, kyc_user_one_addr, mint_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_USER_NOT_KYC, location = kyc_controller)]
    public entry fun test_admin_cannot_mint_rwa_tokens_to_non_kyced_user(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_rwa);

        setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // admin to not be able to mint RWA Tokens to non KYC-ed user
        let mint_amount = 1000;
        rwa_token::mint(kyc_rwa, kyc_user_one_addr, mint_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_RECEIVE_NOT_ALLOWED, location = rwa_token)]
    public entry fun test_admin_cannot_mint_rwa_tokens_to_kyc_user_if_can_receive_is_false(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_rwa);

        setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // kyc registrar to KYC new user
        kyc_controller::add_or_update_user_identity(
            kyc_registrar_one,
            kyc_user_one_addr,
            0,
            0,
            false
        );

        // update transaction policy
        let country_id              = 0; 
        let investor_status_id      = 0; 
        let can_send                = true;
        let can_receive             = false;
        let max_transaction_amount  = 10000;
        let blacklist_countries     = vector[]; 

        kyc_controller::add_or_update_transaction_policy(
            kyc_rwa,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries
        );

        // can_receive is false
        let mint_amount = 1000;
        rwa_token::mint(kyc_rwa, kyc_user_one_addr, mint_amount);
        
    }

    // -----------------------------------
    // Burn Tests 
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_admin_can_burn_rwa_tokens_from_kyced_user(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_rwa);

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
        rwa_token::mint(kyc_rwa, kyc_user_one_addr, mint_amount);

        // admin to be able to burn RWA Tokens from KYC-ed user
        let burn_amount = 100;
        rwa_token::burn(kyc_rwa, kyc_user_one_addr, burn_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = rwa_token)]
    public entry fun test_non_admin_cannot_burn_rwa_tokens_from_kyced_user(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_rwa);

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
        rwa_token::mint(kyc_rwa, kyc_user_one_addr, mint_amount);

        // non admin cannot burn
        let burn_amount = 100;
        rwa_token::burn(creator, kyc_user_one_addr, burn_amount);
        
    }

    // -----------------------------------
    // Deposit Tests
    // -----------------------------------

    // #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    // public entry fun test_deposit_success(
    //     aptos_framework: &signer,
    //     kyc_rwa: &signer,
    //     creator: &signer,
    //     kyc_registrar_one: &signer,
    //     kyc_registrar_two: &signer,
    //     kyc_user_one: &signer,
    //     kyc_user_two: &signer
    // ) acquires Management {

    //     // setup environment
    //     let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
    //     rwa_token::setup_test(kyc_rwa);

    //     setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

    //     // kyc registrar to KYC new user
    //     kyc_controller::add_or_update_user_identity(
    //         kyc_registrar_one,
    //         kyc_user_one_addr,
    //         0,
    //         0,
    //         false
    //     );

    //     // Create the user's primary fungible store.
    //     let user_store = primary_fungible_store::ensure_primary_store_exists(kyc_user_one_addr, rwa_token::metadata());

    //     // Mint some tokens for the user.
    //     rwa_token::mint(kyc_rwa, kyc_user_one_addr, 1000);

    //     // Use helper function to get the management signer
    //     // let token_signer_addr = rwa_token::get_token_signer_addr();
    //     // let management_signer = rwa_token::get_management_signer(token_signer_addr);

    //     // Simulate a deposit using the management signer.
    //     // rwa_token::deposit(user_store, fungible_asset::mint(&management_signer, 100), &management_signer);


    //     // // Simulate a deposit.
    //     // let management = borrow_global<Management>(@kyc_rwa_addr);
    //     // let assets = fungible_asset::mint(&management.mint_ref, 100);
    //     // rwa_token::deposit(user_store, assets, &management.transfer_ref);

    //     // Assert that the deposit was successful (e.g., check user balance).
    //     // let user_balance = primary_fungible_store::balance(user_store);
    //     // assert!(user_balance == 1100, 100);  // Assuming the user had 1000 tokens before.
    // }

    // -----------------------------------
    // View Tests 
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
    public entry fun test_rwa_token_store(
        aptos_framework: &signer,
        kyc_rwa: &signer,
        creator: &signer,
        kyc_registrar_one: &signer,
        kyc_registrar_two: &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer
    )  {

        // setup environment
        let (_kyc_controller_addr, _creator_addr, _kyc_registrar_one_addr, _kyc_registrar_two_addr, _kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);
        rwa_token::setup_test(kyc_rwa);

        let _token_store = rwa_token::rwa_token_store();
        
    }


}