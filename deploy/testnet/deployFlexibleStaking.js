const { ethers, upgrades } = require("hardhat");
const { testnet: addresses } = require("../../addresses/d33d")
module.exports = async () => {

  const [deployer] = await ethers.getSigners();

  let Staking = await ethers.getContractFactory("Staking", deployer)
  let staking = await upgrades.deployProxy(Staking, [deployer.address, addresses.biconomy.forwarder,
    addresses.USM.USM, ethers.utils.parseEther("5000")])
  await staking.deployed()
  console.log("staking", staking.address)


  let StakingToken = await ethers.getContractFactory("StakingToken", deployer)
  let stakingToken = await upgrades.deployProxy(StakingToken, ["Staking d33d", "sD33D", staking.address])
  await stakingToken.deployed()
  console.log("stakingToken", stakingToken.address)


  let VD33D = await ethers.getContractFactory("VD33D", deployer)
  let vD33D = await upgrades.deployProxy(VD33D, ["Voting D33D", "vD33D", deployer.address])
  await vD33D.deployed()
  console.log("vD33D", vD33D.address)

  await vD33D.setAuthorised(staking.address, true)

  let StakingWarmup = await ethers.getContractAt("StakingWarmup", addresses.stakingWarmup, deployer)


  await staking.initialzeStaking(addresses.d33d, stakingToken.address, addresses.distributor, addresses.stakingWarmup,
    28800, 0, //length in seconds(8hrs), firstEpochNumber (same as blockNumber)
    1646899211, addresses.address.DAO, addresses.USM.USMMinter, vD33D.address) //startingTimestampOfFIrstEpoch, lockupPeriodInseconds(5 days), isLockedStaking


  await StakingWarmup.connect(deployer).addStakingContract(staking.address)

  let Distributor = await ethers.getContractAt("Distributor", addresses.distributor, deployer)

  await Distributor.connect(deployer).addRecipient(staking.address, stakingToken.address, "10") //2 == 0.00002% 4 - decimals

  // console.log('fsd33d', stakingToken.address)
  // console.log("Staking Proxy: ", staking.address)

};



module.exports.tags = ["testnet_deploy_flexible-staking"]
// module.exports.dependencies = ["testnet_deploy_distributor", "mainnet_deploy_stakingWarmup"]
//   module.exports.dependencies = ["mainnet_deploy_distributor"]

