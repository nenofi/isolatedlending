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

    address public Alice = address(0x2);
    address public Bob = address(0x3);
    address public Charlie = address(0x4);

    function setUp() public {
        neIDR = new MockERC20("neRupiah", "neIDR", 18);
        usdt = new MockERC20("Tether USD", "USDT", 6);
        wBTC = new MockERC20("wrapped BTC", "WBTC", 18);
        // isolatedLending = new IsolatedLendingV01(neIDR, address(usdt), "neRupiahUSDT vault", "neIDR/USDT");
        isolatedLending = new IsolatedLendingV01(usdt, address(wBTC), "usdtwBTC vault", "USDT/wBTC");

        vm.startPrank(Bob);
        neIDR.mint(100000000e18);
        usdt.mint(50000e6);
        vm.stopPrank();

        vm.startPrank(Alice);
        wBTC.mint(1e18);
        vm.stopPrank();

        vm.startPrank(Charlie);
        wBTC.mint(5e17); //0.5 wbtc
        vm.stopPrank();
    }

    function testAddAsset() public {
        vm.startPrank(Bob);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Bob)), 50000e6);
    }

    function testAddCollateral() public {
        vm.startPrank(Alice);
        wBTC.approve(address(isolatedLending), 1e18);
        isolatedLending.addCollateral(1e18);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Alice)), 1e18);
    }

    // TODO: Figure out optimal MIN_TARGET_UTILIZATION and MAX_TARGET_UTILIZATION for the interest rate model
    function testBorrow() public {
        vm.startPrank(Bob);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Bob)), 50000e6);

        vm.startPrank(Alice);
        wBTC.approve(address(isolatedLending), 1e18);
        isolatedLending.addCollateral(1e18);
        isolatedLending.borrow(8000e6);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Alice)), 1e18);
        assertEq(usdt.balanceOf(address(Alice)), 8000e6);
        // console.log(isolatedLending.totalBorrow());
        // console.log(isolatedLending.getInterestPerSecond());
        // vm.warp(block.timestamp + 10);
        // isolatedLending.accrue();
        // console.log(isolatedLending.totalBorrow());
        // console.log(isolatedLending.getInterestPerSecond());
        // vm.warp(block.timestamp + 100);
        // isolatedLending.accrue();
        // console.log(isolatedLending.totalBorrow());
        // console.log(isolatedLending.getInterestPerSecond());
        // vm.warp(block.timestamp + 1000);
        // isolatedLending.accrue();
        // console.log(isolatedLending.totalBorrow());
        // console.log(isolatedLending.getInterestPerSecond());
        // vm.warp(block.timestamp + 10000);
        // isolatedLending.accrue();
        // console.log(isolatedLending.totalBorrow());
        // console.log(isolatedLending.getInterestPerSecond());
    }

    function testMultipleBorrow() public {
        vm.startPrank(Bob);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Bob)), 50000e6);

        vm.startPrank(Alice);
        wBTC.approve(address(isolatedLending), 1e18);
        isolatedLending.addCollateral(1e18);
        isolatedLending.borrow(8000e6);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Alice)), 1e18);
        assertEq(usdt.balanceOf(address(Alice)), 8000e6);

        // console.log(isolatedLending.userBorrowShare(address(Alice)));
        // console.log(isolatedLending.totalAmountBorrowed(address(Alice)));
        // console.log(isolatedLending.borrowSharesToAmount(isolatedLending.userBorrowShare(address(Alice))));

        vm.startPrank(Charlie);
        wBTC.approve(address(isolatedLending), 5e17);
        isolatedLending.addCollateral(5e17);
        isolatedLending.borrow(2000e6);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Charlie)), 5e17);
        assertEq(usdt.balanceOf(address(Charlie)), 2000e6);

        // console.log(isolatedLending.userBorrowShare(address(Charlie)));
        // console.log(isolatedLending.totalAmountBorrowed(address(Charlie)));
        // console.log(isolatedLending.borrowSharesToAmount(isolatedLending.userBorrowShare(address(Charlie))));
    }

    function testBorrowWithoutCollateral() public {
        vm.startPrank(Bob);
        usdt.approve(address(isolatedLending), 50000e6);
        isolatedLending.addAsset(50000e6);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Bob)), 50000e6);

        vm.startPrank(Alice);
        vm.expectRevert(bytes("NenoLend: user insolvent"));
        isolatedLending.borrow(8000e6);
        vm.stopPrank();
    }




}
