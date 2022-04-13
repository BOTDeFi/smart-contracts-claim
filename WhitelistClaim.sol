/*************************************************************************************
 * 
 * Autor & Owner: BotPlenet
 *
 * 446576656c6f7065723a20416e746f6e20506f6c656e79616b61 *****************************/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "./ERC20.sol";
import "./IWhitelistClaim.sol";

abstract contract WhitelistClaim is IWhitelistClaim, Context {

    // Attributies

    ERC20 private _token;
    address private _owner;
    address private _contractAddress;
    bool private _isPaused;
    uint256 private _minTimeBetweenClaim;
    uint256 private _defaultTotalPeriods;
    uint256 private _firstDateToClaim;

    WhitelistedData[] private _whitelistedData;
    mapping(address => WhitelistedData) private _addressToData;
    mapping(address => bool) private _whitelistedAddresses;
    mapping(address => bool) private _exist;

    // Constructor

    constructor(address tokenContractAddress_, address owner_, uint256 minTimeBetweenClaim_,
        uint256 defaultTotalPeriods_, uint256 firstDateToClaim_) {
        _token = ERC20(tokenContractAddress_);
        _contractAddress = address(this);
        _minTimeBetweenClaim = minTimeBetweenClaim_;
        _owner = owner_;
        _defaultTotalPeriods = defaultTotalPeriods_;
        _firstDateToClaim = firstDateToClaim_;
        emit OwnerChanged(address(0), _owner);
    }

    // Modifiers

    modifier onlyOwner() {
        require(_owner == _msgSender(), "ERROR: Caller is not the owner");
        _;
    }

    modifier isWhitelisted() {
        require(_whitelistedAddresses[_msgSender()], "ERROR: You need to be whitelisted");
        _;
    }

    modifier notPaused() {
        require(!_isPaused, "ERROR: Contract state is paused!");
        _;
    }

    // Methods: General
    function Pause() external override onlyOwner {
        _isPaused = true;
        emit StateChanged(_isPaused);
    }

    function Unpause() external override onlyOwner {
        _isPaused = false;
        emit StateChanged(_isPaused);
    }

    function IsPaused() external view returns(bool) {
        return _isPaused;
    }

    // Methods: Balance

    function _contractBalanceBOT() internal view returns(uint256 balance) {
        return _token.balanceOf(_contractAddress);
    }

    function BalanceGetTokens() external view notPaused returns(uint256) {
        return _contractBalanceBOT();
    }

    // Methods: Owner

    function OwnerSet(address newOwner) external onlyOwner {
        // Check
        require(newOwner != address(0), "ERROR: Address of owner need to be different 0");
        // Work
        _owner = newOwner;
        // Event
        emit OwnerChanged(msg.sender, newOwner);
    }

    function OwnerGet() external view notPaused returns(address) {
        return _owner;
    }

    // Methods: User

    function _userAddDataBase(address account_, uint256 periodAmount_, uint256 totalAmountToClaim_) internal {
        require(_exist[account_] == false, "ERROR: This account is already added to claim/white list");
        WhitelistedData memory data = WhitelistedData({
            account: account_,
            totalPeriods: totalAmountToClaim_ / periodAmount_,
            lastClaimedPeriod: 0,
            periodAmount: periodAmount_,
            lastClaimTimestamp: _firstDateToClaim - _minTimeClaim(),
            nextClaimTimestamp: _firstDateToClaim,
            totalAmountToClaim: totalAmountToClaim_,
            pendingAmountToClaim: totalAmountToClaim_
        });
        _whitelistedData.push(data);
        _addressToData[account_] = data;
        _whitelistedAddresses[account_] = true;
        _exist[account_] = true;
    }

    function UsersAdd(address[] memory accounts_, uint256[] memory totalAmountsToClaim_) external override onlyOwner {
        // Check data
        require(accounts_.length > 0, "ERROR: Number of accounts need to be greater of zero!");
        require(accounts_.length == totalAmountsToClaim_.length, "ERROR: Number of accounts and amounts need to be equal!");
        for(uint256 i = 0; i < accounts_.length; i++) {
            require(accounts_[i] != address(0), "ERROR: Account address need to be different 0");
            require(totalAmountsToClaim_[i] > 0, "ERROR: Total amount to claim need to be greater 0 and greater or equal period amount!");
            // Work
            uint256 periodAmount = totalAmountsToClaim_[i] / _defaultTotalPeriods;
            _userAddDataBase(accounts_[i], periodAmount, totalAmountsToClaim_[i]);
        }
        // Event
        emit UsersAdded(accounts_.length, accounts_[0], accounts_[accounts_.length - 1]);
    }

    function UserGetInfo(address account_) external override view notPaused returns(WhitelistedData memory) {
        require(account_ != address(0), "ERROR: user address is zero!");
        require(_whitelistedAddresses[account_] == true, "ERROR: user with this address not in whitelist!");
        return _addressToData[account_];
    }

    function UserVerify(address account_) external view notPaused returns(bool) {
        bool userIsWhitelisted = _whitelistedAddresses[account_];
        return userIsWhitelisted;
    }

    // Methods: Claim

    function _minTimeClaim() internal view returns(uint256 time) {
        return _minTimeBetweenClaim;
    }

    function _checkTimeClaim(uint256 nextClaim_) internal view returns(bool isAllowedClaim){
        isAllowedClaim = nextClaim_ > 0 && block.timestamp >= nextClaim_;
        return isAllowedClaim;
    }

    function _checkAmount(uint256 amount_) internal view returns(bool isAmountOk) {
        isAmountOk = amount_ > 0 && _contractBalanceBOT() >= amount_;
        return isAmountOk;
    }

    function _calculateCurrentUserPeriod(WhitelistedData memory data_) internal view returns(uint256 currentPeriod) {
        uint256 timestamp = data_.lastClaimTimestamp;
        currentPeriod = data_.lastClaimedPeriod;
        while((timestamp + _minTimeClaim()) <= block.timestamp) {
            currentPeriod++;
            timestamp += _minTimeClaim();
        }
        if(currentPeriod > data_.totalPeriods) {
            currentPeriod = data_.totalPeriods;
        }
        return currentPeriod;
    }

    function _calculateCurrentPendingUserClaim(WhitelistedData memory data_, uint256 currentPeriod_) internal pure returns(uint256 amount) {
        amount = 0;

        uint256 unClaimedPeriods;
        if(currentPeriod_ <= data_.lastClaimedPeriod) {
            unClaimedPeriods = 0;
        } else {
            unClaimedPeriods = currentPeriod_ - data_.lastClaimedPeriod;
        }

        amount = unClaimedPeriods * data_.periodAmount;
        // Control: don't pay more of reserved total amount
        if(amount > data_.pendingAmountToClaim) {
            amount = data_.pendingAmountToClaim;
        }

        return amount;
    }

    function _claimOneUser(address account_) internal returns(uint256 amount, uint256 currentPeriod) {
        amount = 0;
        // Check if address of user added to whitelist
        bool userInWhitelist = _whitelistedAddresses[account_];
        require(userInWhitelist, "ERROR: User is not added to whitelist!");
        WhitelistedData storage data = _addressToData[account_];
        // Check if user has any amount to claim
        require(data.pendingAmountToClaim > 0, "ERROR: User already claimed all amount of tokens reserved for him!");
        // Check last time execution/release
        bool isAllowedClaim = _checkTimeClaim(data.nextClaimTimestamp);
        require(isAllowedClaim, "ERROR: Is not time to claim tokens, try it late!");
        // Check amount
        currentPeriod = _calculateCurrentUserPeriod(data);
        require(currentPeriod > 0, "ERROR: Current period is 0, not possible to claim!");
        require(currentPeriod > data.lastClaimedPeriod, "ERROR: Current period is already claimed by user!");
        uint256 currentAmountToClaimByUser = _calculateCurrentPendingUserClaim(data, currentPeriod);
        require(currentAmountToClaimByUser > 0, "ERROR: Currently no tokens for this user to claim!");
        bool isAmountOk = _checkAmount(currentAmountToClaimByUser);
        require(isAmountOk, "ERROR: Amount to claim by user is not correct!");
        // Increase time for next claim
        data.lastClaimTimestamp = _firstDateToClaim + (_minTimeClaim() * (currentPeriod - 1));
        data.pendingAmountToClaim -= currentAmountToClaimByUser;
        do {
            data.nextClaimTimestamp = data.nextClaimTimestamp + _minTimeClaim();
        } while(data.nextClaimTimestamp <= block.timestamp);
        if(currentPeriod < data.totalPeriods) {
            data.lastClaimedPeriod = currentPeriod;
        } else {
            data.lastClaimedPeriod = data.totalPeriods;
        }
        // Transfer tokens to user
        _token.transfer(data.account, currentAmountToClaimByUser);
        
        amount = currentAmountToClaimByUser;
        return (amount, currentPeriod);
    }

    function Claim() external override notPaused { // isWhitelisted
        // Check
        address userWallet = msg.sender;
        require(userWallet != address(0), "ERROR: Is not allowed 0 address!");
        // Work
        (uint256 amount, uint256 currentPeriod) = _claimOneUser(userWallet);
        // Event
        emit Claimed(userWallet, amount, currentPeriod);
    }

    function GetTimeForNextClaim() external override view isWhitelisted notPaused returns(uint256 time) {
        WhitelistedData memory data = _addressToData[msg.sender];
        if(block.timestamp >= data.nextClaimTimestamp) {
            time = 0;
        } else {
            time = data.nextClaimTimestamp - block.timestamp;
        }
        return time;
    }

    function GetCurrentTime() external view returns(uint256) {
        return block.timestamp;
    }
}