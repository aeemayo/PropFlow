// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./KYCRegistry.sol";

/**
 * @title PropToken
 * @author PropFlow
 * @notice ERC-20 token representing fractional ownership of a real-estate property.
 * @dev Core compliance mechanism: every transfer (except minting during purchase)
 *      checks both sender and recipient against the KYCRegistry. If either party
 *      is unverified, the transaction reverts with "KYC required".
 *
 *      Investors call `purchase(amount)` to buy shares. The function:
 *      1. Transfers (amount × pricePerToken) USDC from the buyer to this contract
 *      2. Mints `amount` PropTokens to the buyer
 *      3. Tracks the buyer in a `holders` array for rent distribution
 *
 *      Deploy after KYCRegistry:
 *      KYCRegistry → PropToken → RentDistributor → PropertyRegistry
 *
 * @custom:demo-property
 *      Name: "Marina Studio — Dubai"
 *      Total shares: 100,000 PropToken
 *      Price per share: 2 USDC
 *      Valuation: 200,000 USDC
 */
contract PropToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice KYC registry used to gate transfers.
    KYCRegistry public kycRegistry;

    /// @notice The USDC token contract (6 decimals on Arc).
    IERC20 public usdcToken;

    /// @notice Price of one PropToken in USDC (6-decimal units).
    uint256 public pricePerToken;

    /// @notice Maximum number of tokens that can ever exist.
    uint256 public totalShares;

    /// @notice Total USDC raised through share purchases.
    uint256 public raised;

    /// @notice Ordered list of unique holder addresses (for rent distribution).
    address[] private _holders;

    /// @notice Quick lookup to avoid duplicate entries in `_holders`.
    mapping(address => bool) public isHolder;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when an investor purchases shares.
    /// @param buyer   The address that purchased.
    /// @param amount  Number of PropTokens purchased.
    /// @param cost    Total USDC paid (6-decimal units).
    event SharesPurchased(
        address indexed buyer,
        uint256 amount,
        uint256 cost
    );

    /// @notice Emitted when the KYC registry address is updated.
    /// @param newRegistry The new KYCRegistry address.
    event KYCRegistryUpdated(address indexed newRegistry);

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    /**
     * @notice Deploy the PropToken for a specific property.
     * @param _name          Token name (e.g. "PropFlow Marina Studio").
     * @param _symbol        Token symbol (e.g. "PFMS").
     * @param _totalShares   Maximum token supply (e.g. 100000 * 1e18).
     * @param _kycRegistry   Address of the deployed KYCRegistry.
     * @param _usdcToken     Address of the USDC ERC-20 contract.
     * @param _pricePerToken Price of one token in USDC 6-decimal units (e.g. 2e6 = 2 USDC).
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalShares,
        address _kycRegistry,
        address _usdcToken,
        uint256 _pricePerToken
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        require(_kycRegistry != address(0), "PropToken: zero KYC registry");
        require(_usdcToken != address(0), "PropToken: zero USDC address");
        require(_pricePerToken > 0, "PropToken: zero price");
        require(_totalShares > 0, "PropToken: zero total shares");

        kycRegistry = KYCRegistry(_kycRegistry);
        usdcToken = IERC20(_usdcToken);
        pricePerToken = _pricePerToken;
        totalShares = _totalShares;
    }

    // ──────────────────────────────────────────────
    //  Purchase flow
    // ──────────────────────────────────────────────

    /**
     * @notice Purchase fractional property shares with USDC.
     * @dev Caller must first `approve` this contract on the USDC token for
     *      at least `amount * pricePerToken` before calling.
     *
     *      The buyer must be KYC-verified in the registry.
     *
     * @param amount Number of PropTokens to purchase (in 18-decimal token units).
     */
    function purchase(uint256 amount) external {
        require(amount > 0, "PropToken: zero amount");
        require(
            totalSupply() + amount <= totalShares,
            "PropToken: exceeds total shares"
        );
        require(
            kycRegistry.isVerified(msg.sender),
            "KYC required"
        );

        // Calculate USDC cost.
        // amount is in 18-decimal token units, pricePerToken is in 6-decimal USDC units.
        // cost = (amount / 1e18) * pricePerToken
        // To avoid precision loss: cost = amount * pricePerToken / 1e18
        uint256 cost = (amount * pricePerToken) / 1e18;
        require(cost > 0, "PropToken: cost rounds to zero");

        // Pull USDC from buyer
        usdcToken.safeTransferFrom(msg.sender, address(this), cost);

        // Track holder for rent distribution (first purchase only)
        if (!isHolder[msg.sender]) {
            isHolder[msg.sender] = true;
            _holders.push(msg.sender);
        }

        // Mint PropTokens to buyer
        _mint(msg.sender, amount);

        // Accumulate total raised
        raised += cost;

        emit SharesPurchased(msg.sender, amount, cost);
    }

    /**
     * @notice Purchase shares on behalf of a recipient (platform/admin only).
     * @dev Called by the platform Cloud Function to purchase tokens without requiring
     *      the recipient to sign the transaction directly. The platform wallet pays
     *      the USDC cost; tokens are minted to `recipient`.
     *
     *      The recipient must be KYC-verified. The caller (platform wallet) must
     *      have approved this contract to spend the USDC cost.
     *
     * @param recipient  The investor's Arc wallet address.
     * @param amount     Number of PropTokens in 18-decimal units.
     */
    function purchaseFor(address recipient, uint256 amount) external onlyOwner {
        require(amount > 0, "PropToken: zero amount");
        require(
            totalSupply() + amount <= totalShares,
            "PropToken: exceeds total shares"
        );
        require(
            kycRegistry.isVerified(recipient),
            "KYC required"
        );

        uint256 cost = (amount * pricePerToken) / 1e18;
        require(cost > 0, "PropToken: cost rounds to zero");

        usdcToken.safeTransferFrom(msg.sender, address(this), cost);

        if (!isHolder[recipient]) {
            isHolder[recipient] = true;
            _holders.push(recipient);
        }

        _mint(recipient, amount);
        raised += cost;

        emit SharesPurchased(recipient, amount, cost);
    }

    // ──────────────────────────────────────────────
    //  Transfer guard — KYC compliance
    // ──────────────────────────────────────────────

    /**
     * @dev Override the internal _update hook to enforce KYC on all transfers.
     *      Minting (from == address(0)) and burning (to == address(0)) are
     *      exempt from the KYC check to allow the purchase flow to work.
     *
     *      This is the core compliance story for Track 3 judging:
     *      - Verified → Verified: ✅ allowed
     *      - Unverified → Anyone:  ❌ reverts "KYC required"
     *      - Anyone → Unverified:  ❌ reverts "KYC required"
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Skip KYC check for minting and burning
        if (from != address(0) && to != address(0)) {
            require(kycRegistry.isVerified(from), "KYC required");
            require(kycRegistry.isVerified(to), "KYC required");
        }

        super._update(from, to, amount);

        // Track new holder on transfer receipt (secondary market)
        if (to != address(0) && !isHolder[to] && balanceOf(to) > 0) {
            isHolder[to] = true;
            _holders.push(to);
        }
    }

    // ──────────────────────────────────────────────
    //  Owner admin
    // ──────────────────────────────────────────────

    /**
     * @notice Update the KYC registry address.
     * @dev Allows migration to a new registry if needed.
     * @param _newRegistry The new KYCRegistry contract address.
     */
    function setKYCRegistry(address _newRegistry) external onlyOwner {
        require(_newRegistry != address(0), "PropToken: zero address");
        kycRegistry = KYCRegistry(_newRegistry);
        emit KYCRegistryUpdated(_newRegistry);
    }

    // ──────────────────────────────────────────────
    //  View functions
    // ──────────────────────────────────────────────

    /**
     * @notice Returns the list of all addresses that hold or have held tokens.
     * @dev Used by RentDistributor to iterate holders for proportional payouts.
     * @return Array of holder addresses.
     */
    function getHolders() external view returns (address[] memory) {
        return _holders;
    }

    /**
     * @notice Returns the number of unique holders.
     * @return Count of holder addresses.
     */
    function holderCount() external view returns (uint256) {
        return _holders.length;
    }

    /**
     * @notice Returns the number of shares still available for purchase.
     * @return Remaining shares in 18-decimal units.
     */
    function sharesAvailable() external view returns (uint256) {
        return totalShares - totalSupply();
    }
}
