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

contract IsolatedLendingV01Test is Test {
    MockERC20 public usdc;
    MockERC20 public bct;

    IsolatedLendingV01 public isolatedLending;
    IStrat public moobeftmStrategy;

    address public Borrower1 = address(0xdb9d281C3D29bAa9587f5dAC99DD982156913913);
    address public Borrower2 = address(0x3);
    address public Lender1 = address(0x4);
    address public Lender2 = address(0x5);
    address public Liquidator1 = address(0x6);
    address public Liquidator2 = address(0x7);

    function setUp() public {
        usdc = new MockERC20("usdc", "USDC", 6);
        bct = new MockERC20("bct", "BCT", 18);
        // moobeftm = IBeefyVault(0x185647c55633A5706aAA3278132537565c925078);
        // moobeftmStrategy= IStrat(0x2dc8683F752305659ff7F97A7CB4291B1c0Df37b);

        // isolatedLending = new IsolatedLendingV01(wftm, address(beftm), "neRupiahbeftm vault", "wftm/beftm");
        isolatedLending = new IsolatedLendingV01(address(usdc), address(bct), "USDCBCT vault", "USDC/BCT");


        vm.startPrank(Lender1);
        usdc.mint(50000e6);
        vm.stopPrank();

        vm.startPrank(Lender2);
        usdc.mint(100000e6);
        vm.stopPrank();

    //     vm.startPrank(Borrower1);
    //     beftm.mint(10000e18);
    //     vm.stopPrank();

    //     vm.startPrank(Borrower2);
    //     beftm.mint(20000e18);
    //     vm.stopPrank();

    //     vm.startPrank(Liquidator1);
    //     wftm.mint(500000e18);
    //     vm.stopPrank();

    //     vm.startPrank(Liquidator2);
    //     wftm.mint(500000e18);
    //     vm.stopPrank();
    // }
    }

    // function testSetUp() public{
    //     console.log(moobeftm.balanceOf(address(Borrower1)));
    //     console.log("moobeFTM vault share price: %s", moobeftm.getPricePerFullShare()); //beFTM/moobeFTM
    //     console.log("moobeFTM/FTM: %s", isolatedLending.exchangeRate()); // moobeFTM/FTM exchangerate
    //     assertGt(moobeftm.balanceOf(address(Borrower1)), 1e18);

    //     vm.warp(block.timestamp+7889229);
    //     moobeftmStrategy.harvest();
    //     isolatedLending.updateExchangeRate();

    //     console.log("moobeFTM vault share price: %s", moobeftm.getPricePerFullShare()); //beFTM/moobeFTM
    //     console.log("moobeFTM/FTM: %s", isolatedLending.exchangeRate()); // moobeFTM/FTM exchangerate

    // } 

    // function testAddAndRemoveAsset() public{
    //     vm.startPrank(Lender1);
    //     usdc.approve(address(isolatedLending), 50000e6);
    //     isolatedLending.addAsset(50000e6);
    //     vm.stopPrank();
    //     assertEq(isolatedLending.balanceOf(address(Lender1)), 50000e6);

    //     vm.startPrank(Lender1);
    //     // isolatedLending.approve(address(isolatedLending), 50000e6);
    //     usdc.removeAsset(50000e6);
    //     vm.stopPrank();
    //     assertEq(isolatedLending.balanceOf(address(Lender1)), 0);
    // }

    // function testAddAndRemoveCollateral() public {
    //     vm.startPrank(Borrower1);
    //     moobeftm.approve(address(isolatedLending), 1e18);
    //     isolatedLending.addCollateral(1e18);
    //     vm.stopPrank();
    //     assertEq(isolatedLending.userCollateralAmount(address(Borrower1)), 1e18);
    //     console.log(isolatedLending.userCollateralValue(address(Borrower1)));

    //     vm.startPrank(Borrower1);
    //     moobeftm.approve(address(isolatedLending), 1);
    //     isolatedLending.removeCollateral(1e18);
    //     vm.stopPrank();
    //     assertEq(isolatedLending.userCollateralAmount(address(Borrower1)), 0);
    // }

}