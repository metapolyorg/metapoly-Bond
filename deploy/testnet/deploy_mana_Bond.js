const { ethers, upgrades } = require("hardhat");
const {testnet: addresses} = require("../../addresses/d33d")
module.exports = async () => {

    const [deployer] = await ethers.getSigners();
    const { deploy } = deployments

    let BondingCalculator = await ethers.getContractFactory("BondingCalculatorMANA", deployer)

    let bondingCalculator = await upgrades.deployProxy(BondingCalculator, ["5000", deployer.address,
        addresses.oracle.MANA.MANA_ETH, addresses.oracle.MANA.ETH_USD])

    await bondingCalculator.deployed()
  
    console.log("BondingCalculator MANA Proxy: ", bondingCalculator.address)

    let BondContract = await ethers.getContractFactory("BondContractLP", deployer)

    let bondContract = await upgrades.deployProxy(BondContract, [addresses.d33d, addresses.tokens.mana, addresses.treasury, 
        bondingCalculator.address, addresses.stakingFlexible, deployer.address, deployer.address, addresses.biconomy.forwarder])

    await bondContract.deployed()

    await bondContract.initializeBondTerms(
        1000000, // _controlVariable
        432000,//28800,// _vestingTerm in seconds
        ethers.utils.parseEther("0.029"), // _minimumPrice //1 cesta = 0.029 mana
        500000000000000, // _maxPayout //3 dcimals // % of totalSupply in 1 tx
        0, // _fee
        "600000000000000000000000000", // _maxDebt
        "0"//_initialDebt
    )

    let Treasury = await ethers.getContractAt("Treasury", addresses.treasury, deployer)


    await Treasury.connect(deployer).toggle(4, bondContract.address, bondingCalculator.address) //liquidiyDepositor
    await Treasury.connect(deployer).toggle(5, addresses.tokens.mana, bondingCalculator.address) //liquidityToken

    console.log("MANA BOND Proxy: ", bondContract.address)
  
  };
  
  
  
  module.exports.tags = ["testnet_deploy_bond_mana"]
//   module.exports.dependencies = ["mainnet_deploy_bondingCalculator", "mainnet_deploy_cesta", "mainnet_deploy_staking"]
