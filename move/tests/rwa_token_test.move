#[test_only]
module sentinel_addr::rwa_token_test {

    use sentinel_addr::kyc_controller;
    use sentinel_addr::rwa_token;
    
    use std::string::{String};

    use aptos_std::smart_table::{SmartTable};
    
    use aptos_framework::object::{Self};

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

    // RWA Token Errors
    const ERROR_TRANSFER_KYC_FAIL: u64                                  = 22;
    const ERROR_SEND_NOT_ALLOWED: u64                                   = 23;
    const ERROR_RECEIVE_NOT_ALLOWED: u64                                = 24;
    const ERROR_MAX_TRANSACTION_AMOUNT_EXCEEDED: u64                    = 25;

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
    // Mint Tests 
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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
        rwa_token::setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

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


    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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
        rwa_token::setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

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


    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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
        rwa_token::setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

        // admin to not be able to mint RWA Tokens to non KYC-ed user
        let mint_amount = 1000;
        rwa_token::mint(kyc_rwa, kyc_user_one_addr, mint_amount);
        
    }


    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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
        rwa_token::setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

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

        // can_receive is false
        let mint_amount = 1000;
        rwa_token::mint(kyc_rwa, kyc_user_one_addr, mint_amount);
        
    }

    // -----------------------------------
    // Burn Tests 
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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
        rwa_token::setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

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


    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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
        rwa_token::setup_kyc_for_test(kyc_rwa, kyc_registrar_one_addr, kyc_registrar_two_addr);

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
    // View Tests 
    // -----------------------------------

    #[test(aptos_framework = @0x1, kyc_rwa=@sentinel_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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