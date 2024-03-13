// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Proxy } from "../contracts/universal/Proxy.sol";
import { ProxyAdmin } from "../contracts/universal/ProxyAdmin.sol";
import "./interfaces/IGnosisSafe.sol";
import "../contracts/L1/OptimismPortal.sol";
import "../contracts/L1/extensions/OptimismPortalBlockNativeMint.sol";
import "../contracts/deployment/SystemDictator.sol";
import { SequencerFeeVaultWithdrawOnL2 } from "../contracts/L2/extensions/L1FeeVaultWithdrawOnL2.sol";

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

contract TestUpgradeVaultSequenceFeeL2Script is Script {

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address payable recipient = payable(vm.envAddress("RECIPIENT"));
        address payable sequencerFeeVault = payable(0x4200000000000000000000000000000000000011);

        SequencerFeeVaultWithdrawOnL2 newSF = new SequencerFeeVaultWithdrawOnL2(recipient);
        ProxyAdmin tmp = ProxyAdmin(payable(0x4200000000000000000000000000000000000018));
        console.log("proxy admin owner %s",tmp.owner());

        tmp.upgrade(sequencerFeeVault, address(newSF));
        require(newSF.MIN_WITHDRAWAL_AMOUNT() == 1, "invalid min amount withdraw");

        // toto: uncomment this to test
        //        console.log(sequencerFeeVault.balance);
        //        console.log(recipient.balance);
        //        SequencerFeeVaultWithdrawOnL2(sequencerFeeVault).withdraw();
        //        console.log(recipient.balance);
        //        console.log(sequencerFeeVault.balance);
        //        require(sequencerFeeVault.balance == 0, "balance must be zero");

        vm.stopBroadcast();
    }
}
