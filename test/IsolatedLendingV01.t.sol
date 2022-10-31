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
        vm.startPrank(Bob);
        neIDR.mint(10000000e18);
        vm.stopPrank();
        vm.startPrank(Alice);
        usdt.mint(1000e6);
        vm.stopPrank();
    }

    function testAddAsset() public {
        vm.startPrank(Bob);
        // neIDR.mint(10000000e18);
        neIDR.approve(address(isolatedLending), 10000000e18);
        isolatedLending.addAsset(10000000e18);
        vm.stopPrank();
        // console.log(isolatedLending.balanceOf(address(Bob)));
        assertEq(isolatedLending.balanceOf(address(Bob)), 10000000e18);
    }

    function testAddCollateral() public {
        vm.startPrank(Alice);
        // usdt.mint(1000e6);
        usdt.approve(address(isolatedLending), 1000e6);
        isolatedLending.addCollateral(1000e6);
        console.log(isolatedLending.userCollateralAmount(address(Alice))/1e6);
        vm.stopPrank();
        // assertEq(isolatedLending.balanceOf(address(Bob)), 10000000e18);
        // vm.startPrank(Alice);
        // isolatedLending.borrow(1000000e18);
        // vm.stopPrank();
        // console.log(isolatedLending.userBorrowAmount(address(Alice))/1e18);
        // console.log(isolatedLending.convertToAssets(isolatedLending.balanceOf(address(Bob)))/1e18);
    }

    function testAddAliceBorrow() public {
        vm.startPrank(Bob);
        neIDR.mint(10000000e18);
        neIDR.approve(address(isolatedLending), 10000000e18);
        isolatedLending.addAsset(10000000e18);
        // console.log(isolatedLending.balanceOf(address(Bob))/1e18);
        vm.stopPrank();
        // assertEq(isolatedLending.balanceOf(address(Bob)), 10000000e18);
        vm.startPrank(Alice);
        isolatedLending.borrow(1000000e18);
        vm.stopPrank();
        // console.log(isolatedLending.userBorrowAmount(address(Alice))/1e18);
        // console.log(isolatedLending.totalBorrow()/1e18);
        vm.warp(block.timestamp + 500000);
        isolatedLending.accrue();
        // console.log(isolatedLending.userBorrowAmount(address(Alice))/1e18);
        // console.log(isolatedLending.totalBorrow()/1e18);
        console.log(isolatedLending.totalBorrow());
        console.log(isolatedLending.getUserBorrowAmount(address(Alice)));

        // console.log(isolatedLending.convertToAssets(isolatedLending.balanceOf(address(Bob)))/1e18);
    }


}
