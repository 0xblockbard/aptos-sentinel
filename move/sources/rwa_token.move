module kyc_rwa_addr::rwa_token {
    
    use kyc_rwa_addr::kyc_controller;

    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset, FungibleStore };
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::function_info;
    use std::signer;
    use std::event;
    use std::option::{Self};
    use std::string::{Self, utf8};

    // -----------------------------------
    // Seeds
    // -----------------------------------

    const ASSET_SYMBOL : vector<u8>   = b"KYCRWA";

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

    const ERROR_NOT_ADMIN: u64                                          = 1;
    const ERROR_TRANSFER_KYC_FAIL: u64                                  = 18;
    const ERROR_SEND_NOT_ALLOWED: u64                                   = 19;
    const ERROR_RECEIVE_NOT_ALLOWED: u64                                = 20;
    const ERROR_MAX_TRANSACTION_AMOUNT_EXCEEDED: u64                    = 21;

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
        object::create_object_address(&@kyc_rwa_addr, ASSET_SYMBOL)
    }

    #[view]
    public fun metadata(): Object<Metadata> {
        object::address_to_object(metadata_address())
    }

    #[view]
    public fun rwa_token_store(): Object<FungibleStore> {
        primary_fungible_store::ensure_primary_store_exists(@kyc_rwa_addr, metadata())
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

        // Verify KYC status for the store owner (with amount check)
        let (_, can_receive, valid_amount) = kyc_controller::verify_kyc_user(store_owner, option::some(amount));
        assert!(can_receive, ERROR_RECEIVE_NOT_ALLOWED);
        assert!(valid_amount, ERROR_MAX_TRANSACTION_AMOUNT_EXCEEDED);
        
        // Withdraw the remaining amount from the input store and return it.
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }


    /// Deposit function override for KYC check
    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &TransferRef,
    ) {

        let store_owner = object::owner(store);

        // Verify KYC status for the store owner (without amount check)
        let (can_send, _, _) = kyc_controller::verify_kyc_user(store_owner, option::none());
        assert!(can_send, ERROR_SEND_NOT_ALLOWED);

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
    public entry fun burn(admin: &signer, from: address, amount: u64) acquires Management, AdminInfo {

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

        // Verify KYC between sender and receiver
        let from_address = signer::address_of(from);
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
        object::create_object_address(&@kyc_rwa_addr, ASSET_SYMBOL)
    }

    // -----------------------------------
    // Unit Tests
    // -----------------------------------

    #[test_only]
    public fun setup_test(admin : &signer)  {
        init_module(admin)
    }


    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

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

        // test withdraw
        let management = borrow_global<Management>(metadata_address());
        let asset      = withdraw(user_store, 10, &management.transfer_ref);

        // burn asset to consume it
        fungible_asset::burn(&management.burn_ref, asset);

    }


    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

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

        kyc_controller::add_or_update_transaction_policy(
            kyc_rwa,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries
        );

        // test withdraw
        let management = borrow_global<Management>(metadata_address());
        let asset      = withdraw(user_store, 10, &management.transfer_ref);

        // burn asset to consume it
        fungible_asset::burn(&management.burn_ref, asset);

    }


    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

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

        kyc_controller::add_or_update_transaction_policy(
            kyc_rwa,
            country_id,
            investor_status_id,
            can_send,
            can_receive,
            max_transaction_amount,
            blacklist_countries
        );

        // test deposit
        let management = borrow_global<Management>(metadata_address());
        let assets     = fungible_asset::mint(&management.mint_ref, 1000);

        // Deposit tokens to user's store
        deposit(user_store, assets, &management.transfer_ref);

    }


    #[test(aptos_framework = @0x1, kyc_rwa=@kyc_rwa_addr, creator = @0x222, kyc_registrar_one = @0x333, kyc_registrar_two = @0x444, kyc_user_one = @0x555, kyc_user_two = @0x666)]
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

        // setup environment
        let (_kyc_controller_addr, _creator_addr, kyc_registrar_one_addr, kyc_registrar_two_addr, kyc_user_one_addr, _kyc_user_two_addr) = kyc_controller::setup_test(aptos_framework, kyc_rwa, creator, kyc_registrar_one, kyc_registrar_two, kyc_user_one, kyc_user_two);

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

        // test deposit
        let management = borrow_global<Management>(metadata_address());
        let assets     = fungible_asset::mint(&management.mint_ref, 1000);

        // Deposit tokens to user's store
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

    // Helper function: Add transaction policy
    #[test_only]
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


    #[test_only]
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

}
