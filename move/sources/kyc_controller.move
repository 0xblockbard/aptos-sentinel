module kyc_rwa_addr::kyc_controller {

    use std::signer;
    use std::event;
    use std::string::{String};
    use std::option::{Self, Option};
    
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::vector::{Self};
    
    use aptos_framework::object::{Self};

    // -----------------------------------
    // Seeds
    // -----------------------------------

    const APP_OBJECT_SEED : vector<u8>   = b"KYC";

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
    // Events
    // -----------------------------------

    #[event]
    struct IdentityRegisteredEvent has drop, store {
        kyc_registrar: address,
        user: address,
        country: u16,
        investor_status: u8,
        is_frozen: bool
    }

    #[event]
    struct IdentityUpdatedEvent has drop, store {
        kyc_registrar: address,
        user: address,
        country: u16,
        investor_status: u8,
        is_frozen: bool
    }

    #[event]
    struct IdentityRemovedEvent has drop, store {
        kyc_registrar: address,
        user: address,
    }

    #[event]
    struct NewKycRegistrarEvent has drop, store {
        registrar_address: address,
        name: String,
        description: String
    }

    #[event]
    struct KycRegistrarUpdatedEvent has drop, store {
        registrar_address: address,
        name: String,
        description: String
    }

    #[event]
    struct KycRegistrarRemovedEvent has drop, store {
        registrar_address: address
    }

    #[event]
    struct ToggleKycRegistrarEvent has drop, store {
        registrar_address: address,
        active: bool
    }

    #[event]
    struct NewTransactionPolicyEvent has drop, store {
        country: u16,
        investor_status: u8, 
        can_send: bool,                  
        can_receive: bool,               
        max_transaction_amount: u64,   
        blacklist_countries: vector<u16>, 
    }

    #[event]
    struct TransactionPolicyRemovedEvent has drop, store {
        country: u16,
        investor_status: u8
    }

    // -----------------------------------
    // Errors
    // -----------------------------------

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
    
    // -----------------------------------
    // Init
    // -----------------------------------

    /// init module 
    fun init_module(admin : &signer) {

        let constructor_ref = object::create_named_object(
            admin,
            APP_OBJECT_SEED,
        );
        let extend_ref            = object::generate_extend_ref(&constructor_ref);
        let kyc_controller_signer = &object::generate_signer(&constructor_ref);

        // set KycControllerSigner
        move_to(kyc_controller_signer, KycControllerSigner {
            extend_ref,
        });

        // set AdminInfo
        move_to(kyc_controller_signer, AdminInfo {
            admin_address: signer::address_of(admin),
        });

        // init identity struct
        move_to(kyc_controller_signer, IdentityTable {
            identities: smart_table::new(),
        });

        // init kyc registrars struct
        move_to(kyc_controller_signer, KycRegistrarTable {
            kyc_registrars: smart_table::new(),
        });

        // init transaction policy struct
        move_to(kyc_controller_signer, TransactionPolicyTable {
            policies: smart_table::new(),
        });

        // init valid country struct
        move_to(kyc_controller_signer, ValidCountryTable {
            countries: smart_table::new(),
            counter: 0
        });

        // init valid investor status struct
        move_to(kyc_controller_signer, ValidInvestorStatusTable {
            investor_status: smart_table::new(),
            counter: 0
        });
    }

    // -----------------------------------
    // Admin Functions : KYC Registrar
    // -----------------------------------

    /// add or update kyc registrar
    public entry fun add_or_update_kyc_registrar(
        admin: &signer, 
        registrar_address: address, 
        name: String,
        description: String
    ) acquires AdminInfo, KycRegistrarTable {
        
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_controller_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);

        // get the KycRegistrarTable resource
        let kyc_registrar_table = borrow_global_mut<KycRegistrarTable>(kyc_controller_signer_addr);

        // emit events
        if (smart_table::contains<address, KycRegistrar>(&kyc_registrar_table.kyc_registrars, registrar_address)) {

            // emit event for updated KYC registrar
            event::emit(KycRegistrarUpdatedEvent {
                registrar_address,
                name,
                description,
            });

        } else {
            
            // emit event for new KYC registrar
            event::emit(NewKycRegistrarEvent {
                registrar_address,
                name,
                description,
            });

        };
        
        // create a new KYC registrar and insert it into the smart table
        smart_table::upsert(
            &mut kyc_registrar_table.kyc_registrars, 
            registrar_address, 
            KycRegistrar {
                registrar_address,
                name,
                description,
                active: true,
            },
        );
        
    }


    /// removes a kyc registrar
    public entry fun remove_kyc_registrar(
        admin: &signer, 
        registrar_address: address
    ) acquires AdminInfo, KycRegistrarTable {
        
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_controller_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);

        // get the KycRegistrarTable resource
        let kyc_registrar_table = borrow_global_mut<KycRegistrarTable>(kyc_controller_signer_addr);

        //removes KYC registrar
        smart_table::remove(
            &mut kyc_registrar_table.kyc_registrars, 
            registrar_address
        );

        // emit event for the removed KYC registrar
        event::emit(KycRegistrarRemovedEvent {
            registrar_address
        });
        
    }


    /// toggle KYC Registrar
    public entry fun toggle_kyc_registrar(
        admin: &signer, 
        registrar_address: address,
        toggle_bool: bool
    ) acquires AdminInfo, KycRegistrarTable {
        
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_controller_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);

        // get the KycRegistrarTable resource
        let kyc_registrar_table = borrow_global_mut<KycRegistrarTable>(kyc_controller_signer_addr);

        //get KYC registrar
        let kyc_registrar = smart_table::borrow_mut(
            &mut kyc_registrar_table.kyc_registrars, 
            registrar_address
        );

        kyc_registrar.active = toggle_bool;

        // emit event for the toggled KYC registrar
        event::emit(ToggleKycRegistrarEvent {
            registrar_address,
            active : toggle_bool
        });
        
    }

    // -----------------------------------
    // Admin Functions : Valid Country / Investor Status
    // -----------------------------------

    /// add or update valid country
    public entry fun add_or_update_valid_country(
        admin: &signer, 
        country: String,
        counter: Option<u16>
    ) acquires AdminInfo, ValidCountryTable {
        
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_controller_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);

        // get the ValidCountryTable resource
        let valid_country_table = borrow_global_mut<ValidCountryTable>(kyc_controller_signer_addr);
        let use_counter;

        if (option::is_some(&counter)) {
            // update valid country
            use_counter = option::extract(&mut counter); 
        } else {
            // add new valid country
            use_counter                 = valid_country_table.counter;
            valid_country_table.counter = use_counter + 1;
        };

        // upsert entry
        smart_table::upsert(
            &mut valid_country_table.countries, 
            use_counter, 
            country
        );
        
    }


    /// remove valid country
    public entry fun remove_valid_country(
        admin: &signer, 
        country: u16
    ) acquires AdminInfo, ValidCountryTable {
        
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_controller_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);

        // get the ValidCountryTable resource
        let valid_country_table = borrow_global_mut<ValidCountryTable>(kyc_controller_signer_addr);

        // remove valid country
        smart_table::remove(
            &mut valid_country_table.countries, 
            country
        );
        
    }


    /// add or update valid investor status
    public entry fun add_or_update_valid_investor_status(
        admin: &signer, 
        investor_status: String,
        counter: Option<u8>
    ) acquires AdminInfo, ValidInvestorStatusTable {
        
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_controller_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);

        // get the ValidInvestorStatusTable resource
        let valid_investor_status_table = borrow_global_mut<ValidInvestorStatusTable>(kyc_controller_signer_addr);
        let use_counter;

        if (option::is_some(&counter)) {
            // update valid country
            use_counter = option::extract(&mut counter); 
        } else {
            // add new valid country
            use_counter                         = valid_investor_status_table.counter;
            valid_investor_status_table.counter = use_counter + 1;
        };

        // upsert entry
        smart_table::upsert(
            &mut valid_investor_status_table.investor_status, 
            use_counter, 
            investor_status
        );

    }


    /// remove valid investor status
    public entry fun remove_valid_investor_status(
        admin: &signer, 
        investor_status: u8
    ) acquires AdminInfo, ValidInvestorStatusTable {
        
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_controller_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);

        // get the ValidInvestorStatusTable resource
        let valid_investor_status_table = borrow_global_mut<ValidInvestorStatusTable>(kyc_controller_signer_addr);

        // remove valid investor status
        smart_table::remove(
            &mut valid_investor_status_table.investor_status, 
            investor_status
        );
        
    }

    // -----------------------------------
    // Admin Functions : Transaction Policy
    // -----------------------------------

    /// add a new transaction policy
    public entry fun add_or_update_transaction_policy(
        admin: &signer, 
        country: u16, 
        investor_status: u8,
        can_send: bool,
        can_receive: bool,
        max_transaction_amount: u64,
        blacklist_countries: vector<u16>
    ) acquires AdminInfo, TransactionPolicyTable, ValidCountryTable, ValidInvestorStatusTable {
        
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_controller_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);

        // get the TransactionPolicyTable resource
        let transaction_policy_table    = borrow_global_mut<TransactionPolicyTable>(kyc_controller_signer_addr);
        let valid_country_table         = borrow_global_mut<ValidCountryTable>(kyc_controller_signer_addr);
        let valid_investor_status_table = borrow_global_mut<ValidInvestorStatusTable>(kyc_controller_signer_addr);

        // verify country and investor status exists
        if (!smart_table::contains(&valid_country_table.countries, country)) {
            // Abort if country is not found
            abort ERROR_COUNTRY_NOT_FOUND
        };

        if (!smart_table::contains(&valid_investor_status_table.investor_status, investor_status)) {
            // Abort if investor status is not found
            abort ERROR_INVESTOR_STATUS_NOT_FOUND
        };

        // set transaction policy key
        let transaction_policy_key = TransactionPolicyKey {
            country,
            investor_status
        };

        // create a new transaction policy
        smart_table::upsert(
            &mut transaction_policy_table.policies, 
            transaction_policy_key, 
            TransactionPolicy {
                blacklist_countries,
                can_send,
                can_receive,
                max_transaction_amount,
            },
        );

        // emit event for new Transaction Policy
        event::emit(NewTransactionPolicyEvent {
            country,
            investor_status,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries
        });
        
    }


    /// remove transaction policy
    public entry fun remove_transaction_policy(
        admin: &signer, 
        country: u16, 
        investor_status: u8,
    ) acquires AdminInfo, TransactionPolicyTable {
        
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // verify signer is the admin
        let admin_info = borrow_global<AdminInfo>(kyc_controller_signer_addr);
        assert!(signer::address_of(admin) == admin_info.admin_address, ERROR_NOT_ADMIN);

        // get the smart table
        let transaction_policy_table    = borrow_global_mut<TransactionPolicyTable>(kyc_controller_signer_addr);

        // set transaction policy key
        let transaction_policy_key = TransactionPolicyKey {
            country,
            investor_status
        };

        // remove valid investor status
        smart_table::remove(
            &mut transaction_policy_table.policies, 
            transaction_policy_key
        );
        
        // emit event for removal of transaction policy
        event::emit(TransactionPolicyRemovedEvent {
            country,
            investor_status
        });
    }

    // -----------------------------------
    // KYC Registrar Functions
    // -----------------------------------

    /// adds or updates a user's identity. Only KYC registrars can manage identities.
    public entry fun add_or_update_user_identity(
        registrar: &signer, 
        user: address, 
        country: u16, 
        investor_status: u8,
        is_frozen: bool
    ) acquires IdentityTable, KycRegistrarTable, ValidCountryTable, ValidInvestorStatusTable {

        // Check if the signer is a valid KYC registrar
        let registrar_addr = signer::address_of(registrar);
        assert!(is_kyc_registrar(registrar_addr), ERROR_NOT_KYC_REGISTRAR);

        // Access the IdentityTable
        let kyc_controller_signer_addr  = get_kyc_controller_signer_addr();
        let identity_table              = borrow_global_mut<IdentityTable>(kyc_controller_signer_addr);
        let kyc_registrars_table        = borrow_global_mut<KycRegistrarTable>(kyc_controller_signer_addr);
        let valid_country_table         = borrow_global_mut<ValidCountryTable>(kyc_controller_signer_addr);
        let valid_investor_status_table = borrow_global_mut<ValidInvestorStatusTable>(kyc_controller_signer_addr);

        // get kyc registrar and verify that it is active
        let kyc_registrar = smart_table::borrow<address, KycRegistrar>(&kyc_registrars_table.kyc_registrars, registrar_addr);
        assert!(kyc_registrar.active, ERROR_KYC_REGISTRAR_INACTIVE);

        // verify country and investor status exists
        if (!smart_table::contains(&valid_country_table.countries, country)) {
            // Abort if country is not found
            abort ERROR_COUNTRY_NOT_FOUND
        };

        if (!smart_table::contains(&valid_investor_status_table.investor_status, investor_status)) {
            // Abort if investor status is not found
            abort ERROR_INVESTOR_STATUS_NOT_FOUND
        };

        // check if the identity already exists or not
        if (smart_table::contains<address, Identity>(&identity_table.identities, user)) {
            
            // identity already exists

            // kyc registrars can only manage users that they have onboarded
            let identity = smart_table::borrow<address, Identity>(&identity_table.identities, user);
            assert!(identity.kyc_registrar == registrar_addr, ERROR_INVALID_KYC_REGISTRAR_PERMISSION);

            // emit event for identity update
            event::emit(IdentityUpdatedEvent {
                kyc_registrar: registrar_addr,
                user,
                country,
                investor_status,
                is_frozen
            });

        } else {

            // add new identity

            // emit event for new identity registration
            event::emit(IdentityRegisteredEvent {
                kyc_registrar: registrar_addr,
                user,
                country,
                investor_status,
                is_frozen
            });

        };

        // upsert table
        smart_table::upsert(
            &mut identity_table.identities,
            user,
            Identity { 
                country, 
                investor_status, 
                kyc_registrar: registrar_addr,
                is_frozen
            }
        );
        
    }


    /// remove user identity
    public entry fun remove_user_identity(
        registrar: &signer, 
        user: address
    ) acquires IdentityTable, KycRegistrarTable, {
        
        // Check if the signer is a valid KYC registrar
        let registrar_addr = signer::address_of(registrar);
        assert!(is_kyc_registrar(registrar_addr), ERROR_NOT_KYC_REGISTRAR);

        // Access the IdentityTable
        let kyc_controller_signer_addr  = get_kyc_controller_signer_addr();
        let identity_table              = borrow_global_mut<IdentityTable>(kyc_controller_signer_addr);
        let kyc_registrars_table        = borrow_global_mut<KycRegistrarTable>(kyc_controller_signer_addr);

        // get kyc registrar and verify that it is active
        let kyc_registrar = smart_table::borrow<address, KycRegistrar>(&kyc_registrars_table.kyc_registrars, registrar_addr);
        assert!(kyc_registrar.active, ERROR_KYC_REGISTRAR_INACTIVE);

        // kyc registrars can only manage users that they have onboarded
        let identity = smart_table::borrow<address, Identity>(&identity_table.identities, user);
        assert!(identity.kyc_registrar == registrar_addr, ERROR_INVALID_KYC_REGISTRAR_PERMISSION);

        // remove valid investor status
        smart_table::remove(
            &mut identity_table.identities, 
            user
        );
        
        // emit event for identity removal
        event::emit(IdentityRemovedEvent {
            kyc_registrar: registrar_addr,
            user
        });
    
    }

    // -----------------------------------
    // Views
    // -----------------------------------

    #[view]
    public fun verify_kyc_transfer(
        sender: address, 
        receiver: address,
        send_amount: u64
    ) : bool acquires IdentityTable, TransactionPolicyTable {

        // get kyc controller signer address
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // get the Identity Table, and Transaction Policy Table resource
        let transaction_policy_table = borrow_global<TransactionPolicyTable>(kyc_controller_signer_addr);
        let identity_table           = borrow_global<IdentityTable>(kyc_controller_signer_addr);

        if (!smart_table::contains<address, Identity>(&identity_table.identities, sender)) {
            abort ERROR_SENDER_NOT_KYC
        };

        if (!smart_table::contains<address, Identity>(&identity_table.identities, receiver)) {
            abort ERROR_RECEIVER_NOT_KYC
        };

        // get the identity of sender and receiver 
        let sender_identity   = smart_table::borrow(&identity_table.identities, sender);
        let receiver_identity = smart_table::borrow(&identity_table.identities, receiver);

        // get transaction policy for sender
        let sender_country : u16         = sender_identity.country;
        let sender_investor_status : u8  = sender_identity.investor_status;

        // set sender transaction policy key
        let sender_transaction_policy_key = TransactionPolicyKey {
            country : sender_country,
            investor_status : sender_investor_status
        };
        let sender_transaction_policy = smart_table::borrow(&transaction_policy_table.policies, sender_transaction_policy_key);

        // get transaction policy for receiver
        let receiver_country : u16         = receiver_identity.country;
        let receiver_investor_status : u8  = receiver_identity.investor_status;

        // set receiver transaction policy key
        let receiver_transaction_policy_key = TransactionPolicyKey {
            country : receiver_country,
            investor_status : receiver_investor_status
        };
        let receiver_transaction_policy = smart_table::borrow(&transaction_policy_table.policies, receiver_transaction_policy_key);

        // verify transaction policies can send and receive
        assert!(sender_transaction_policy.can_send == true, ERROR_SENDER_TRANSACTION_POLICY_CANNOT_SEND);
        assert!(receiver_transaction_policy.can_receive == true, ERROR_RECEIVER_TRANSACTION_POLICY_CANNOT_RECEIVE);

        // verify countries not blacklisted 
        assert!(vector::contains(&sender_transaction_policy.blacklist_countries, &receiver_country) == false, ERROR_RECEIVER_COUNTRY_IS_BLACKLISTED);
        assert!(vector::contains(&receiver_transaction_policy.blacklist_countries, &sender_country) == false, ERROR_SENDER_COUNTRY_IS_BLACKLISTED);

        // verify max transaction amount is not reached for sender
        assert!(send_amount <= sender_transaction_policy.max_transaction_amount, ERROR_SEND_AMOUNT_GREATER_THAN_MAX_TRANSACTION_AMOUNT);

        return true
    }

    #[view]
    public fun verify_kyc_user(
        user: address,
        amount: Option<u64>
    ) : (bool, bool, bool) acquires IdentityTable, TransactionPolicyTable {

        // get kyc controller signer address
        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // get the Identity Table, and Transaction Policy Table resource
        let transaction_policy_table = borrow_global<TransactionPolicyTable>(kyc_controller_signer_addr);
        let identity_table = borrow_global<IdentityTable>(kyc_controller_signer_addr);

        if (!smart_table::contains<address, Identity>(&identity_table.identities, user)) {
            abort ERROR_USER_NOT_KYC
        };

        // get the identity of user if they are KYC-ed
        let user_identity   = smart_table::borrow(&identity_table.identities, user);

        // verify user is not frozen
        assert!(user_identity.is_frozen == false, ERROR_USER_IS_FROZEN);

        // get transaction policy for user
        let user_country : u16         = user_identity.country;
        let user_investor_status : u8  = user_identity.investor_status;

        // set user transaction policy key
        let user_transaction_policy_key = TransactionPolicyKey {
            country : user_country,
            investor_status : user_investor_status
        };
        let user_transaction_policy = smart_table::borrow(&transaction_policy_table.policies, user_transaction_policy_key);

        let can_send_bool     = user_transaction_policy.can_send;
        let can_receive_bool  = user_transaction_policy.can_receive;
        let valid_amount_bool : bool = false;

        if (option::is_some(&amount)) {
            let amount = option::extract(&mut amount); 
            if(amount <= user_transaction_policy.max_transaction_amount){
                valid_amount_bool = true;
            };
        };

        return (can_send_bool, can_receive_bool, valid_amount_bool)
    }

    
    #[view]
    /// Helper function to check if the given address is an active KYC registrar
    public fun is_kyc_registrar(kyc_registrar_addr: address) : bool acquires KycRegistrarTable {

        let kyc_controller_signer_addr = get_kyc_controller_signer_addr();

        // get the KycRegistrarTable resource
        let kyc_registrar_table = borrow_global<KycRegistrarTable>(kyc_controller_signer_addr);

        // verify if given address is a KYC Registrar
        let is_kyc_registrar : bool = smart_table::contains<address, KycRegistrar>(&kyc_registrar_table.kyc_registrars, kyc_registrar_addr);
        is_kyc_registrar 
    }

    // -----------------------------------
    // Helpers
    // -----------------------------------

    fun get_kyc_controller_signer_addr() : address {
        object::create_object_address(&@kyc_rwa_addr, APP_OBJECT_SEED)
    }

    // -----------------------------------
    // Unit Tests
    // -----------------------------------

    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use aptos_framework::account;

    #[test_only]
    public fun setup_test(
        aptos_framework : &signer, 
        kyc_controller : &signer,
        creator : &signer,
        kyc_registrar_one : &signer,
        kyc_registrar_two : &signer,
        kyc_user_one: &signer,
        kyc_user_two: &signer,
    ) : (address, address, address, address, address, address) {

        init_module(kyc_controller);

        timestamp::set_time_has_started_for_testing(aptos_framework);

        // Set an initial time for testing
        timestamp::update_global_time_for_test(1000000000);

        // get addresses
        let kyc_controller_addr       = signer::address_of(kyc_controller);
        let creator_addr              = signer::address_of(creator);
        let kyc_registrar_one_addr    = signer::address_of(kyc_registrar_one);
        let kyc_registrar_two_addr    = signer::address_of(kyc_registrar_two);
        let kyc_user_one_addr         = signer::address_of(kyc_user_one);
        let kyc_user_two_addr         = signer::address_of(kyc_user_two);

        // create accounts
        account::create_account_for_test(kyc_controller_addr);
        account::create_account_for_test(creator_addr);
        account::create_account_for_test(kyc_registrar_one_addr);
        account::create_account_for_test(kyc_registrar_two_addr);
        account::create_account_for_test(kyc_user_one_addr);
        account::create_account_for_test(kyc_user_two_addr);

        (kyc_controller_addr, creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, kyc_user_two_addr)
    }

    #[view]
    #[test_only]
    public fun test_IdentityRegisteredEvent(
        kyc_registrar: address,
        user: address,
        country: u16,
        investor_status: u8,
        is_frozen: bool
    ): IdentityRegisteredEvent {
        let event = IdentityRegisteredEvent{
            kyc_registrar,
            user,
            country,
            investor_status,
            is_frozen
        };
        return event
    }

    #[view]
    #[test_only]
    public fun test_IdentityUpdatedEvent(
        kyc_registrar: address,
        user: address,
        country: u16,
        investor_status: u8,
        is_frozen: bool
    ): IdentityUpdatedEvent {
        let event = IdentityUpdatedEvent{
            kyc_registrar,
            user,
            country,
            investor_status,
            is_frozen
        };
        return event
    }

    #[view]
    #[test_only]
    public fun test_IdentityRemovedEvent(
        kyc_registrar: address,
        user: address,
    ): IdentityRemovedEvent {
        let event = IdentityRemovedEvent{
            kyc_registrar,
            user
        };
        return event
    }

    #[view]
    #[test_only]
    public fun test_NewKycRegistrarEvent(
        registrar_address: address,
        name: String,
        description: String
    ): NewKycRegistrarEvent {
        let event = NewKycRegistrarEvent{
            registrar_address,
            name,
            description
        };
        return event
    }

    #[view]
    #[test_only]
    public fun test_KycRegistrarUpdatedEvent(
        registrar_address: address,
        name: String,
        description: String
    ): KycRegistrarUpdatedEvent {
        let event = KycRegistrarUpdatedEvent{
            registrar_address,
            name,
            description
        };
        return event
    }

    #[view]
    #[test_only]
    public fun test_KycRegistrarRemovedEvent(
        registrar_address: address,
    ): KycRegistrarRemovedEvent {
        let event = KycRegistrarRemovedEvent{
            registrar_address
        };
        return event
    }

    #[view]
    #[test_only]
    public fun test_ToggleKycRegistrarEvent(
        registrar_address: address,
        active: bool
    ): ToggleKycRegistrarEvent {
        let event = ToggleKycRegistrarEvent{
            registrar_address,
            active
        };
        return event
    }

    #[view]
    #[test_only]
    public fun test_NewTransactionPolicyEvent(
        country: u16,
        investor_status: u8, 
        can_send: bool,                  
        can_receive: bool,               
        max_transaction_amount: u64,   
        blacklist_countries: vector<u16>, 
    ): NewTransactionPolicyEvent {
        let event = NewTransactionPolicyEvent{
            country,
            investor_status,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries
        };
        return event
    }

    #[view]
    #[test_only]
    public fun test_TransactionPolicyRemovedEvent(
        country: u16,
        investor_status: u8
    ): TransactionPolicyRemovedEvent {
        let event = TransactionPolicyRemovedEvent{
            country,
            investor_status
        };
        return event
    }
}