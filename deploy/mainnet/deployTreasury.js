const { ethers, upgrades} = require("hardhat");
const {mainnet: addresses} = require("../../addresses/d33d")

module.exports = async ({deployments}) => {

    let {deploy, catchUnknownSigner} = deployments

    const [deployer] = await ethers.getSigners();

    let Treasury = await ethers.getContractFactory("Treasury", deployer)

    let treasury = await upgrades.deployProxy(Treasury, [addresses.d33d, addresses.tokens.dai, deployer.address,
      ethers.utils.parseUnits("1", "17") //0.1 USD per d33d
    ])

    await treasury.deployed()

    let D33D = await ethers.getContractAt("D33DImplementation", addresses.d33d, deployer)

    await D33D.setTreasury(treasury.address)

  
    console.log("Treasury Proxy: ", treasury.address)

  };
  
  
  
  module.exports.tags = ["mainnet_deploy_treasury"]

  module.exports.dependencies = ["mainnet_deploy_d33d"]