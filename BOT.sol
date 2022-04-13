// SPDX-License-Identifier: MIT
// Developer: Anton Polenyaka. Linkedin: https://www.linkedin.com/in/antonpolenyaka/

pragma solidity 0.8.12;

import "./ERC20.sol";

contract BOT is ERC20 {

    // Attributies
    address private _owner;
    address private _contractAddress;

    // Constructors
    constructor() ERC20("BOT", "BOT") {
        // Init
        _owner = _msgSender();
        _contractAddress = address(this);
        // Total supply to owner
        uint256 initialSupply = 1000000 * 10 ** decimals();
        _mint(_owner, initialSupply);
    }
}