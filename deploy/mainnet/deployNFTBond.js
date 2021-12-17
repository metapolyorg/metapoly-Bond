const { ethers, upgrades } = require("hardhat");
const {mainnet: addresses} = require("../../addresses/d33d")
module.exports = async () => {

    const [deployer] = await ethers.getSigners();

    let BondContract = await ethers.getContractFactory("NFTBond", deployer)

    let bondContract = await upgrades.deployProxy(BondContract, [addresses.d33d, addresses.NFT.LAND, addresses.treasury, 
        ethers.constants.AddressZero, ethers.constants.AddressZero, addresses.address.DAO, deployer.address,
        addresses.oracle.LAND.oracle, addresses.oracle.LAND.jobID, ethers.utils.parseEther("0.1")])

    await bondContract.deployed()

    await bondContract.initializeBondTerms(
        1000000,
        // 1000,// 2581, // _controlVariable
        432000,//28800,// _vestingTerm in seconds
        ethers.utils.parseEther("0.9"), // _minimumPrice
        500000000000000, // _maxPayout //3 dcimals // % of totalSupply in 1 tx
        1000, // _fee //10%
        "600000000000000000000000000", // _maxDebt
        "0"//"450000000000000000000000"// _initialDebt
    )

    let Treasury = await ethers.getContractAt("Treasury", addresses.treasury, deployer)

    await Treasury.connect(deployer).toggle(8, bondContract.address, ethers.constants.AddressZero)
    await Treasury.connect(deployer).toggle(9, addresses.NFT.LAND, ethers.constants.AddressZero)

  
    console.log("NFT BOND Proxy: ", bondContract.address)
  
  };
  
  
  
  module.exports.tags = ["mainnet_deploy_nftBond"]
  module.exports.dependencies = ["mainnet_deploy_D33D","mainnet_deploy_treasury"/* , "mainnet_deploy_staking" */]
