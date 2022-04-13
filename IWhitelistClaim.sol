/*************************************************************************************
 * 
 * Autor & Owner: BotPlenet
 *
 * 446576656c6f7065723a20416e746f6e20506f6c656e79616b61 *****************************/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

interface IWhitelistClaim {

    struct WhitelistedData {
        address account;
        uint256 totalPeriods;
        uint256 lastClaimedPeriod;
        uint256 periodAmount;
        uint256 lastClaimTimestamp;
        uint256 nextClaimTimestamp;
        uint256 totalAmountToClaim;
        uint256 pendingAmountToClaim;
    }

    // Events

    event UsersAdded(uint256 numAccountsAdded, address indexed firstAccount, address indexed lastAccount);
    event Claimed(address indexed account, uint256 amount, uint256 claimedPeriod);
    event OwnerChanged(address oldOwner, address newOwner);
    event StateChanged(bool isPausedContract);

    // Methods: Balance

    function BalanceGetTokens() external view returns(uint256);

    // Methods: General

    // Interrumpt any functions in the contract
    function Pause() external;
    // Allow paused functions in the contract
    function Unpause() external;
    // Check state of contract if is paused or not
    function IsPaused() external view returns(bool);
    // Return current blockchain time
    function GetCurrentTime() external view returns(uint256);

    // Methods: Owner

    function OwnerSet(address newOwner) external;
    function OwnerGet() external returns(address);

    // Methods: User

    function UsersAdd(address[] memory accounts_, uint256[] memory totalAmountsToClaim_) external;
    function UserGetInfo(address account) external view returns(WhitelistedData memory);
    function UserVerify(address account) external view returns(bool);

    // Methods: Claim

    function Claim() external;
    function GetTimeForNextClaim() external view returns(uint256 time);
}