// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./PropToken.sol";

/**
 * @title RentDistributor
 * @author PropFlow
 * @notice Accepts USDC rent deposits and distributes them proportionally to
 *         all PropToken holders.
 * @dev Any address (property manager, Circle Gateway webhook, admin) can
 *      deposit rent via `depositRent()`. The owner (or an automated keeper)
 *      then calls `distributeRent()` to push USDC to each holder in proportion
 *      to their token balance.
 *
 *      Proportional calculation:
 *        holderShare = (holderBalance / totalSupply) * rentPool
 *
 *      For the hackathon MVP, the holders array is maintained in PropToken and
 *      iterated here. This is O(n) and acceptable for demo-scale holder counts.
 *
 *      Deploy after PropToken:
 *      KYCRegistry → PropToken → RentDistributor → PropertyRegistry
 *
 * @custom:demo-property
 *      Monthly rent: 1,200 USDC → 0.012 USDC per token per month
 */
contract RentDistributor is Ownable {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice The PropToken contract whose holders receive rent.
    PropToken public propToken;

    /// @notice The USDC ERC-20 contract (6 decimals on Arc).
    IERC20 public usdcToken;

    /// @notice Undistributed USDC available for next distribution.
    uint256 public rentPool;

    /// @notice Running total of all USDC ever distributed.
    uint256 public totalDistributed;

    /// @notice Timestamp of the last successful distribution.
    uint256 public lastDistribution;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when rent USDC is deposited into the pool.
    /// @param depositor Address that deposited.
    /// @param amount    USDC amount deposited (6-decimal units).
    event RentDeposited(address indexed depositor, uint256 amount);

    /// @notice Emitted after a successful rent distribution round.
    /// @param totalAmount Total USDC distributed in this round.
    /// @param timestamp   Block timestamp of the distribution.
    event RentDistributed(uint256 totalAmount, uint256 timestamp);

    /// @notice Emitted for each individual holder payout (useful for indexing).
    /// @param holder Address that received rent.
    /// @param amount USDC amount received (6-decimal units).
    event RentPaid(address indexed holder, uint256 amount);

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    /**
     * @notice Deploy the RentDistributor.
     * @param _propToken Address of the PropToken contract.
     * @param _usdcToken Address of the USDC ERC-20 contract.
     */
    constructor(
        address _propToken,
        address _usdcToken
    ) Ownable(msg.sender) {
        require(_propToken != address(0), "RentDistributor: zero PropToken");
        require(_usdcToken != address(0), "RentDistributor: zero USDC");

        propToken = PropToken(_propToken);
        usdcToken = IERC20(_usdcToken);
    }

    // ──────────────────────────────────────────────
    //  Deposit
    // ──────────────────────────────────────────────

    /**
     * @notice Deposit USDC rent into the distribution pool.
     * @dev Callable by anyone (property manager, Gateway webhook, admin).
     *      Caller must approve this contract on USDC first.
     * @param amount USDC amount to deposit (6-decimal units).
     */
    function depositRent(uint256 amount) external {
        require(amount > 0, "RentDistributor: zero deposit");

        usdcToken.safeTransferFrom(msg.sender, address(this), amount);
        rentPool += amount;

        emit RentDeposited(msg.sender, amount);
    }

    // ──────────────────────────────────────────────
    //  Distribution
    // ──────────────────────────────────────────────

    /**
     * @notice Distribute accumulated rent to all PropToken holders.
     * @dev Iterates the holders array from PropToken and sends each holder
     *      their proportional share: (balance / totalSupply) * rentPool.
     *
     *      Only callable by the contract owner (or future keeper integration).
     *
     *      Gas note: O(n) over holders — fine for MVP demo scale.
     *      Production would use a Merkle-drop or pull-based pattern.
     */
    function distributeRent() external onlyOwner {
        require(rentPool > 0, "RentDistributor: no rent to distribute");

        uint256 supply = propToken.totalSupply();
        require(supply > 0, "RentDistributor: no tokens minted");

        address[] memory holders = propToken.getHolders();
        uint256 distributed = 0;
        uint256 poolSnapshot = rentPool;

        for (uint256 i = 0; i < holders.length; i++) {
            uint256 balance = propToken.balanceOf(holders[i]);
            if (balance == 0) continue;

            // Proportional share: (balance * poolSnapshot) / supply
            uint256 share = (balance * poolSnapshot) / supply;
            if (share == 0) continue;

            usdcToken.safeTransfer(holders[i], share);
            distributed += share;

            emit RentPaid(holders[i], share);
        }

        // Update state
        rentPool -= distributed;
        totalDistributed += distributed;
        lastDistribution = block.timestamp;

        emit RentDistributed(distributed, block.timestamp);
    }

    // ──────────────────────────────────────────────
    //  View helpers
    // ──────────────────────────────────────────────

    /**
     * @notice Returns the pending rent available for distribution.
     * @return USDC amount in the pool (6-decimal units).
     */
    function pendingRent() external view returns (uint256) {
        return rentPool;
    }
}
