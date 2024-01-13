// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { Proxy } from "../contracts/universal/Proxy.sol";
import { ProxyAdmin } from "../contracts/universal/ProxyAdmin.sol";
import "./interfaces/IGnosisSafe.sol";
import "../contracts/L1/OptimismPortal.sol";
import "../contracts/L1/extensions/OptimismPortalBlockNativeMint.sol";
import "../contracts/deployment/SystemDictator.sol";

contract TestUpgradeBridgeL1 is Script {
    // todo replace address
    // @notice config L1 side
    ProxyAdmin proxyAdmin = ProxyAdmin(payable(vm.envAddress("PROXY_ADMIN")));
    address payable portal = payable(vm.envAddress("PORTAL"));

    // @notice config for L2
    address genesisAccount = vm.envAddress("GENESIS_ACCOUNT");
    uint mintAmount = vm.envUint("GENESIS_AMOUNT");

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // @notice upgrade for portal contract
        OptimismPortal optimismPortal = OptimismPortal(portal);
        OptimismPortalBlockNativeMint newOptimismPortal = new OptimismPortalBlockNativeMint(optimismPortal.L2_ORACLE(), optimismPortal.GUARDIAN(), optimismPortal.paused(),  optimismPortal.SYSTEM_CONFIG(), genesisAccount, mintAmount);
        proxyAdmin.upgrade(portal, address(newOptimismPortal));
        OptimismPortalBlockNativeMint(portal).preMint();

        vm.stopBroadcast();
    }
}
