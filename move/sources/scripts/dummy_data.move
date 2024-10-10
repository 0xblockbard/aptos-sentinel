script {

    use std::signer;
    use std::option::{Self, Option};

    use kyc_rwa_addr::kyc_controller;
    // use kyc_rwa_addr::rwa_token;

    fun setup_dummy_data(creator: &signer) {

        // ------------------------------------
        // Set up KYC registrar
        // ------------------------------------
        let name            = std::string::utf8(b"KYC Registrar One");
        let description     = std::string::utf8(b"Kyc Registrar One Description");
        let image_url       = std::string::utf8(b"https://placehold.co/400x400");

        kyc_controller::add_or_update_kyc_registrar(
            creator,
            signer::address_of(creator),
            name,
            description,
            image_url
        );

        // ------------------------------------
        // Set up valid countries
        // ------------------------------------
        let counterU16 : Option<u16> = option::none();
        kyc_controller::add_or_update_valid_country(
            creator,
            std::string::utf8(b"usa"),
            counterU16
        );
        kyc_controller::add_or_update_valid_country(
            creator,
            std::string::utf8(b"thailand"),
            counterU16
        );
        kyc_controller::add_or_update_valid_country(
            creator,
            std::string::utf8(b"japan"),
            counterU16
        );
        kyc_controller::add_or_update_valid_country(
            creator,
            std::string::utf8(b"argentina"),
            counterU16
        );
        kyc_controller::add_or_update_valid_country(
            creator,
            std::string::utf8(b"france"),
            counterU16
        );
        kyc_controller::add_or_update_valid_country(
            creator,
            std::string::utf8(b"germany"),
            counterU16
        );
        kyc_controller::add_or_update_valid_country(
            creator,
            std::string::utf8(b"korea"),
            counterU16
        );
        
        // ------------------------------------
        // Set up valid investor status
        // ------------------------------------
        let counterU8 : Option<u8>   = option::none();
        kyc_controller::add_or_update_valid_investor_status(
            creator,
            std::string::utf8(b"standard"),
            counterU8
        );
        kyc_controller::add_or_update_valid_investor_status(
            creator,
            std::string::utf8(b"accredited"),
            counterU8
        );

        // ------------------------------------
        // setup standard transaction policies
        // ------------------------------------
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

        country_id              = 0; // usa
        investor_status_id      = 1; // accredited
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

        country_id              = 1; // thailand
        investor_status_id      = 0; // standard
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

        country_id              = 1; // thailand
        investor_status_id      = 1; // accredited
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

        country_id              = 2; // japan
        investor_status_id      = 0; // standard
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

        country_id              = 2; // japan
        investor_status_id      = 1; // accredited
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

        country_id              = 3; // argentina
        investor_status_id      = 0; // standard
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

        country_id              = 3; // argentina
        investor_status_id      = 1; // accredited
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

        country_id              = 4; // france
        investor_status_id      = 0; // standard
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

        country_id              = 4; // france
        investor_status_id      = 1; // accredited
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

        country_id              = 5; // germany
        investor_status_id      = 0; // standard
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

        country_id              = 5; // germany
        investor_status_id      = 1; // accredited
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

        country_id              = 6; // korea
        investor_status_id      = 0; // standard
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

        country_id              = 6; // korea
        investor_status_id      = 1; // accredited
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

        // ------------------------------------
        // Set up dummy KYC-ed users
        // ------------------------------------

        kyc_controller::add_or_update_user_identity(
            creator,
            signer::address_of(creator),
            0,      // country
            0,      // investor status
            false   // is_frozen
        );

        kyc_controller::add_or_update_user_identity(
            creator,
            @0x111,
            1,
            0,
            false
        );

        kyc_controller::add_or_update_user_identity(
            creator,
            @0x222,
            2,
            0,
            false
        );

        kyc_controller::add_or_update_user_identity(
            creator,
            @0x555,
            3,
            1,
            false
        );

        kyc_controller::add_or_update_user_identity(
            creator,
            @0x444,
            4,
            0,
            false
        );

        kyc_controller::add_or_update_user_identity(
            creator,
            @0x555,
            5,
            1,
            false
        );

        kyc_controller::add_or_update_user_identity(
            creator,
            @0x666,
            6,
            0,
            false
        );

    }
}
