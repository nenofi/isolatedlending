// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/test/MockERC20.sol";
import "../src/IsolatedLendingV01.sol";


contract IsolatedLendingV01Test is Test {
    MockERC20 public neIDR;
    MockERC20 public usdt;
    MockERC20 public wBTC;
    IsolatedLendingV01 public isolatedLending;

    address public Borrower1 = address(0x2);
    address public Borrower2 = address(0x3);
    address public Lender1 = address(0x4);
    address public Lender2 = address(0x5);
    address public Liquidator1 = address(0x6);
    address public Liquidator2 = address(0x7);

    function setUp() public {
        neIDR = new MockERC20("neRupiah", "neIDR", 18);
        usdt = new MockERC20("Tether USD", "USDT", 6);
        wBTC = new MockERC20("wrapped BTC", "WBTC", 18);
        // isolatedLending = new IsolatedLendingV01(neIDR, address(usdt), "neRupiahUSDT vault", "neIDR/USDT");
        isolatedLending = new IsolatedLendingV01(usdt, address(wBTC), "usdtwBTC vault", "USDT/wBTC");

        vm.startPrank(Lender1);
        neIDR.mint(100000000e18);
        usdt.mint(50000e6);
        vm.stopPrank();

        vm.startPrank(Lender2);
        neIDR.mint(100000000e18);
        usdt.mint(100000e6);
        vm.stopPrank();

        vm.startPrank(Borrower1);
        wBTC.mint(1e8);
        usdt.mint(50000e6);
        vm.stopPrank();

        vm.startPrank(Borrower2);
        wBTC.mint(5e7); //0.5 wbtc
        vm.stopPrank();

        vm.startPrank(Liquidator1);
        neIDR.mint(100000000e18);
        usdt.mint(50000e6);
        vm.stopPrank();

        vm.startPrank(Liquidator2);
        neIDR.mint(100000000e18);
        usdt.mint(100000e6);
        vm.stopPrank();
    }

    function testAddAndRemoveAsset() public {
        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 50000e6);
        // console.log(isolatedLending.exchangeRate());
        vm.startPrank(Lender1);
        isolatedLending.removeAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 0);


    }

    function testAddCollateral() public {
        vm.startPrank(Borrower1);
        wBTC.approve(address(isolatedLending), 1e8);
        isolatedLending.addCollateral(1e8);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Borrower1)), 1e8);
    }

    // TODO: Figure out optimal MIN_TARGET_UTILIZATION and MAX_TARGET_UTILIZATION for the interest rate model
    function testBorrow() public {
        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 50000e6);

        vm.startPrank(Borrower1);
        wBTC.approve(address(isolatedLending), 1e8);
        isolatedLending.addCollateral(1e8);
        isolatedLending.borrow(8000e6);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Borrower1)), 1e8);
        assertEq(usdt.balanceOf(address(Borrower1)), 58000e6);

    }

    function testMultipleBorrow() public {
        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 50000e6);

        vm.startPrank(Borrower1);
        wBTC.approve(address(isolatedLending), 1e18);
        isolatedLending.addCollateral(1e8);
        isolatedLending.borrow(8000e6);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Borrower1)), 1e8);
        assertEq(usdt.balanceOf(address(Borrower1)), 58000e6);

        vm.startPrank(Borrower2);
        wBTC.approve(address(isolatedLending), 5e7);
        isolatedLending.addCollateral(5e7);
        isolatedLending.borrow(2000e6);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Borrower2)), 5e7);
        assertEq(usdt.balanceOf(address(Borrower2)), 2000e6);

    }

    // TODO add test multiple Lender and repayments
    // to count APY for each user, we must take into account their shares of borrow/supply
    // see: https://docs.solend.fi/getting-started/supply-and-borrow-apy

    function testBorrowWithoutCollateral() public {
        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 50000e6);

        vm.startPrank(Borrower1);
        vm.expectRevert(bytes("NenoLend: user insolvent"));
        isolatedLending.borrow(8000e6);
        vm.stopPrank();
    }

    // TODO: totalassets == totalborrow, so asset depositor's shares won't be burned less than the value at the time they deposited their asset
    //       - keep track of asset depositor's shares in respect to total borrow not total assets available i.e. usdt.balanceOf(address(isolatedLending))
    //       - override withdraw? or redo share counting? etc.
    function testWithdrawAllAssetWhenBorrowed() public {
        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(10000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 10000e6);

        vm.startPrank(Borrower1);
        wBTC.approve(address(isolatedLending), 1e8);
        isolatedLending.addCollateral(1e8);
        isolatedLending.borrow(8000e6);
        vm.stopPrank();

        vm.startPrank(Lender1);
        vm.expectRevert(abi.encodePacked("TRANSFER_FAILED"));

        isolatedLending.removeAsset(isolatedLending.maxWithdraw(address(Lender1)));
        // isolatedLending.withdraw(isolatedLending.maxWithdraw(address(Lender1)), address(Lender1), address(Lender1));

        vm.stopPrank();
        // console.log(isolatedLending.balanceOf(address(Lender1)));
        
    }

    function testWithdrawSomeAssetWhenBorrowed() public {
        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(10000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 10000e6);

        vm.startPrank(Borrower1);
        wBTC.approve(address(isolatedLending), 1e8);
        isolatedLending.addCollateral(1e8);
        isolatedLending.borrow(8000e6);
        vm.stopPrank();

        vm.startPrank(Lender1);
        isolatedLending.removeAsset(1000e6);
        // isolatedLending.withdraw(1000e6, address(Lender1), address(Lender1));
        vm.stopPrank();
        assertEq(usdt.balanceOf(address(Lender1)), 41000e6);

    }

    function testMultipleAddAssets() public {
        vm.startPrank(Lender1);
        // console.log(isolatedLending.previewDeposit(50000e6));
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 50000e6);
        // console.log(isolatedLending.totalAssets());

        vm.startPrank(Lender2);
        // console.log(isolatedLending.previewDeposit(100000e6));
        // console.log(isolatedLending.convertToShares(100000e6));
        usdt.approve(address(isolatedLending), 100000e6);
        isolatedLending.addAsset(100000e6);
        vm.stopPrank();
        // console.log(isolatedLending.balanceOf(address(Lender1)));
        // console.log(isolatedLending.balanceOf(address(Lender2)));

        assertEq(isolatedLending.balanceOf(address(Lender2)), 100000e6);
        // assertEq(isolatedLending.maxWithdraw(address(Lender1)), 50000e6);
        // assertEq(isolatedLending.maxWithdraw(address(Lender2)), 100000e6);

        // console.log(isolatedLending.totalAssets());
        // console.log(isolatedLending.maxWithdraw(address(Lender1)));
        // console.log(isolatedLending.maxWithdraw(address(Lender2)));

    }

    function testExchangeRateInsolvency() public {
        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 50000e6);

        vm.startPrank(Borrower1);
        wBTC.approve(address(isolatedLending), 1e8);
        isolatedLending.addCollateral(1e8);
        isolatedLending.borrow(11200e6);
        vm.stopPrank();
        assertEq(isolatedLending.isSolvent(Borrower1), true);

        // console.log(isolatedLending.isSolvent(Borrower1));
        // console.log(isolatedLending.userCollateralAmount(address(Borrower1))*isolatedLending.exchangeRate()*1e10*75/100/1e18);
        isolatedLending.updateExchangeRate(14000e8);
        assertEq(isolatedLending.isSolvent(Borrower1), false);

        // console.log(isolatedLending.isSolvent(Borrower1));
        // console.log(isolatedLending.userCollateralValue(address(Borrower1)));
        // console.log(isolatedLending.userCollateralAmount(address(Borrower1))*isolatedLending.exchangeRate()*75/100/1e18);

    }

   function testInterestRateInsolvency() public {
        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 12000e6);
        isolatedLending.addAsset(12000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 12000e6);

        vm.startPrank(Borrower1);
        wBTC.approve(address(isolatedLending), 1e8);
        isolatedLending.addCollateral(1e8);
        isolatedLending.borrow(11200e6);
        vm.stopPrank();
        assertEq(isolatedLending.isSolvent(Borrower1), true);
        // console.log(isolatedLending.totalAmountBorrowed(Borrower1));
        // console.log(isolatedLending.isSolvent(Borrower1));
        // console.log(block.timestamp);

        vm.warp(block.timestamp+100);
        isolatedLending.accrue();
        vm.warp(block.timestamp+100000);
        isolatedLending.accrue();
        vm.warp(block.timestamp+1400000);
        isolatedLending.accrue();
        vm.warp(block.timestamp+250000);
        isolatedLending.accrue();

        assertEq(isolatedLending.isSolvent(Borrower1), false);
        // console.log(isolatedLending.totalAmountBorrowed(Borrower1));
        // console.log(isolatedLending.isSolvent(Borrower1));
        // console.log(block.timestamp);
    }


   function testBorrowMoreThanSupply() public {
        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 10000e6);
        isolatedLending.addAsset(10000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 10000e6);

        vm.startPrank(Borrower1);
        wBTC.approve(address(isolatedLending), 1e8);
        isolatedLending.addCollateral(1e8);
        vm.expectRevert(bytes("Arithmetic over/underflow"));
        isolatedLending.borrow(11200e6);
        vm.stopPrank();
        assertEq(isolatedLending.isSolvent(Borrower1), true);

    }

    function testLiquidate() public {
        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 50000e6);

        vm.startPrank(Borrower1);
        wBTC.approve(address(isolatedLending), 1e8);
        isolatedLending.addCollateral(1e8);
        isolatedLending.borrow(11200e6);
        vm.stopPrank();
        assertEq(isolatedLending.isSolvent(Borrower1), true);

        isolatedLending.updateExchangeRate(14000e8);
        assertEq(isolatedLending.isSolvent(Borrower1), false);
        // console.log(isolatedLending.isSolvent(Borrower1));

        // console.log(isolatedLending.isSolvent(address(Borrower1)));
        // console.log(isolatedLending.totalAmountBorrowed(address(Borrower1)));
        // console.log(isolatedLending.userCollateralValue(address(Borrower1))/1e12*75/100);
        // vm.startPrank(Liquidator1);
        // usdt.approve(address(isolatedLending), 50000e6);
        // isolatedLending.liquidate(address(Borrower1), 4000e6);
        // vm.stopPrank();

        // console.log(wBTC.balanceOf(Liquidator1));
        // console.log(isolatedLending.userCollateralAmount(Borrower1));
        // assertEq(isolatedLending.isSolvent(Borrower1), true);

    }

    // TODO add interest rate test
    function testInterestRate() public {

        vm.startPrank(Lender1);
        usdt.approve(address(isolatedLending), 10000e6);
        isolatedLending.addAsset(10000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 10000e6);
        // console.log("Vault USDT Balance: %s", usdt.balanceOf(address(isolatedLending)));

        // vm.startPrank(Lender2);
        // usdt.transfer(address(isolatedLending), 1000e6);
        // console.log("Vault USDT Balance: %s", usdt.balanceOf(address(isolatedLending)));

        vm.startPrank(Borrower1);
        wBTC.approve(address(isolatedLending), 1e8);
        isolatedLending.addCollateral(1e8);
        isolatedLending.borrow(8000e6);
        vm.stopPrank();
        assertEq(isolatedLending.isSolvent(Borrower1), true);
        // console.log("Borrower 1: %s", isolatedLending.totalAmountBorrowed(address(Borrower1)));

        // vm.warp(block.timestamp+10518975);
        // isolatedLending.accrue();
        // vm.warp(block.timestamp+10518975);
        // isolatedLending.accrue();
        // vm.warp(block.timestamp+10518975);
        // isolatedLending.accrue();

        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();
        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();
        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();

        console.log("Borrower 1: %s", isolatedLending.totalAmountBorrowed(address(Borrower1)));
        vm.startPrank(Borrower1);
        usdt.approve(address(isolatedLending), 1000000e6);
        isolatedLending.repay(8084867235);
        vm.stopPrank();
        

        // isolatedLending.withdrawFees();
        console.log("Owner's Balance: %s", isolatedLending.balanceOf(address(this)));
        isolatedLending.removeAsset(isolatedLending.maxWithdraw(address(this)));

        // isolatedLending.withdrawFees();
        vm.startPrank(Lender1);
        // console.log("Lender1 Vault Balance: %s", isolatedLending.balanceOf(address(Lender1)));
        // console.log(isolatedLending.convertToAssets(10000000000));
        // isolatedLending.removeAsset(10000e6);
        // console.log("Lender1 USDT Balance: %s", usdt.balanceOf(address(Lender1)));
        // console.log("Vault USDT Balance: %s", usdt.balanceOf(address(isolatedLending)));
        console.log("max withdraw: %s", isolatedLending.maxWithdraw(address(Lender1)));
        isolatedLending.removeAsset(isolatedLending.maxWithdraw(address(Lender1)));
        // isolatedLending.redeem(10000000000, address(Lender1), address(Lender1));
        // isolatedLending.withdraw(11000000000, address(Lender1), address(Lender1));
        // isolatedLending.removeAsset(11000000000);


        console.log("Lender1 USDT Balance: %s", usdt.balanceOf(address(Lender1)));

        vm.stopPrank();

        // // console.log("Owner's Balance: %s", isolatedLending.balanceOf(address(this)));
        // // isolatedLending.redeem(16852738,address(this),address(this));
        // // console.log(usdt.balanceOf(address(this)));
        // // console.log(isolatedLending.getPricePerShare()*isolatedLending.balanceOf(address(this)) );
        // console.log("IsolatedLending Balance: %s", usdt.balanceOf(address(isolatedLending)));



        // // vm.warp(block.timestamp+31556926);
        // // isolatedLending.accrue();

        // //75% utilization 1% apy
        // //80% utilization 1% apy
        // console.log("Borrower 1: %s",isolatedLending.totalAmountBorrowed(address(Borrower1))); 


    }

}
