//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralisedStableCoin} from "../../src/DecentralisedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralisedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant PRECISION = 1e18;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    /////////////* constructor tests *///////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////* Price feed tests *///////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;

        // 15e18 * 2000/ETH = 30000
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);

        assertEq(actualUsd, expectedUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /////////////* Deposit collateral tests *///////////

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL - 5);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testRevertIfHealthFactorIsBroken() public depositedCollateral {
        uint256 collateralValueInUsd = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 maxDsc = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 amountToMint = maxDsc + 1;

        //calculating the health factor:
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 expectedHealthFactor = (collateralAdjustedForThreshold * PRECISION) / amountToMint;

        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreakHealthFactor.selector, expectedHealthFactor));
        dsce.mintDSC(amountToMint);
        vm.stopPrank();
    }

    /////////////* Minting DSC tests *///////////

    function testMintingDscWithValidCollateral() public {
        uint256 collateralValueInUsd = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 minDsc = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 amountDScToMint = minDsc - 1;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, amountDScToMint);
        vm.stopPrank();

        //verifing the minting worked
        uint256 userDscBalance = dsc.balanceOf(USER);
        assertEq(userDscBalance, amountDScToMint);

        //checking the minted amount is recorded in the engine
        (uint256 mintedAmount,) = dsce.getAccountInformation(USER);
        assertEq(mintedAmount, amountDScToMint);
    }

    /////////////* Burning DSC tests *///////////
    function testBurningDsc() public {
        uint256 collateralValueInUsd = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 minDsc = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 amountDScToMint = minDsc - 1;
        vm.startPrank(USER);
        //minting
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, amountDScToMint);

        //burning
        ERC20Mock(address(dsc)).approve(address(dsce), amountDScToMint);
        uint256 amountToburn = amountDScToMint / 2; //burns half of the dsc minted.
        dsce.burnDSC(amountToburn);
        vm.stopPrank();

        uint256 userDscBalance = dsc.balanceOf(USER);
        assertEq(userDscBalance, amountDScToMint - amountToburn);
    }

    function testBurningZeroDscReverts() public {
        uint256 collateralValueInUsd = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 minDsc = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 amountDScToMint = minDsc - 1;
        vm.startPrank(USER);
        //minting
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, amountDScToMint);

        //burning
        ERC20Mock(address(dsc)).approve(address(dsce), amountDScToMint);
        uint256 amountToburn = amountDScToMint - amountDScToMint; //burns 0 dsc
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDSC(amountToburn);
        vm.stopPrank();
    }

    /////////////* Redeeming DSC tests *///////////

    function testRedeemCollateralAndBurnDsc() public {
        uint256 collateralValueInUsd = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 maxDsc = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 amountDScToMint = maxDsc / 2;

        //minting
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, amountDScToMint);

        //verify mint
        uint256 userDscBalanceAfterMint = dsc.balanceOf(USER);
        assertEq(userDscBalanceAfterMint, amountDScToMint);

        //redemption setup
        ERC20Mock(address(dsc)).approve(address(dsce), amountDScToMint);

        //balances before redemption
        uint256 wethBalanceBefore = ERC20Mock(weth).balanceOf(USER);
        uint256 dscBalanceBefore = dsc.balanceOf(USER);

        uint256 amountCollateralToRedeem = AMOUNT_COLLATERAL / 2;
        uint256 amountDScToBurn = amountDScToMint / 2;
        dsce.redeemCollateralForDSC(weth, amountCollateralToRedeem, amountDScToBurn);

        //verifying final balances
        uint256 wethBalanceAfter = ERC20Mock(weth).balanceOf(USER);
        uint256 dscBalanceAfter = dsc.balanceOf(USER);

        //weth bal should increase after
        assertEq(wethBalanceAfter, wethBalanceBefore + amountCollateralToRedeem);
        assertEq(dscBalanceAfter, dscBalanceBefore - amountDScToBurn);
        vm.stopPrank();
    }
}
