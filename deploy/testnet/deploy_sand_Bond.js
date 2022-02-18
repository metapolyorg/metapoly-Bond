const { ethers, upgrades } = require("hardhat");
const {testnet: addresses} = require("../../addresses/d33d")
module.exports = async () => {

    const [deployer] = await ethers.getSigners();

    let BondingCalculator = await ethers.getContractFactory("BondingCalculatorSAND", deployer)

    let bondingCalculator = await upgrades.deployProxy(BondingCalculator, ["5000", deployer.address, addresses.oracle.SAND.address])

    // let bondingCalculator = await upgrades.upgradeProxy("0x8c29fdb14d02bc08b8b359388a65c1def74d02c7",BondingCalculator)
    await bondingCalculator.deployed()
  
    console.log("BondingCalculator SAND Proxy: ", bondingCalculator.address)

    let BondContract = await ethers.getContractFactory("BondContractLP", deployer)
    // let bondingCalculator = await upgrades.upgradeProxy("0x1E71bc7b01F92D2850f825fC68905edEC33ccB6c",BondContract, {unsafeAllowRenames: true})

    let bondContract = await upgrades.deployProxy(BondContract, [addresses.d33d, addresses.tokens.sand, addresses.treasury, 
        bondingCalculator.address, addresses.stakingFlexible, deployer.address, deployer.address])

    await bondContract.deployed()

    await bondContract.initializeBondTerms(
        800000, // _controlVariable
        432000,//28800,// _vestingTerm in seconds
        ethers.utils.parseEther("0.8334"), // _minimumPrice //1 cesta = 0.029 mana
        500000000000000, // _maxPayout //3 dcimals // % of totalSupply in 1 tx
        0, // _fee
        "600000000000000000000000000", // _maxDebt
        "0"//_initialDebt
    )

    let Treasury = await ethers.getContractAt("Treasury", addresses.treasury, deployer)


    await Treasury.connect(deployer).toggle(4, bondContract.address, bondingCalculator.address) //liquidiyDepositor
    await Treasury.connect(deployer).toggle(5, addresses.tokens.sand, bondingCalculator.address) //liquidityToken

    console.log("SAND BOND Proxy: ", bondContract.address)
  
  };
  
  
  
  module.exports.tags = ["testnet_deploy_bond_sand"]
//   module.exports.dependencies = ["mainnet_deploy_bondingCalculator", "mainnet_deploy_cesta", "mainnet_deploy_staking"]
