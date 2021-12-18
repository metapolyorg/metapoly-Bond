const { ethers, upgrades } = require("hardhat");

module.exports = async () => {

    const [deployer] = await ethers.getSigners();

    let StakingWarmup = await ethers.getContractFactory("StakingWarmup", deployer)

    let stakingWarmup = await upgrades.deployProxy(StakingWarmup, [deployer.address])
    await stakingWarmup.deployed()
  
    console.log("stakingWarmup Proxy: ", stakingWarmup.address)
  
  };
  
  
  
  module.exports.tags = ["testnet_deploy_stakingWarmup"]