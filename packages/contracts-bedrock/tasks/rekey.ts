import {task, types} from 'hardhat/config'
import { hdkey } from 'ethereumjs-wallet'
import * as bip39 from 'bip39'
import {HardhatRuntimeEnvironment} from "hardhat/types";

task('rekey', 'Generates a new set of keys for a test network').setAction(
  async () => {
    const mnemonic = bip39.generateMnemonic()
    const pathPrefix = "m/44'/60'/0'/0"
    const labels = ['Admin', 'Proposer', 'Batcher', 'Sequencer']
    const hdwallet = hdkey.fromMasterSeed(await bip39.mnemonicToSeed(mnemonic))

    console.log(`Mnemonic: ${mnemonic}`)
    for (let i = 0; i < labels.length; i++) {
      const label = labels[i]
      const wallet = hdwallet.derivePath(`${pathPrefix}/${i}`).getWallet()
      const addr = '0x' + wallet.getAddress().toString('hex')
      const pk = wallet.getPrivateKey().toString('hex')

      console.log()
      console.log(`${label}: ${addr}`)
      console.log(`Private Key: ${pk}`)
    }
  }
)

task('l2oo_upgrade', 'upgrade contract')
  .addOptionalParam("from", "from address", "", types.string)
  .addOptionalParam("proxy", "proxy contract address", "", types.string)
  .addOptionalParam("impl", "new implementation contract address", "", types.string)
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { from } = taskArgs;
    const { ethers, deployments } = hre;
    const signer = await ethers.getSigner(from);
    // get ProxyAdmin deployment
    const ProxyAdmin = await deployments.get("ProxyAdmin");
    // get L2OutputOracleProxy
    const L2OutputOracleProxy = await ethers.getContractAt("ProxyAdmin", ProxyAdmin.address, signer);
    // upgrade
    const tx = await L2OutputOracleProxy.upgrade(taskArgs.proxy, taskArgs.impl);
    await tx.wait();
    console.log(tx);
  });
