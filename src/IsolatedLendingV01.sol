// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "solmate/mixins/ERC4626.sol";
import "./interface/IERC20.sol";
import "forge-std/console.sol";


contract IsolatedLendingV01 is ERC4626{

    IERC20 public collateral;
    uint256 public totalBorrow;
    // uint256 public totalAsset;
    uint256 public totalBorrowShares;
    // Total amounts
    uint256 public totalCollateralAmount; // Total collateral supplied
    uint256 public totalCollateralShare;

    //user balances
    mapping(address => uint256) public userCollateralAmount;
    mapping(address => uint256) public userCollateralShare;

    // userAssetFraction is called balanceOf for ERC20 compatibility (it's in ERC20.sol)
    // mapping(address => uint256) public userBorrowAmount;
    mapping(address => uint256) public userBorrowShare;

    uint256 public exchangeRate;

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
        exchangeRate = 15000e18;
    }

    function totalAssets() public override view virtual returns (uint256){
        return asset.balanceOf(address(this));
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

        uint256 utilization = totalBorrow*UTILIZATION_PRECISION / asset.balanceOf(address(this));
        if(utilization < MINIMUM_TARGET_UTILIZATION){
            uint256 underFactor = (MINIMUM_TARGET_UTILIZATION - utilization) * FACTOR_PRECISION / MINIMUM_TARGET_UTILIZATION;
            uint256 scale = INTEREST_ELASTICITY + (underFactor*underFactor*elapsedTime);
            _accrueInfo.interestPerSecond = _accrueInfo.interestPerSecond*(INTEREST_ELASTICITY) / scale;
            if (_accrueInfo.interestPerSecond < MINIMUM_INTEREST_PER_SECOND) {
                _accrueInfo.interestPerSecond = MINIMUM_INTEREST_PER_SECOND; // 0.25% APR minimum
            }
        } else if (utilization > MAXIMUM_TARGET_UTILIZATION) {
            uint256 overFactor = (utilization - MAXIMUM_TARGET_UTILIZATION) * FACTOR_PRECISION / FULL_UTILIZATION_MINUS_MAX;
            uint256 scale = INTEREST_ELASTICITY+(overFactor*overFactor*elapsedTime);
            uint256 newInterestPerSecond = _accrueInfo.interestPerSecond*scale / INTEREST_ELASTICITY;
            if (newInterestPerSecond > MAXIMUM_INTEREST_PER_SECOND) {
                newInterestPerSecond = MAXIMUM_INTEREST_PER_SECOND; // 1000% APR maximum
            }
            _accrueInfo.interestPerSecond = newInterestPerSecond;
        }

        accrueInfo = _accrueInfo;
    }

    function isSolvent(
        address _user
    ) public view returns (bool) {
        // accrue must have already been called!
        uint256 borrowPart = userBorrowShare[_user];
        if (borrowPart == 0) return true;
        uint256 collateralAmount = userCollateralAmount[_user];
        if (collateralAmount == 0) return false;

        return collateralAmount*75/100 >= totalAmountBorrowed(_user)*1e6/exchangeRate;
    }

    modifier solvent() {
        _;
        require(isSolvent(msg.sender), "NenoLend: user insolvent");
    }


    function addAsset(uint256 _amount)public returns (uint256 shares){
        accrue();
        shares = deposit(_amount, msg.sender);
    }

    function addCollateral(uint256 _amount) public {
        userCollateralAmount[msg.sender] += userCollateralAmount[msg.sender] + _amount;
        totalCollateralAmount += totalCollateralAmount + _amount;
        collateral.transferFrom(msg.sender, address(this), _amount);
    }

    function borrow(uint256 _amount)public solvent{
        accrue();

        uint256 _pool = totalBorrow;
        uint256 feeAmount = _amount*(BORROW_OPENING_FEE) / BORROW_OPENING_FEE_PRECISION; // A flat % fee is charged for any borrow
        totalBorrow = totalBorrow + feeAmount + _amount;
        uint256 shares = 0;

        if(totalBorrowShares == 0){
            shares = _amount;
        } else {
            shares = _amount*totalBorrowShares/_pool;
        }
        totalBorrowShares += shares;
        userBorrowShare[msg.sender] += shares;
        asset.transfer(msg.sender, _amount);
    }


    function totalAmountBorrowed(address _user) public view returns (uint256){
        return userBorrowShare[_user] == 0 ? 0 : (totalBorrow*userBorrowShare[_user])/totalBorrowShares;
    }

    function repay(uint256 _amount) public {
        accrue();

        uint256 repaidShares = borrowAmountToShares(_amount);
        userBorrowShare[msg.sender] -= repaidShares;
        totalBorrowShares -= repaidShares;
        totalBorrow -= _amount;

        asset.transferFrom(msg.sender, address(this), _amount);
    }

    function borrowAmountToShares(uint256 _amount) public view returns(uint256 shares){
        if(totalBorrowShares == 0){
            shares = _amount;
        } else {
            shares = _amount*totalBorrowShares/totalBorrow;
        }
    }

    
    function getPricePerShare() public view returns (uint256){
        return totalBorrowShares == 0 ? 1e18 : (totalBorrow*1e18)/totalBorrowShares;
    }
}
