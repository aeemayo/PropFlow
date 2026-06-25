// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KYCRegistry
 * @author PropFlow
 * @notice Owner-controlled whitelist of KYC-verified investor addresses.
 * @dev Every PropToken transfer checks this registry. Only verified addresses
 *      may send or receive property tokens, enforcing UAE/RERA compliance
 *      requirements for fractional real-estate ownership.
 *
 *      Deployed first in the contract dependency chain:
 *      KYCRegistry → PropToken → RentDistributor → PropertyRegistry
 */
contract KYCRegistry is Ownable {
    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice Whether a given address has passed KYC verification.
    mapping(address => bool) public verified;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when an investor address is approved.
    /// @param investor The address that was approved.
    event Approved(address indexed investor);

    /// @notice Emitted when an investor address is revoked.
    /// @param investor The address that was revoked.
    event Revoked(address indexed investor);

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    /**
     * @notice Deploys the KYC registry and sets the deployer as owner.
     */
    constructor() Ownable(msg.sender) {}

    // ──────────────────────────────────────────────
    //  Owner-only mutations
    // ──────────────────────────────────────────────

    /**
     * @notice Mark an investor address as KYC-verified.
     * @dev Idempotent — calling approve on an already-verified address is a no-op
     *      (event still emits for indexer consistency).
     * @param investor The address to approve.
     */
    function approve(address investor) external onlyOwner {
        require(investor != address(0), "KYCRegistry: zero address");
        verified[investor] = true;
        emit Approved(investor);
    }

    /**
     * @notice Revoke KYC status from an investor address.
     * @dev After revocation the address can no longer send or receive PropTokens.
     * @param investor The address to revoke.
     */
    function revoke(address investor) external onlyOwner {
        require(investor != address(0), "KYCRegistry: zero address");
        verified[investor] = false;
        emit Revoked(investor);
    }

    // ──────────────────────────────────────────────
    //  View helpers
    // ──────────────────────────────────────────────

    /**
     * @notice Check whether an address is KYC-verified.
     * @param investor The address to check.
     * @return True if the address is verified.
     */
    function isVerified(address investor) external view returns (bool) {
        return verified[investor];
    }
}
