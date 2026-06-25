// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PropertyRegistry
 * @author PropFlow
 * @notice Stores property metadata onchain for transparency and auditability.
 * @dev Each property entry links to its PropToken contract address,
 *      RERA registration number, and an IPFS/Arweave hash of supporting
 *      documents (title deed, valuation report, etc.).
 *
 *      Deployed last in the contract dependency chain:
 *      KYCRegistry → PropToken → RentDistributor → PropertyRegistry
 *
 * @custom:demo-property
 *      RERA Number: "RERA-DXB-2024-00142" (fictional)
 *      Location:    "Dubai Marina, UAE"
 *      Valuation:   200,000 USDC
 */
contract PropertyRegistry is Ownable {
    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    /**
     * @notice On-chain representation of a listed property.
     * @param reraNumber     UAE RERA registration number.
     * @param location       Human-readable location string.
     * @param valuationUSD   Property valuation in USDC (6-decimal units).
     * @param documentsHash  IPFS/Arweave hash of supporting documents.
     * @param propToken      Address of the associated PropToken contract.
     * @param active         Whether the property is currently active/listed.
     */
    struct Property {
        string reraNumber;
        string location;
        uint256 valuationUSD;
        string documentsHash;
        address propToken;
        bool active;
    }

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice Mapping from property ID to property metadata.
    mapping(uint256 => Property) public properties;

    /// @notice Auto-incrementing counter for property IDs.
    uint256 public propertyCount;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when a new property is listed.
    /// @param id         The property ID.
    /// @param reraNumber The RERA registration number.
    event PropertyListed(uint256 indexed id, string reraNumber);

    /// @notice Emitted when a property's active status is toggled.
    /// @param id     The property ID.
    /// @param active The new active status.
    event PropertyStatusUpdated(uint256 indexed id, bool active);

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    /**
     * @notice Deploys the PropertyRegistry and sets the deployer as owner.
     */
    constructor() Ownable(msg.sender) {}

    // ──────────────────────────────────────────────
    //  Owner-only mutations
    // ──────────────────────────────────────────────

    /**
     * @notice Register a new property onchain.
     * @param _reraNumber     UAE RERA registration number.
     * @param _location       Human-readable location string.
     * @param _valuationUSD   Property valuation in USDC (6-decimal units).
     * @param _documentsHash  IPFS/Arweave hash of supporting documents.
     * @param _propToken      Address of the associated PropToken contract.
     * @return id The assigned property ID.
     */
    function addProperty(
        string calldata _reraNumber,
        string calldata _location,
        uint256 _valuationUSD,
        string calldata _documentsHash,
        address _propToken
    ) external onlyOwner returns (uint256 id) {
        require(bytes(_reraNumber).length > 0, "PropertyRegistry: empty RERA");
        require(_propToken != address(0), "PropertyRegistry: zero PropToken");

        id = propertyCount;
        properties[id] = Property({
            reraNumber: _reraNumber,
            location: _location,
            valuationUSD: _valuationUSD,
            documentsHash: _documentsHash,
            propToken: _propToken,
            active: true
        });

        propertyCount++;

        emit PropertyListed(id, _reraNumber);
    }

    /**
     * @notice Toggle the active status of a property.
     * @param _id     The property ID to update.
     * @param _active The new active status.
     */
    function setPropertyActive(
        uint256 _id,
        bool _active
    ) external onlyOwner {
        require(_id < propertyCount, "PropertyRegistry: invalid ID");
        properties[_id].active = _active;
        emit PropertyStatusUpdated(_id, _active);
    }

    // ──────────────────────────────────────────────
    //  View functions
    // ──────────────────────────────────────────────

    /**
     * @notice Get full metadata for a property.
     * @param _id The property ID.
     * @return The Property struct.
     */
    function getProperty(
        uint256 _id
    ) external view returns (Property memory) {
        require(_id < propertyCount, "PropertyRegistry: invalid ID");
        return properties[_id];
    }
}
