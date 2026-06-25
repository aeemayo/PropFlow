// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @author PropFlow
 * @notice A minimal ERC-20 mock of USDC for local testing and Remix IDE.
 * @dev Uses 6 decimals to match Arc's USDC ERC-20 interface.
 *      On Arc Testnet, replace this address with:
 *      0x3600000000000000000000000000000000000000
 *
 *      Anyone can call `mint()` to get test tokens — this is intentional
 *      for hackathon / demo purposes only.
 */
contract MockUSDC is ERC20 {
    uint8 private constant _DECIMALS = 6;

    /**
     * @notice Deploy MockUSDC and mint an initial supply to the deployer.
     */
    constructor() ERC20("USD Coin", "USDC") {
        // Mint 10,000,000 USDC to deployer for testing
        _mint(msg.sender, 10_000_000 * 10 ** _DECIMALS);
    }

    /**
     * @notice Returns the number of decimals (6, matching real USDC).
     */
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }

    /**
     * @notice Mint test USDC to any address. Public for testing convenience.
     * @param to   The recipient address.
     * @param amount The amount to mint (in 6-decimal units).
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
