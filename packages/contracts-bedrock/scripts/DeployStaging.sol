// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { Proxy } from "../contracts/universal/Proxy.sol";
import { ProxyAdmin } from "../contracts/universal/ProxyAdmin.sol";
import "./interfaces/IGnosisSafe.sol";
import "../contracts/L1/OptimismPortal.sol";
import "../contracts/deployment/SystemDictator.sol";

contract TestUpgradeBridgeL1 is Script {
    // todo replace address
    // @notice config L1 side
    ProxyAdmin proxyAdmin = ProxyAdmin(payable(0x9C1b7B02C49F27dFFA61daB94C3B8Ad0Bd4548a6));
    address payable portal = payable(0xC5761216F0f11c8022206E4EB38d5AC319782892);

    // @notice config for L2
    address genesisAccount = address(0x4784B721d0D0aFe9b865C88369d140Fe6f7BC1eb);
    uint mintAmount = 21 * 1e6 * 1e18; // 21 Mil tokens

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("KEY_1");
        vm.startBroadcast(deployerPrivateKey);

        // @notice upgrade for portal contract
        OptimismPortal optimismPortal = OptimismPortal(portal);
        OptimismPortal newOptimismPortal = new OptimismPortal(optimismPortal.L2_ORACLE(), optimismPortal.GUARDIAN(), optimismPortal.paused(),  optimismPortal.SYSTEM_CONFIG(), genesisAccount, mintAmount);
        proxyAdmin.upgrade(portal, address(newOptimismPortal));
        optimismPortal.preMint();

        vm.stopBroadcast();
    }
}
