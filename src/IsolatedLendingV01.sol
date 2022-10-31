// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "solmate/mixins/ERC4626.sol";
import "./interface/IERC20.sol";
import "forge-std/console.sol";

struct Rebase {
    uint256 elastic;
    uint256 base;
}

/// @notice A rebasing library using overflow-/underflow-safe math.
library RebaseLibrary {

    /// @notice Calculates the base value in relationship to `elastic` and `total`.
    function toBase(
        Rebase memory total,
        uint256 elastic,
        bool roundUp
    ) internal pure returns (uint256 base) {
        if (total.elastic == 0) {
            base = elastic;
        } else {
            base = elastic*total.base / total.elastic;
            // if (roundUp && base.mul(total.elastic) / total.base < elastic) {
            //     base = base.add(1);
            // }
        }
    }

    /// @notice Calculates the elastic value in relationship to `base` and `total`.
    function toElastic(
        Rebase memory total,
        uint256 base,
        bool roundUp
    ) internal pure returns (uint256 elastic) {
        if (total.base == 0) {
            elastic = base;
        } else {
            elastic = base*total.elastic / total.base;
            // if (roundUp && elastic.mul(total.base) / total.elastic < base) {
            //     elastic = elastic.add(1);
            // }
        }
    }

    /// @notice Add `elastic` to `total` and doubles `total.base`.
    /// @return (Rebase) The new total.
    /// @return base in relationship to `elastic`.
    function add(
        Rebase memory total,
        uint256 elastic,
        bool roundUp
    ) internal pure returns (Rebase memory, uint256 base) {
        base = toBase(total, elastic, roundUp);
        total.elastic = total.elastic+(elastic);
        total.base = total.base+(base);
        return (total, base);
    }

    /// @notice Sub `base` from `total` and update `total.elastic`.
    /// @return (Rebase) The new total.
    /// @return elastic in relationship to `base`.
    function sub(
        Rebase memory total,
        uint256 base,
        bool roundUp
    ) internal pure returns (Rebase memory, uint256 elastic) {
        elastic = toElastic(total, base, roundUp);
        total.elastic = total.elastic-(elastic);
        total.base = total.base-(base);
        return (total, elastic);
    }

    /// @notice Add `elastic` and `base` to `total`.
    function add(
        Rebase memory total,
        uint256 elastic,
        uint256 base
    ) internal pure returns (Rebase memory) {
        total.elastic = total.elastic+(elastic);
        total.base = total.base+(base);
        return total;
    }

    /// @notice Subtract `elastic` and `base` to `total`.
    function sub(
        Rebase memory total,
        uint256 elastic,
        uint256 base
    ) internal pure returns (Rebase memory) {
        total.elastic = total.elastic-(elastic);
        total.base = total.base-(base);
        return total;
    }
}

contract IsolatedLendingV01 is ERC4626{
    using RebaseLibrary for Rebase;

    IERC20 public collateral;
    // Rebase public totalBorrow;
    // Rebase public totalAsset;
    uint256 public totalBorrow;
    uint256 public totalAsset;
    uint256 public totalBorrowShares;
    // Total amounts
    uint256 public totalCollateralAmount; // Total collateral supplied


    //user balances
    mapping(address => uint256) public userCollateralAmount;
    // userAssetFraction is called balanceOf for ERC20 compatibility (it's in ERC20.sol)
    mapping(address => uint256) public userBorrowAmount;
    mapping(address => uint256) public userBorrowShare;


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
        // return totalAsset;
    }

    function addAsset(uint256 _amount)public returns (uint256 shares){
        /*OLD CODE*/
        // accrue();
        shares = deposit(_amount, msg.sender);
        totalAsset += _amount;

        // Rebase memory _totalAsset = totalAsset;
        // uint256 totalAssetShare = _totalAsset.elastic;
        // uint256 allShare = _totalAsset.elastic;
        // fraction = allShare == 0 ? _amount : _amount*(_totalAsset.base) / allShare;
        // if (_totalAsset.base+(fraction) < 1000) {
        //     return 0;
        // }
        // totalAsset = _totalAsset.add(_amount, fraction);
        // balanceOf[msg.sender] = balanceOf[msg.sender]+(fraction);
        // asset.transferFrom(msg.sender, address(this), _amount);
    }

    function addCollateral(uint256 _amount) public {
        userCollateralAmount[msg.sender] += userCollateralAmount[msg.sender] + _amount;
        totalCollateralAmount += totalCollateralAmount + _amount;
        collateral.transferFrom(msg.sender, address(this), _amount);
    }

    function borrow(uint256 _amount)public {
        /*OLD CODE*/
        // uint256 feeAmount = _amount*(BORROW_OPENING_FEE) / BORROW_OPENING_FEE_PRECISION; // A flat % fee is charged for any borrow
        // userBorrowAmount[msg.sender] += _amount + feeAmount;
        // totalBorrow += userBorrowAmount[msg.sender];
        // totalAsset -= _amount;
        // asset.transfer(msg.sender, _amount); 

        uint256 _pool = totalBorrow;
        uint256 feeAmount = _amount*(BORROW_OPENING_FEE) / BORROW_OPENING_FEE_PRECISION; // A flat % fee is charged for any borrow
        // totalBorrow += feeAmount;
        totalBorrow = totalBorrow + feeAmount + _amount;
        uint256 _after = totalBorrow;
        uint256 shares = 0;
        if(totalBorrowShares == 0){
            shares = _amount;
            // userBorrowShare[msg.sender] += _amount;
            // totalBorrowShares += userBorrowShare[msg.sender];
        } else {
            shares = _amount*totalBorrowShares/_pool;
            // userBorrowShare[msg.sender] += _amount * totalBorrowShares / beforeBorrow;
            // totalBorrowShares += userBorrowShare[msg.sender];
        }
        totalBorrowShares += shares;
        userBorrowShare[msg.sender] += shares;


        // uint256 part;
        // uint256 share;

        // uint256 feeAmount = _amount*(BORROW_OPENING_FEE) / BORROW_OPENING_FEE_PRECISION; // A flat % fee is charged for any borrow
        // (totalBorrow, part) = totalBorrow.add(_amount+(feeAmount), true);
        // userBorrowShare[msg.sender] = userBorrowShare[msg.sender]+(part);

        // Rebase memory _totalAsset = totalAsset;
        // require(_totalAsset.base >= 1000, "Kashi: below minimum");
        // _totalAsset.elastic = _totalAsset.elastic.sub(share.to128());
        // totalAsset = _totalAsset;
        // bentoBox.transfer(asset, address(this), to, share);
    }

    function currentUserBorrowAmount(address _user) public view returns (uint256){
        // console.log(totalBorrow);
        // console.log(userBorrowAmount[_user]);
        // console.log(userBorrowAmount[_user]*totalBorrow/userBorrowAmount[_user]);
        uint256 rate = totalBorrow * 1e18 / userBorrowAmount[_user];
        return userBorrowAmount[_user] * rate;
    }

    function totalAmountBorrowed(address _user) public view returns (uint256){
        // console.log(_shares);
        // console.log(totalBorrow);
        // console.log(totalBorrowShares);
        return (totalBorrow*userBorrowShare[_user])/totalBorrowShares;
    }
    
    function getPricePerShare() public view returns (uint256){
        return totalBorrowShares == 0 ? 1e18 : (totalBorrow*1e18)/totalBorrowShares;
    }
}
