// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/test/MockERC20.sol";
import "../src/IsolatedLendingV01.sol";


contract IsolatedLendingV01Test is Test {
    MockERC20 public neIDR;
    MockERC20 public usdt;
    IsolatedLendingV01 public isolatedLending;

    address public Alice = address(0x2);
    address public Bob = address(0x3);
    address public Charlie = address(0x4);

    function setUp() public {
        neIDR = new MockERC20("neRupiah", "neIDR", 18);
        usdt = new MockERC20("Tether USD", "USDT", 6);
        isolatedLending = new IsolatedLendingV01(neIDR, address(usdt), "neRupiahUSDT vault", "neIDR/USDT");
        // vm.startPrank(Bob);
        // neIDR.mint(10000000e18);
        // vm.stopPrank();
        // vm.startPrank(Alice);
        // usdt.mint(1000e6);
        // vm.stopPrank();
    }

    function testAddAsset() public {
        vm.startPrank(Bob);
        neIDR.mint(10000000e18);
        neIDR.approve(address(isolatedLending), 10000000e18);
        isolatedLending.addAsset(10000000e18);
        vm.stopPrank();
        // console.log(isolatedLending.balanceOf(address(Bob)));
        assertEq(isolatedLending.balanceOf(address(Bob)), 10000000e18);
    }

    function testAddCollateral() public {
        vm.startPrank(Charlie);
        neIDR.mint(20000000e18);
        neIDR.approve(address(isolatedLending), 20000000e18);
        // isolatedLending.addAsset(20000000e18);
        vm.stopPrank();

        vm.startPrank(Bob);
        neIDR.mint(20000000e18);
        neIDR.approve(address(isolatedLending), 20000000e18);
        isolatedLending.addAsset(20000000e18);
        vm.stopPrank();

        vm.startPrank(Alice);
        usdt.mint(1000e6);
        usdt.approve(address(isolatedLending), 1000e6);
        isolatedLending.addCollateral(1000e6);
        isolatedLending.borrow(11200000e18);
        // console.log(isolatedLending.userCollateralAmount(address(Alice)) * isolatedLending.exchangeRate());
        // console.log(15000000000000000000000000/1e18);
        // isolatedLending.isSolvent(address(Alice));
        // console.log(isolatedLending.totalAmountBorrowed(address(Alice)));
        // console.log(isolatedLending.userCollateralAmount(address(Alice))*isolatedLending.exchangeRate()/1e6);
        // console.log(isolatedLending.totalAmountBorrowed(address(Alice)));
        vm.stopPrank();
        console.log(isolatedLending.isSolvent(address(Alice)));
        isolatedLending.updateExchangeRate();
        vm.startPrank(Charlie);
        isolatedLending.liquidate(address(Alice), 1);
        console.log(usdt.balanceOf(address(Charlie)));
        vm.stopPrank();
        console.log(isolatedLending.isSolvent(address(Alice)));

        // console.log(isolatedLending.isSolvent(address(Alice)));
        // console.log(isolatedLending.userCollateralAmount(address(Alice))*isolatedLending.exchangeRate()/1e6);
        // console.log(isolatedLending.totalAmountBorrowed(address(Alice)));

        // assertEq(isolatedLending.balanceOf(address(Alice)), 1000e6);
        // vm.startPrank(Alice);
        // isolatedLending.borrow(1000000e18);
        // vm.stopPrank();
        // console.log(isolatedLending.userBorrowAmount(address(Alice))/1e18);
        // console.log(isolatedLending.convertToAssets(isolatedLending.balanceOf(address(Bob)))/1e18);
    }
    // function testAddAliceBorrow() public {
    //     vm.startPrank(Bob);
    //     neIDR.mint(10000000e18);
    //     neIDR.approve(address(isolatedLending), 10000000e18);
    //     isolatedLending.addAsset(10000000e18);
    //     vm.stopPrank();


    //     vm.startPrank(Alice);
    //     isolatedLending.borrow(9500000e18);
    //     // console.log(neIDR.balanceOf(address(Alice)));
    //     // console.log(isolatedLending.userBorrowShare(address(Alice)));
    //     // console.log(isolatedLending.totalAmountBorrowed(address(Alice)));
    //     // console.log(isolatedLending.totalBorrowShares());
    //     // console.log(isolatedLending.getPricePerShare());
    //     // console.log(isolatedLending.userBorrowShare(address(Alice)));
    //     // isolatedLending.convertSharesToAmount(500000e18);
    //     vm.warp(block.timestamp + 1);
    //     isolatedLending.accrue();
    //     // console.log(isolatedLending.getPricePerShare());

    //     vm.stopPrank();

    //     vm.warp(block.timestamp + 2629743);
    //     isolatedLending.accrue();
    //     // console.log(isolatedLending.totalAmountBorrowed(address(Alice))/1e18);
    //     // console.log(isolatedLending.getPricePerShare());


    //     // vm.warp(block.timestamp + 5259486);
    //     // isolatedLending.accrue();
    //     // console.log(isolatedLending.totalAmountBorrowed(address(Alice))/1e18);


    //     // console.log(isolatedLending.userBorrowShare(address(Alice)));
    //     // console.log(isolatedLending.totalAmountBorrowed(address(Alice))/1e18);


    //     // vm.startPrank(Charlie);
    //     // isolatedLending.borrow(5000000e18);
    //     // // console.log(isolatedLending.userBorrowAmount(address(Charlie)));
    //     // vm.warp(block.timestamp + 31556926);
    //     // isolatedLending.accrue();
    //     // vm.stopPrank();

    //     // console.log(isolatedLending.userBorrowShare(address(Alice)));
    //     // console.log(isolatedLending.totalAmountBorrowed(address(Alice))/1e18);
    //     // console.log(isolatedLending.userBorrowShare(address(Charlie)));
    //     // console.log(isolatedLending.totalAmountBorrowed(address(Charlie))/1e18);

    //     // console.log(isolatedLending.totalBorrow());
    //     // console.log(isolatedLending.userBorrowAmount(address(Charlie)));
    //     // console.log(isolatedLending.currentUserBorrowAmount(address(Charlie)));

    //     // console.log(isolatedLending.currentUserBorrowAmount(address(Alice)));

    //     // console.log(isolatedLending.convertToAssets(isolatedLending.balanceOf(address(Bob)))/1e18);
    // }

    // function testAccrue() public {
    //     vm.startPrank(Bob);
    //     neIDR.mint(10000000e18);
    //     neIDR.approve(address(isolatedLending), 10000000e18);
    //     isolatedLending.addAsset(10000000e18);
    //     vm.stopPrank();

        
    //     vm.startPrank(Alice);
    //     isolatedLending.borrow(9000000e18);
    //     vm.warp(block.timestamp + 500000);
    //     isolatedLending.accrue();
    //     // isolatedLending.repay(50000e18);
    //     vm.stopPrank();

    // }

    // function testRepay() public {
    //     vm.startPrank(Bob);
    //     neIDR.mint(10000000e18);
    //     // console.log(neIDR.balanceOf(address(Bob)));
    //     neIDR.approve(address(isolatedLending), 10000000e18);
    //     isolatedLending.addAsset(10000000e18);
    //     // console.log(neIDR.balanceOf(address(Bob)));
    //     vm.stopPrank();

        
    //     vm.startPrank(Alice);
    //     neIDR.mint(10000000e18);
    //     neIDR.approve(address(isolatedLending), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    //     isolatedLending.borrow(9000000e18);
    //     vm.warp(block.timestamp + 1);
    //     isolatedLending.accrue();
    //     vm.warp(block.timestamp + 500000);
    //     isolatedLending.accrue();
    //     isolatedLending.repay(9006011077841700379374997);
    //     // console.log(isolatedLending.totalAmountBorrowed(address(Alice)));
    //     // console.log(neIDR.balanceOf(address(Alice)));
    //     vm.stopPrank();

    //     vm.startPrank(Bob);
    //     // console.log(neIDR.balanceOf(address(isolatedLending)));
    //     // console.log(isolatedLending.totalAssets())
    //     isolatedLending.approve(address(isolatedLending),0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff );
    //     isolatedLending.redeem(10000000e18, address(Bob), address(Bob));


    //     // console.log(isolatedLending.balanceOf(address(Bob)));
    //     // console.log(isolatedLending.previewRedeem(10000000e18));
    //     // isolatedLending.maxRedeem(address(Bob));
    //     // console.log(neIDR.balanceOf(address(Bob)));

    //     // isolatedLending.withdraw(5000000e18, address(Bob), address(Bob));
    //     // console.log(neIDR.balanceOf(address(Bob)));
    //     vm.stopPrank();

    //     // console.log(isolatedLending.totalAssets());
    //     // console.log(neIDR.balanceOf(address(isolatedLending)));

    // }


}
