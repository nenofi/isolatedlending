// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "solmate/mixins/ERC4626.sol";
import "./interface/IERC20.sol";

contract IsolatedLendingV01 is ERC4626{

    IERC20 public collateral;
    uint256 public totalBorrow;
    uint256 public totalAsset;
    // Total amounts
    uint256 public totalCollateralAmount; // Total collateral supplied


    //user balances
    mapping(address => uint256) public userCollateralAmount;
    // userAssetFraction is called balanceOf for ERC20 compatibility (it's in ERC20.sol)
    mapping(address => uint256) public userBorrowAmount;


    struct AccrueInfo {
        uint256 interestPerSecond;
        uint256 lastAccrued;
        uint256 feesEarnedFraction;
    }

    AccrueInfo public accrueInfo;

    // Settings for the Medium Risk KashiPair
    uint256 private constant CLOSED_COLLATERIZATION_RATE = 75000; // 75%
    uint256 private constant OPEN_COLLATERIZATION_RATE = 77000; // 77%
    uint256 private constant COLLATERIZATION_RATE_PRECISION = 1e5; // Must be less than EXCHANGE_RATE_PRECISION (due to optimization in math)
    uint256 private constant MINIMUM_TARGET_UTILIZATION = 7e17; // 70%
    uint256 private constant MAXIMUM_TARGET_UTILIZATION = 8e17; // 80%
    uint256 private constant UTILIZATION_PRECISION = 1e18;
    uint256 private constant FULL_UTILIZATION = 1e18;
    uint256 private constant FULL_UTILIZATION_MINUS_MAX = FULL_UTILIZATION - MAXIMUM_TARGET_UTILIZATION;
    uint256 private constant FACTOR_PRECISION = 1e18;

    uint256 private constant STARTING_INTEREST_PER_SECOND = 317097920; // approx 1% APR
    uint256 private constant MINIMUM_INTEREST_PER_SECOND = 79274480; // approx 0.25% APR
    uint256 private constant MAXIMUM_INTEREST_PER_SECOND = 317097920000; // approx 1000% APR
    uint256 private constant INTEREST_ELASTICITY = 28800e36; // Half or double in 28800 seconds (8 hours) if linear

    uint256 private constant EXCHANGE_RATE_PRECISION = 1e18;

    uint256 private constant LIQUIDATION_MULTIPLIER = 112000; // add 12%
    uint256 private constant LIQUIDATION_MULTIPLIER_PRECISION = 1e5;

    // Fees
    uint256 private constant PROTOCOL_FEE = 10000; // 10%
    uint256 private constant PROTOCOL_FEE_DIVISOR = 1e5;
    uint256 private constant BORROW_OPENING_FEE = 50; // 0.05%
    uint256 private constant BORROW_OPENING_FEE_PRECISION = 1e5;

    constructor(ERC20 _asset, address _collateral, string memory _name, string memory _symbol)ERC4626(_asset, _name, _symbol){
        collateral = IERC20(_collateral);
        accrueInfo.interestPerSecond = STARTING_INTEREST_PER_SECOND;
    }

    function accrue() public{
        AccrueInfo memory _accrueInfo = accrueInfo;
        uint256 elapsedTime = block.timestamp - _accrueInfo.lastAccrued;
        if (elapsedTime == 0) {
            return;
        }
        _accrueInfo.lastAccrued = block.timestamp;

        if(totalBorrow == 0){
            if(_accrueInfo.interestPerSecond != STARTING_INTEREST_PER_SECOND){
                _accrueInfo.interestPerSecond = STARTING_INTEREST_PER_SECOND;
            }
            accrueInfo = _accrueInfo;
            return;
        }

        uint256 extraAmount = 0;
        uint256 feeFraction = 0;

        extraAmount = totalBorrow * _accrueInfo.interestPerSecond * elapsedTime / 1e18;
        totalBorrow = totalBorrow + extraAmount;
        // add interest as asset down here, total borrow must == total asset
        // add user's borrow amount as part of total borrow's share

        //*borrow* elastic = Total token amount to be repayed by borrowers, base = Total parts of the debt held by borrowers
        // return base
        // base = elastic * total.base / total.elastic

    }

    function totalAssets() public override view virtual returns (uint256){
        return totalAsset;
    }

    function addAsset(uint256 _amount)public returns (uint256 shares){
        // accrue();
        shares = deposit(_amount, msg.sender);
        totalAsset += _amount;
    }

    function addCollateral(uint256 _amount) public {
        userCollateralAmount[msg.sender] += userCollateralAmount[msg.sender] + _amount;
        totalCollateralAmount += totalCollateralAmount + _amount;
        collateral.transferFrom(msg.sender, address(this), _amount);
    }

    function borrow(uint256 _amount)public {
        uint256 feeAmount = _amount*(BORROW_OPENING_FEE) / BORROW_OPENING_FEE_PRECISION; // A flat % fee is charged for any borrow
        userBorrowAmount[msg.sender] += _amount + feeAmount;
        totalBorrow += userBorrowAmount[msg.sender];
        totalAsset -= _amount;
        asset.transfer(msg.sender, _amount);    
    }
}
