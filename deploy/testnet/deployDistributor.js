const { ethers, upgrades } = require("hardhat");
const {testnet: addresses} = require("../../addresses/d33d")
module.exports = async () => {

    const [deployer] = await ethers.getSigners();

    let Distributor = await ethers.getContractFactory("Distributor", deployer)

    //end of first epoch time
    let distributor = await upgrades.deployProxy(Distributor, [addresses.d33d, addresses.treasury, "28800", "1643155203", deployer.address])

    await distributor.deployed()

    let Treasury = await ethers.getContractAt("Treasury", addresses.treasury, deployer)
  
    await Treasury.connect(deployer).toggle("7", distributor.address, ethers.constants.AddressZero)
    console.log("Distributor Proxy: ", distributor.address)
  
  };
    
  module.exports.tags = ["testnet_deploy_distributor"]

  // module.exports.dependencies = ["mainnet_deploy_treasury"]