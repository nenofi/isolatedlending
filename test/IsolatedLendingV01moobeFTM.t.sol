// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/test/MockERC20.sol";
import "../src/IsolatedLendingV01.sol";

interface IStrat{
    function harvest() external;
}

// interface IBeefyVault{
//     function balanceOf(address account) external view returns (uint256);
//     function deposit(uint256 amount) external;
//     function _mint(uint256 amount) external;
//     function getPricePerFullShare() external view returns (uint256);
//     function totalSupply() external view returns (uint256);
//     function approve(address spender, uint256 amount) external returns (bool);
//     function transferFrom(
//         address from,
//         address to,
//         uint256 amount
//     ) external returns (bool);
// }

contract IsolatedLendingV01moobeFTMTest is Test {
    MockERC20 public wftm;
    IBeefyVault public moobeftm;

    IsolatedLendingV01 public isolatedLending;
    IStrat public moobeftmStrategy;

    address public Borrower1 = address(0xdb9d281C3D29bAa9587f5dAC99DD982156913913);
    address public Borrower2 = address(0x066188948681D38F88441a80E3823dd41155211C);
    address public Lender1 = address(0x4);
    address public Lender2 = address(0x5);
    address public Liquidator1 = address(0x6);
    address public Liquidator2 = address(0x7);

    function setUp() public {
        wftm = new MockERC20("wftm", "WFTM", 18);
        moobeftm = IBeefyVault(0x185647c55633A5706aAA3278132537565c925078);
        moobeftmStrategy= IStrat(0x2dc8683F752305659ff7F97A7CB4291B1c0Df37b);

        // isolatedLending = new IsolatedLendingV01(wftm, address(beftm), "neRupiahbeftm vault", "wftm/beftm");
        isolatedLending = new IsolatedLendingV01(address(wftm), address(moobeftm), "wFTMmoobeFTM vault", "wFTM/moobeFTM");


        vm.startPrank(Lender1);
        wftm.mint(100000e18);
        // beftm.mint(50000e6);
        vm.stopPrank();

        vm.startPrank(Lender2);
        wftm.mint(100000e18);
        // beftm.mint(100000e6);
        vm.stopPrank();

        vm.startPrank(Borrower1);
        wftm.mint(100000e18);
        // beftm.mint(50000e6);
        vm.stopPrank();

        vm.startPrank(Borrower2);
        wftm.mint(100000e18);
        // beftm.mint(100000e6);
        vm.stopPrank();

        vm.startPrank(Liquidator1);
        wftm.mint(500000e18);
        vm.stopPrank();

        vm.startPrank(Liquidator2);
        wftm.mint(500000e18);
        vm.stopPrank();
    }

    function testSetUp() public{
        // console.log(moobeftm.balanceOf(address(Borrower1)));
        console.log("moobeFTM vault share price: %s", moobeftm.getPricePerFullShare()); //beFTM/moobeFTM
        console.log("moobeFTM/FTM: %s", isolatedLending.exchangeRate()); // moobeFTM/FTM exchangerate
        assertGt(moobeftm.balanceOf(address(Borrower1)), 1e18);

        vm.warp(block.timestamp+7889229);
        moobeftmStrategy.harvest();
        isolatedLending.updateExchangeRate();

        console.log("moobeFTM vault share price: %s", moobeftm.getPricePerFullShare()); //beFTM/moobeFTM
        console.log("moobeFTM/FTM: %s", isolatedLending.exchangeRate()); // moobeFTM/FTM exchangerate

    } 

    function testAddAndRemoveAsset() public{
        vm.startPrank(Lender1);
        wftm.approve(address(isolatedLending), 100000e18);
        isolatedLending.addAsset(100000e18);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 100000e18);

        vm.startPrank(Lender1);
        isolatedLending.approve(address(isolatedLending), 1000000e18);
        isolatedLending.removeAsset(100000e18);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 0);
    }

    function testAddAndRemoveCollateral() public {
        vm.startPrank(Borrower1);
        moobeftm.approve(address(isolatedLending), 1e18);
        isolatedLending.addCollateral(1e18);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Borrower1)), 1e18);
        // console.log(isolatedLending.userCollateralValue(address(Borrower1)));

        vm.startPrank(Borrower1);
        isolatedLending.removeCollateral(1e18);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Borrower1)), 0);
    }

    function testBorrow() public {
        vm.startPrank(Lender1);
        wftm.approve(address(isolatedLending), 100000e18);
        isolatedLending.addAsset(100000e18);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 100000e18);

        vm.startPrank(Borrower1);
        moobeftm.approve(address(isolatedLending), 100e18);
        isolatedLending.addCollateral(100e18);
        console.log("Borrower collateral value (ftm): %s",isolatedLending.userCollateralValue(address(Borrower1)));
        console.log("Available ftm to borrow: %s",isolatedLending.userCollateralValue(address(Borrower1))*60/100);


        isolatedLending.borrow(50e18);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Borrower1)), 100e18);
        assertEq(isolatedLending.isSolvent(address(Borrower1)), true);
    }

    function testMultipleBorrowAndRepay() public {
        vm.startPrank(Lender1);
        wftm.approve(address(isolatedLending), 100000e18);
        isolatedLending.addAsset(100000e18);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 100000e18);

        uint256 startingTotalAssets = isolatedLending.totalAssets();

        vm.startPrank(Borrower1);
        moobeftm.approve(address(isolatedLending), 10000e18);
        isolatedLending.addCollateral(10000e18);
        isolatedLending.borrow(5000e18);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Borrower1)), 10000e18);
        assertEq(wftm.balanceOf(address(Borrower1)), 105000000000000000000000);

        vm.startPrank(Borrower2);
        moobeftm.approve(address(isolatedLending), 5000e18);
        isolatedLending.addCollateral(5000e18);
        isolatedLending.borrow(2500e18);
        vm.stopPrank();
        assertEq(isolatedLending.userCollateralAmount(address(Borrower2)), 5000e18);
        assertEq(wftm.balanceOf(address(Borrower2)), 102500000000000000000000);
        
        assertGt(isolatedLending.totalAmountBorrowed(address(Borrower1)), 5000e18);
        assertGt(isolatedLending.totalAmountBorrowed(address(Borrower2)), 2500e18);

        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();
        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();
        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();

        assertGt(isolatedLending.totalAmountBorrowed(address(Borrower1)), 5010e18);
        assertGt(isolatedLending.totalAmountBorrowed(address(Borrower2)), 2505e18);
        assertGt(isolatedLending.convertToAssets(isolatedLending.balanceOf(address(Lender1))), isolatedLending.balanceOf(address(Lender1)));

        // console.log(isolatedLending.totalAmountBorrowed(address(Borrower1)));
        // console.log(isolatedLending.totalAmountBorrowed(address(Borrower2)));
        // console.log("total amt borrowed: %s",isolatedLending.totalBorrow()); 
        console.log("protocol fee (ftm): %s", isolatedLending.convertToAssets(isolatedLending.balanceOf(address(this)))); 
        // console.log("lender balance: %s", isolatedLending.convertToAssets(isolatedLending.balanceOf(address(Lender1)))); 


        vm.startPrank(Borrower1);
        wftm.approve(address(isolatedLending), 6000e18);
        isolatedLending.repay(5028398062744791637184);
        vm.stopPrank();

        vm.startPrank(Borrower2);
        wftm.approve(address(isolatedLending), 2600e18);
        isolatedLending.repay(2512942560092349643770);
        vm.stopPrank();
        assertLt(isolatedLending.totalAmountBorrowed(address(Borrower1)), 5000e18);
        assertLt(isolatedLending.totalAmountBorrowed(address(Borrower2)), 2500e18);
        assertGt(isolatedLending.totalAssets(), startingTotalAssets);

    }

    function testInterestRateInsolvency() public {
        vm.startPrank(Lender1);
        wftm.approve(address(isolatedLending), 6500e18);
        isolatedLending.addAsset(6500e18);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 6500e18);

        vm.startPrank(Borrower1);
        moobeftm.approve(address(isolatedLending), 11000e18);
        isolatedLending.addCollateral(11000e18);
        isolatedLending.borrow(5500e18);
        vm.stopPrank();
        assertEq(isolatedLending.isSolvent(Borrower1), true);


        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();
        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();
        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();

        assertEq(isolatedLending.isSolvent(Borrower1), false);

    }

    function testLiquidate() public {
        vm.startPrank(Lender1);
        wftm.approve(address(isolatedLending), 6500e18);
        isolatedLending.addAsset(6500e18);
        vm.stopPrank();
        assertEq(isolatedLending.balanceOf(address(Lender1)), 6500e18);

        vm.startPrank(Borrower1);
        moobeftm.approve(address(isolatedLending), 11000e18);
        isolatedLending.addCollateral(11000e18);
        isolatedLending.borrow(5350e18);
        vm.stopPrank();
        assertEq(isolatedLending.isSolvent(Borrower1), true);
        console.log("START BORROW");
        console.log("user col val: %s", isolatedLending.userCollateralValue(address(Borrower1)));
        console.log("user max borrow: %s", isolatedLending.userCollateralValue(address(Borrower1))*60/100);
        console.log("user borrow: %s", isolatedLending.totalAmountBorrowed(address(Borrower1)));

        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();
        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();
        vm.warp(block.timestamp+10518975);
        isolatedLending.accrue();

        console.log("INSOLVENT");
        console.log("user col val: %s", isolatedLending.userCollateralValue(address(Borrower1)));
        console.log("user max borrow: %s", isolatedLending.userCollateralValue(address(Borrower1))*60/100);
        console.log("user borrow: %s", isolatedLending.totalAmountBorrowed(address(Borrower1)));

        // isolatedLending.updateExchangeRate();
        assertEq(isolatedLending.isSolvent(Borrower1), false);
        
        vm.startPrank(Liquidator1);
        wftm.approve(address(isolatedLending), 10000e18);
        isolatedLending.liquidate(Borrower1, 6308500826112756608831);
        vm.stopPrank();

        console.log("LIQUIDATED");
        console.log("user col val: %s", isolatedLending.userCollateralValue(address(Borrower1)));
        console.log("user max borrow: %s", isolatedLending.userCollateralValue(address(Borrower1))*60/100);
        console.log("user borrow: %s", isolatedLending.totalAmountBorrowed(address(Borrower1)));

        console.log(moobeftm.balanceOf(Liquidator1)*moobeftm.getPricePerFullShare()/1e18);

        // // assertEq(wBTC.balanceOf(address(Liquidator1)), 40267223);
        assertEq(isolatedLending.isSolvent(Borrower1), true);
        // console.log("user col val: %s", isolatedLending.userCollateralValue(address(Borrower1)));
        // console.log("user max borrow: %s", isolatedLending.userCollateralValue(address(Borrower1))*75/100);
        // console.log("user borrow: %s", isolatedLending.totalAmountBorrowed(address(Borrower1)));

    }


}