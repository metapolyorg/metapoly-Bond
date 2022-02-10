const { ethers, upgrades } = require("hardhat");
const {testnet: addresses} = require("../../addresses/d33d")

const signer = "0xEe555465f4B44a7aFF2d0de1eFA86BeD9037E147"

module.exports = async () => {

    const [deployer] = await ethers.getSigners();

    let PD33D = await ethers.getContractFactory("pD33D", deployer)

    let pD33D = await upgrades.deployProxy(PD33D, [ethers.utils.parseEther("10000")])

    await pD33D.deployed()
  
    console.log("pD33D token Proxy: ", pD33D.address)

    let PD33DRedeemer = await ethers.getContractFactory("pD33DRedeemer", deployer)
    
    let pD33DRedeemer = await upgrades.deployProxy(PD33DRedeemer, [addresses.d33d, pD33D.address, signer])

    await pD33DRedeemer.deployed()

    await pD33D.setRedeemer(pD33DRedeemer.address)

    let treasury = await ethers.getContractAt("Treasury", addresses.treasury)
    await pD33DRedeemer.setTreasury(treasury.address)
    await treasury.connect(deployer).toggle(0, pD33DRedeemer.address, ethers.constants.AddressZero)

    console.log("pD33DRedeemer", pD33DRedeemer.address)
  
  };
  
  
  
  module.exports.tags = ["testnet_deploy_pd33d"]