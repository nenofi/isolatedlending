// SPDX-License-Identifier: MIT
// IsolatedLendingV01

// ███╗░░██╗███████╗███╗░░██╗░█████╗░███████╗██╗
// ████╗░██║██╔════╝████╗░██║██╔══██╗██╔════╝██║
// ██╔██╗██║█████╗░░██╔██╗██║██║░░██║█████╗░░██║
// ██║╚████║██╔══╝░░██║╚████║██║░░██║██╔══╝░░██║
// ██║░╚███║███████╗██║░╚███║╚█████╔╝██║░░░░░██║
// ╚═╝░░╚══╝╚══════╝╚═╝░░╚══╝░╚════╝░╚═╝░░░░░╚═╝

pragma solidity ^0.8.16;

import "solmate/mixins/ERC4626.sol";
import "./interface/IERC20.sol";
import "forge-std/console.sol";


contract IsolatedLendingV01 is ERC4626{

    IERC20 public collateral;
    uint256 public totalBorrow; //amt of assets borrowed + interests by users
    uint256 public totalAsset; //amt of assets deposited by users

    uint256 public totalAssetShares;
    uint256 public totalBorrowShares; //amt of borrow shares issued by this pool
    // Total amounts
    uint256 public totalCollateralAmount; // Total collateral supplied
    uint256 public totalCollateralShare;

    //user balances
    mapping(address => uint256) public userCollateralAmount;
    // mapping(address => uint256) public userCollateralShare; UNUSED at the moment

    // userAssetFraction is called balanceOf for ERC20 compatibility (it's in ERC20.sol)
    // mapping(address => uint256) public userBorrowAmount;
    mapping(address => uint256) public userBorrowShare;

    uint256 public exchangeRate;

    // struct AccrueInfo {
    //     uint256 interestPerSecond;
    //     uint256 lastAccrued;
    //     uint256 feesEarnedFraction;
    // }
    struct AccrueInfo {
        uint64 interestPerSecond;
        uint64 lastAccrued;
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

    uint64 private constant STARTING_INTEREST_PER_SECOND = 317097920; // approx 1% APR
    uint64 private constant MINIMUM_INTEREST_PER_SECOND = 79274480; // approx 0.25% APR
    uint64 private constant MAXIMUM_INTEREST_PER_SECOND = 317097920000; // approx 1000% APR
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

    // needs rework
    function totalAssets() public override view virtual returns (uint256){
        return totalAsset + totalBorrow; // + totalborrow?
        // return totalAsset + totalBorrow; // + totalborrow?
    }

    function accrue() public{
        AccrueInfo memory _accrueInfo = accrueInfo;
        uint256 elapsedTime = block.timestamp - _accrueInfo.lastAccrued;
        if (elapsedTime == 0) {
            return;
        }
        _accrueInfo.lastAccrued = uint64(block.timestamp);

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

        uint256 utilization = totalBorrow*UTILIZATION_PRECISION / totalAssets();//asset.balanceOf(address(this));
        if(utilization < MINIMUM_TARGET_UTILIZATION){
            uint256 underFactor = (MINIMUM_TARGET_UTILIZATION - utilization) * FACTOR_PRECISION / MINIMUM_TARGET_UTILIZATION;
            uint256 scale = INTEREST_ELASTICITY + (underFactor*underFactor*elapsedTime);
            _accrueInfo.interestPerSecond = uint64(uint256(_accrueInfo.interestPerSecond)*(INTEREST_ELASTICITY) / scale);
            if (_accrueInfo.interestPerSecond < MINIMUM_INTEREST_PER_SECOND) {
                _accrueInfo.interestPerSecond = MINIMUM_INTEREST_PER_SECOND; // 0.25% APR minimum
            }
        } else if (utilization > MAXIMUM_TARGET_UTILIZATION) {
            uint256 overFactor = (utilization - MAXIMUM_TARGET_UTILIZATION) * FACTOR_PRECISION / FULL_UTILIZATION_MINUS_MAX;
            uint256 scale = INTEREST_ELASTICITY+(overFactor*overFactor*elapsedTime);
            uint256 newInterestPerSecond = uint256(_accrueInfo.interestPerSecond)*scale / INTEREST_ELASTICITY;
            if (newInterestPerSecond > MAXIMUM_INTEREST_PER_SECOND) {
                newInterestPerSecond = MAXIMUM_INTEREST_PER_SECOND; // 1000% APR maximum
            }
            _accrueInfo.interestPerSecond = uint64(newInterestPerSecond);
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

        // console.log(collateralAmount*75/100);
        // console.log(totalAmountBorrowed(_user)*1e6/exchangeRate);

        return collateralAmount*75/100 >= totalAmountBorrowed(_user)*1e6/exchangeRate;
    }

    modifier solvent() {
        _;
        require(isSolvent(msg.sender), "NenoLend: user insolvent");
    }

    function liquidate(address _user, uint256 _amount) public {
        accrue();
        if(!isSolvent(_user)){
            uint256 amountToRepay = totalAmountBorrowed(_user)-(userCollateralAmount[_user]*exchangeRate/1e6);
            // console.log(amountToRepay);
            // console.log(userCollateralAmount[_user]*exchangeRate/1e6);
            uint256 sharesToRepay = borrowAmountToShares(_amount);
            // console.log(_amount/exchangeRate*1e12);
            userBorrowShare[_user] -= sharesToRepay;
            totalBorrowShares -= sharesToRepay;
            totalBorrow -= _amount;

            asset.transferFrom(msg.sender, address(this), _amount);
            uint256 collateralLiquidated = _amount/exchangeRate;
            collateral.transfer(msg.sender, collateralLiquidated);

            // amountToRepay = totalAmountBorrowed(_user)-(userCollateralAmount[_user]*exchangeRate/1e6); 
            // console.log(amountToRepay);
        }
    }

    function updateExchangeRate() public {
        exchangeRate = 15000e18;
    }

    function addAsset(uint256 _amount)public returns (uint256 shares){
        accrue();
        shares = deposit(_amount, msg.sender);
        totalAsset += _amount;

    }

    function removeAsset(uint256 _amount) public returns (uint256 shares){
        accrue();
        shares = withdraw(_amount, msg.sender, msg.sender);
        totalAsset -= _amount;

    }

    function addCollateral(uint256 _amount) public {
        userCollateralAmount[msg.sender] += userCollateralAmount[msg.sender] + _amount;
        totalCollateralAmount += totalCollateralAmount + _amount;
        collateral.transferFrom(msg.sender, address(this), _amount);
    }

    function removeCollateral(uint256 _amount) public solvent {
        // accrue must be called because we check solvency
        accrue();

        userCollateralAmount[msg.sender] -= _amount;
        totalCollateralAmount -= _amount;
        collateral.transferFrom(address(this), msg.sender, _amount);
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
        totalAsset-= _amount;
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


    // NEEDS FIXING: is precision a problem? in this case 1e18
    function borrowSharesToAmount(uint256 _shares) public view returns(uint256 amount){
        uint pricePerShare;
        if(totalBorrowShares ==0){
            amount = 1e18;
        } else{
            amount = _shares*(totalBorrow*1e18/totalBorrowShares)/1e18;
        }
    }

    function getPricePerShare() public view returns (uint256){
        return totalBorrowShares == 0 ? 1e18 : (totalBorrow*1e18)/totalBorrowShares;
    }

    function getInterestPerSecond() external view returns (uint64){
        return accrueInfo.interestPerSecond;
    }
}
