// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import "src/DSCEngine.sol";

abstract contract DSCEngineTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function dSCEngine_burnDSC(uint256 amount) public asActor {
        dSCEngine.burnDSC(amount);
    }

    function dSCEngine_depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) public asActor {
        dSCEngine.depositCollateral(tokenCollateralAddress, amountCollateral);
    }

    function dSCEngine_depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) public asActor {
        dSCEngine.depositCollateralAndMintDSC(tokenCollateralAddress, amountCollateral, amountDscToMint);
    }

    function dSCEngine_liquidate(address collateral, address user, uint256 debtToCover) public asActor {
        dSCEngine.liquidate(collateral, user, debtToCover);
    }

    function dSCEngine_mintDSC(uint256 amountDscToMint) public asActor {
        dSCEngine.mintDSC(amountDscToMint);
    }

    function dSCEngine_redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public asActor {
        dSCEngine.redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    function dSCEngine_redeemCollateralForDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    ) public asActor {
        dSCEngine.redeemCollateralForDSC(tokenCollateralAddress, amountCollateral, amountDscToBurn);
    }
}
