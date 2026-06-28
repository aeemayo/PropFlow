# PropFlow

Fractional Real Estate Tokenization on the Arc Blockchain (Circle's L1).

PropFlow allows investors to purchase fractional ownership of yield-generating UAE properties on-chain using USDC, with rental income automatically distributed back to token holders in proportion to their stake.

---

## Directory Structure

*   **`contracts/`**: Core Solidity smart contracts representing KYC compliance, property tokens, and yield distribution mechanisms.
*   **`flutter_app/`**: Cross-platform Flutter mobile client featuring modern glassmorphism UI, wallet connection, and portfoilo management.
*   **`functions/`**: Node.js Firebase Cloud Functions managing proxy requests for Circle Programmable Wallets API and webhook triggers.

---

## Getting Started

### 1. Prerequisites
- Flutter SDK (v3.29+)
- Node.js (v18+)
- Firebase CLI (`npm install -g firebase-tools`)

### 2. Environment Setup
Create a `.env` file from the provided template inside the `functions` directory:
```bash
cp functions/.env.example functions/.env
```
Fill in the configuration keys:
- `CIRCLE_API_KEY`: Circle Developer Console API key.
- `ADMIN_PRIVATE_KEY`: Private key of the administrator/distributor account.

### 3. Deploy Smart Contracts
Deploy the contracts to the Arc Testnet using Remix IDE or your preferred Ethereum tooling in this order:
1. `KYCRegistry.sol`
2. `PropToken.sol`
3. `RentDistributor.sol`
4. `PropertyRegistry.sol`

Update [constants.dart](flutter_app/lib/utils/constants.dart) and `functions/.env` with your newly deployed contract addresses.

### 4. Run the Mobile App
Get Flutter dependencies and run the app:
```bash
cd flutter_app
flutter pub get
flutter run
```

### 5. Start Firebase Emulator (For Local Testing)
```bash
cd functions
npm install
firebase emulators:start
```
