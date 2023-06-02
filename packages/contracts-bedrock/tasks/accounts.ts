import { task, types } from 'hardhat/config'
import '@nomiclabs/hardhat-ethers'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

task('accounts', 'Prints the list of accounts', async (_, hre) => {
  const accounts = await hre.ethers.getSigners()

  for (const account of accounts) {
    console.log(account.address)
  }
})

task('sendtx', 'send tx using data')
  .addOptionalParam("from", "from address", "", types.string)
  .addOptionalParam("to", "to address", "", types.string)
  .addOptionalParam("data", "data", "", types.string)
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { from, to, data } = taskArgs;
    const signer = await hre.ethers.getSigner(from);
    const tx = await signer.sendTransaction({
      to,
      data,
      // gasLimit: 10000000
    })
    await tx.wait();
    console.log(tx)
  });