const { ethers, upgrades } = require("hardhat");
const {testnet: addresses} = require("../../addresses/d33d")
module.exports = async () => {

    const [deployer] = await ethers.getSigners();
    const { deploy } = deployments

    let BondContract = await ethers.getContractFactory("BondContract", deployer)

 
    /* //Use incase .openzepplin is deleted accidentally
    let Impl = await deploy("BondContract", {
        from: deployer.address
    })

    const proxyAdmin = new ethers.Contract("0xffd653fbaFefdCb1d93A3e28D38396817544FbD5", [
        "function upgrade(address proxy, address implementation) public"
    ], deployer)

    await proxyAdmin.connect(deployer).upgrade("0x054b19e27A131CC11Ba0185B3C36067a379c3C74", Impl.address)
    let bondContract = await ethers.getContractAt("BondContract", "0x054b19e27A131CC11Ba0185B3C36067a379c3C74") 
 */    
    let bondContract = await upgrades.deployProxy(BondContract, [addresses.d33d, addresses.tokens.usdc, addresses.treasury, 
        ethers.constants.AddressZero, addresses.stakingFlexible, deployer.address, deployer.address, addresses.biconomy.forwarder])

    await bondContract.deployed()

    await bondContract.initializeBondTerms(
        1000000, // _controlVariable
        432000,//28800,// _vestingTerm in seconds
        ethers.utils.parseEther("0.8"), // _minimumPrice
        500000000000000, // _maxPayout //3 dcimals // % of totalSupply in 1 tx
        0, // _fee
        "600000000000000000000000000", // _maxDebt
        "0"//_initialDebt
    )

    let Treasury = await ethers.getContractAt("Treasury", addresses.treasury, deployer)

    await Treasury.connect(deployer).toggle(0, bondContract.address, ethers.constants.AddressZero)

  
    console.log("USDC BOND Proxy: ", bondContract.address)
  
  };
  
  
  
  module.exports.tags = ["testnet_deploy_bond_usdc"]
//   module.exports.dependencies = ["mainnet_deploy_bondingCalculator", "mainnet_deploy_d33d", "mainnet_deploy_staking"]
