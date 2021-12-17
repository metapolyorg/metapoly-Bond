const { ethers, upgrades } = require("hardhat");
const {mainnet: addresses} = require("../../addresses/d33d")
module.exports = async () => {

    const [deployer] = await ethers.getSigners();

    let D33D = await ethers.getContractFactory("D33DImplementation", deployer)

    let d33d = await upgrades.deployProxy(D33D, ["MetaPoly", "D33D"])

    await d33d.deployed()
  
    console.log("D33D token Proxy: ", d33d.address)
  
  };
  
  
  
  module.exports.tags = ["mainnet_deploy_D33D"]