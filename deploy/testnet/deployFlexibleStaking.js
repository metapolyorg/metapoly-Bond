const { ethers, upgrades } = require("hardhat");
const { testnet: addresses } = require("../../addresses/d33d")
module.exports = async () => {

  const [deployer] = await ethers.getSigners();

  let Staking = await ethers.getContractFactory("Staking", deployer)
  let staking = await upgrades.deployProxy(Staking, [deployer.address, addresses.biconomy.forwarder])
  await staking.deployed()

  let StakingToken = await ethers.getContractFactory("StakingToken", deployer)
  let stakingToken = await upgrades.deployProxy(StakingToken, ["Staking d33d - flexible", "fsD33D", staking.address])
  await stakingToken.deployed()

  let StakingWarmup = await ethers.getContractAt("StakingWarmup", addresses.stakingWarmup, deployer)

  /*     await staking.initialzeStaking(addresses.d33d, stakingToken.address, addresses.distributor, addresses.stakingWarmup, 
          28800, 7368550, //length in seconds(8hrs), firstEpochNumber (same as blockNumber)
          1637761668, 432000,false) //timestampOfFIrstEpoch, lockupPeriodInseconds(5days), isLockedStaking */


  /// DEPLOY gD33D
  let GD33D = await ethers.getContractFactory("gD33D", deployer)
  let gD33D = await upgrades.deployProxy(GD33D, ["Governance D33D", "gD33D", stakingToken.address, staking.address])
  await gD33D.deployed()

  console.log('gD33D', gD33D.address)

  await staking.initialzeStaking(addresses.d33d, stakingToken.address, addresses.distributor, addresses.stakingWarmup,
    28800, 0, //length in seconds(8hrs), firstEpochNumber (same as blockNumber)
    1643126403, 432000, false, addresses.address.DAO, gD33D.address) //startingTimestampOfFIrstEpoch, lockupPeriodInseconds(5 days), isLockedStaking

  await StakingWarmup.connect(deployer).addStakingContract(staking.address)

  let Distributor = await ethers.getContractAt("Distributor", addresses.distributor, deployer)

  await Distributor.connect(deployer).addRecipient(staking.address, stakingToken.address, "2") //0.00002% 4 - decimals

  console.log('fsd33d', stakingToken.address)
  console.log("Flexible Staking Proxy: ", staking.address)

};



module.exports.tags = ["testnet_deploy_flexible-staking"]
// module.exports.dependencies = ["testnet_deploy_distributor", "mainnet_deploy_stakingWarmup"]
//   module.exports.dependencies = ["mainnet_deploy_distributor"]

