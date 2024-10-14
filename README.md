# Sentinel 

***KYC-RWA Tokenisation Framework on Aptos Move***

The Sentinel KYC-RWA Tokenisation Framework brings a structured and composable approach to the tokenisation of Real-World Assets (RWAs) and regulatory Know-Your-Customer (KYC) compliance on Aptos using the Move language. 

As web3 blockchain technology becomes more widely adopted, it’s increasingly important to facilitate the integration of assets such as property and securities onto the blockchain in a way that adheres to regulatory requirements across different jurisdictions.

Inspired by the [Medici RWA Asset Framework](https://medici-docs.bridgesplit.com/) on Solana, Sentinel provides an unopinionated, flexible, and composable solution to represent tangible and intangible assets with property rights enforced by legal systems.

At its core, Sentinel comprises of a Dispatchable Fungible Asset and KYC Controller module. Any transaction that modifies the distribution of tokens (deposit, withdraw, mint, burn, transfer) will undergo a transaction approval check with the KYC Controller based on the user identity. 

These are facilitated by transaction policies which manage transfer permissions, setting rules on who can send or receive assets and imposing restrictions on transaction size, frequency, and country eligibility. These policies rely on a Transaction Policy Key, which reflects a user’s identity attributes (his country and investor status). 

The KYC Controller admin can configure and update these transaction policies and appoint KYC Registrars to verify users based on valid pre-approved countries and investor statuses. 

By maintaining this modular and adaptable structure, Sentinel can be applied to a broad range of tokenized real-world assets, offering a framework that aligns with regulatory needs while supporting blockchain integration on Aptos.

![Sentinel](https://res.cloudinary.com/blockbard/image/upload/c_scale,w_auto,q_auto,f_auto,fl_lossy/v1728919418/sentinel-home-screenshot_o875fm.png)

## Sentinel Process Flow

On initialisation, the KYC Controller admin can define a set of valid countries and investor statuses that KYC Registrars will use for user KYC verification. 

Each entry is assigned a unique ID— for instance, “US” may be mapped to 0, and “France” to 1. Similarly, investor statuses like “standard” and “accredited” may correspond to 0 and 1, respectively. KYC Registrars can only use these predefined IDs when verifying users, ensuring compliance with valid criteria. 

The admin can then appoint KYC Registrars, specifying the registrar’s account address, name, description, and image. If necessary, the admin can pause or remove a KYC Registrar from the module. 

KYC Registrars will then be able to verify a user’s identity and set his country and investor status. Each user is limited to management by a single Registrar to prevent conflicts. 

The KYC Controller admin also sets transaction policies, which consists of the following properties:

- **Blacklist Countries**: Transactions are blocked if either the sender or receiver's country is blacklisted by the other party.

- **Can Send**: Controls whether users under this policy can initiate transactions.

- **Can Receive**: Controls whether users can receive transactions.

- **Max Transaction Amount**: Defines the maximum amount allowed per transaction.

- **Apply Transaction Count Velocity**: Enforces a cap on the number of transactions from a single address within a specific timeframe. It includes:
  - **Transaction Count Velocity Timeframe**: Duration (in seconds) for which the transaction count limit applies.
  - **Transaction Count Velocity Max**: The maximum allowable transactions within the timeframe.

- **Apply Transaction Amount Velocity**: Enforces a cap on the total transaction amount from a single address within a specific timeframe. It includes:
  - **Transaction Amount Velocity Timeframe**: Duration (in seconds) for which the amount limit applies.
  - **Transaction Amount Velocity Max**: The maximum transaction amount within this timeframe.


When transactions or balance modifications occur, these checks are enforced based on the user’s identity and relevant transaction policies. 

Successful transactions must pass all applicable checks, ensuring regulatory compliance and security.


## Demo MVP

The Sentinel demo is accessible at [https://SentinelMove.com](https://sentinelMove.com). 

**Features**:
- **Wallet Integration**: Users can connect their Aptos wallets to interact with the platform on the Aptos Testnet.


The frontend demo for Sentinel is maintained in a separate repository to ensure that the Move contracts remain focused and well-organised.

It can be found here: [Sentinel Frontend Github](https://github.com)

![Sentinel Bento Grid](https://res.cloudinary.com/blockbard/image/upload/c_scale,w_auto,q_auto,f_auto,fl_lossy/v1728919478/sentinel-bento-grid_ecgins.png)

## Tech Overview and Considerations

We follow the Aptos Object Model approach to decentralise data storage, enhance scalability, and optimise gas costs. 

From a practical perspective, we aim for a streamlined KYC process where KYC Registrars can verify users in one step. However, moving a user Identity object directly to them would require the user to sign a transaction, as objects can only be transferred to signers. This would create a two-step process, which is more cumbersome. This also applies when the KYC Controller admin adds a new KYC Registrar. 

Our initial approach was to store user identities and KYC Registrars in smart tables within the KYC Controller module, simplifying the setup and ensuring an efficient one-step process. However, while this may be adequate for small to medium-sized projects, it has potential scalability limitations that could challenge larger applications with a substantial user base. 

Alternatively, the second approach would be to implement a two-step process where KYC Registrars verify users, and users subsequently sign and claim their verification. However, as noted, this method is not desirable as it introduces friction to a smooth user experience.  

Consequently, we chose to adopt a Programmatically Derived Address (PDA) approach, where we create a named object using the KYC Controller signer and the hash of the user address as the object seed. 

This approach then allows us to reverse-engineer the location of the user’s Identity object for data retrieval, while ensuring scalability and storage efficiency on the KYC Controller module regardless of the number of verified users.

In this way, we are able to follow the Aptos Object Model approach while still keeping a seamless verification process with little to no user friction.

## Smart Contract Entrypoints

The Sentinel KYC Controller module includes nine admin entrypoints, 2 registrar entrypoints, and 2 friend entrypoints:

### Admin Entrypoints

1. **add_or_update_kyc_registrar**: Allows the KYC Controller admin to add or update a KYC Registrar.
   - **Input**: KYC Registrar information (name, description, image)
   - **Output**: Adds or updates a KYC Registrar with the given information

2. **remove_kyc_registrar**: Allows the KYC Controller admin to remove a KYC Registrar.
   - **Input**: KYC Registrar address
   - **Output**: Removes a KYC Registrar

3. **toggle_kyc_registrar**: Allows the KYC Controller admin to pause or unpause a KYC Registrar.
   - **Input**: KYC Registrar address and toggle boolean
   - **Output**: Pauses or unpauses the given KYC Registrar

4. **add_or_update_valid_country**: Allows the KYC Controller admin to add or update a valid country.
   - **Input**: Country name, and optional valid country ID for updates
   - **Output**: Adds or updates a valid country

5. **remove_valid_country**: Allows the KYC Controller admin to remove a valid country.
   - **Input**: Country ID
   - **Output**: Removes the corresponding country

6. **add_or_update_valid_investor_status**: Allows the KYC Controller admin to add or update a valid investor status.
   - **Input**: Investor Status name, and optional valid status ID for updates
   - **Output**: Adds or updates a valid investor status

7. **remove_valid_investor_status**: Allows the KYC Controller admin to remove a valid investor status.
   - **Input**: Investor Status ID
   - **Output**: Removes the corresponding investor status

8. **add_or_update_transaction_policy**: Allows the KYC Controller admin to add or update a transaction policy.
   - **Input**: Country ID, Investor Status ID, and Transaction policy fields
   - **Output**: Adds or updates a transaction policy

9. **remove_transaction_policy**: Allows the KYC Controller admin to remove a transaction policy.
   - **Input**: Country ID and Investor Status ID
   - **Output**: Removes the corresponding transaction policy

### KYC Registrar Entrypoints

1. **add_or_update_user_identity**: Allows a KYC Registrar to add or update a user identity. Registrars can only update users that they have verified.
   - **Input**: User address, valid country ID, valid Investor Status ID, and is_frozen boolean
   - **Output**: Adds or updates a user identity

2. **remove_user_identity**: Allows a KYC Registrar to remove a user identity.
   - **Input**: User address
   - **Output**: Removes the corresponding User Identity

### Friend Entrypoints (to be called from the RWA Token)

1. **update_user_identity_transaction_count_velocity**: Can only be called by friend modules to update the user identity transaction count velocity.
   - **Input**: User address, timestamp, and cumulative count
   - **Output**: Adds or updates a user identity’s transaction_count_velocity_timestamp and cumulative_transaction_count

2. **update_user_identity_transaction_amount_velocity**: Can only be called by friend modules to update the user identity transaction amount velocity.
   - **Input**: User address, timestamp, and cumulative amount
   - **Output**: Adds or updates a user identity’s transaction_amount_velocity_timestamp and cumulative_transaction_amount

## Code Coverage

Sentinel has comprehensive test coverage, with 100% of the codebase thoroughly tested. This includes a full range of scenarios that ensure the platform's reliability and robustness.

The following section provides a breakdown of the tests that validate each function and feature, affirming that Sentinel performs as expected under all intended use cases.

![Code Coverage](https://res.cloudinary.com/blockbard/image/upload/c_scale,w_auto,q_auto,f_auto,fl_lossy/v1728919816/sentinel-coverage-combined_f3s0tm.png)

## Dummy Data Script

We have also included a dummy data script to populate the Sentinel Demo MVP with sample transaction policies. This helps to illustrate how the KYC verification process works. 

To run the dummy data script after deploying a local instance of our frontend and Sentinel package, follow these steps:

```
# compile the dummy data script and get the script path location
aptos move compile-script

# copy the script path location and paste it at the end (replace path_to_script.mv)
aptos move run-script --compiled-script-path /path_to_script.mv
```

## Future Plans

Looking ahead, here are some plans to expand the features and capabilities of Sentinel in Phase 2. 

### Planned Features:

- **Enhanced Identity and Transaction Policy**: Currently, the system relies on two fixed identity properties—country and investor_status— most commonly used for KYC verification, which together forms a Transaction Policy Key. Looking forward, we plan to implement a flexible Transaction Policy Key that can accommodate additional properties as needed, allowing for more tailored and versatile transaction policies.

- **Expanded Access Control Layer**: In the current MVP, access control is simplified, with a single admin for the KYC Controller and one signer for the KYC Registrar. In the future, we plan to extend this by enabling whitelisting and more granular permission settings. This upgrade would allow for scenarios like multiple addresses associated with a KYC Registrar, each with specific permission levels, to better align with real-world access control requirements.

- **Sentinel KYC-RWA Launchpad**: Empower entrepreneurs to swiftly launch RWA tokens tailored to their business needs, with the option to integrate into an existing KYC ecosystem and network. This streamlined approach significantly lowers technological barriers and costs, enabling entrepreneurs to focus on business growth and user acquisition.

### Long-Term Vision:

- **Greater Support for Institutional Integration on Aptos**: By providing tools aligned with institutional compliance needs, Sentinel could facilitate Aptos’s appeal to traditional financial institutions. This would allow banks, asset managers, and other institutions to explore asset tokenisation on Aptos with greater confidence, knowing that compliance tools are readily available.

- **Greater Adoption of RWA on Aptos**: By providing a compliance framework tailored for real-world asset tokenisation, Sentinel could help increase the adoption of RWAs on Aptos. Projects would benefit from a standardised streamlined approach to managing regulatory requirements, making it easier for asset-backed tokens like real estate, commodities, or securities to be issued and traded on Aptos. 

- **Enhanced Decentralized Identity Solutions on Aptos**: Sentinel could expand Aptos’s capabilities by offering flexible identity management that goes beyond traditional KYC. By incorporating various identity attributes and compliance checks, Sentinel could make Aptos a strong option for dApps requiring robust identity verification, such as financial services or digital identity solutions. 

## Conclusion

Sentinel introduces a standardised KYC-RWA Tokenisation Framework to Aptos with the Move language, enabling projects to navigate regulatory requirements with ease. 

By providing customisable and flexible compliance tools tailored to institutional needs and supporting the tokenisation of real-world assets, Sentinel makes Aptos a more attractive platform for both traditional finance and decentralised applications seeking to bring real-world assets onto the blockchain

As Sentinel evolves, we aim to provide a robust foundation for compliant asset tokenisation, paving the way for greater adoption and integration of real-world assets on Aptos.

## Credits and Support

Thanks for reading till the end!

Sentinel is designed and built by 0xBlockBard, a solo indie maker passionate about building innovative products in the web3 space. 

With over 10 years of experience, my work spans full-stack and smart contract development, with the Laravel Framework as my go-to for web projects. I’m also familiar with Solidity, Rust, LIGO, and most recently, Aptos Move.

Beyond coding, I occasionally write and share insights on crypto market trends and interesting projects to watch. If you are interested to follow along my web3 journey, you can subscribe to my [Substack](https://www.0xblockbard.com/) here :)

Twitter / X: [0xBlockBard](https://x.com/0xblockbard)

Substack: [0xBlockBard Research](https://www.0xblockbard.com/)