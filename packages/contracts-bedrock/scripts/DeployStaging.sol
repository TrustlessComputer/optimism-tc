// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { Proxy } from "../contracts/universal/Proxy.sol";
import { ProxyAdmin } from "../contracts/universal/ProxyAdmin.sol";
import "./interfaces/IGnosisSafe.sol";
import "../contracts/L1/OptimismPortal.sol";

contract TestUpgradeBridgeL1 is Script {
    // todo replace address
    // @notice config L1 side
    ProxyAdmin proxyAdmin = ProxyAdmin(payable(0x2a72BC878dF1738c30c2E11900Dc19e7a0C1DbCA));
    IGnosisSafe safeContract = IGnosisSafe(payable(0x0Cf6B283010C308D30425eab9bB088d8EAD7339b));
    address payable portal = payable(0x853bd5FFF6C73D8d6726c7f81BA8bFB00677a26c);

    // @notice config for L2
    address genesisAccount = address(0x1554e0c159364d7f207BfB7Ed0B7Df4c86db011C);
    uint mintAmount = 100 * 1e6 * 1e18; // 100 Mil tokens

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("KEY_1");
        vm.startBroadcast(deployerPrivateKey);

        // @notice upgrade for portal contract
        OptimismPortal optimismPortal = OptimismPortal(portal);
        OptimismPortal newOptimismPortal = new OptimismPortal(optimismPortal.L2_ORACLE(), optimismPortal.GUARDIAN(), optimismPortal.paused(),  optimismPortal.SYSTEM_CONFIG());
        bytes memory txData = abi.encodeWithSelector(ProxyAdmin.upgrade.selector, portal, newOptimismPortal);
        bytes memory signatures = abi.encode(vm.addr(deployerPrivateKey), address(0));
        signatures = abi.encodePacked(signatures, uint8(1));
        safeContract.execTransaction(
            address(proxyAdmin),
            0,
            txData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signatures
        );

        vm.stopBroadcast();
    }
}
