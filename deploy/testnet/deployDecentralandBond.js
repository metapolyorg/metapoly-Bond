const { ethers, upgrades } = require("hardhat");
const {testnet: addresses} = require("../../addresses/d33d")
module.exports = async () => {

    const [deployer] = await ethers.getSigners();
    const {deploy} = deployments
  
    let PriceUpdater = await deploy("PriceUpdater",{
        from: deployer.address,
        args: [addresses.oracle.LAND.oracle, addresses.oracle.LAND.jobID, ethers.utils.parseEther("0.1")]
    })

    let BondContract = await ethers.getContractFactory("NFTBond", deployer)
    let bondContract = await upgrades.upgradeProxy("0x35B52706732B3148868A23798012994f52d340D1", BondContract)
    await bondContract.connect(deployer).setTrustedForwarder(addresses.biconomy.forwarder)
    
    let bondContract = await upgrades.deployProxy(BondContract, [addresses.d33d, addresses.NFT.DECENTRALAND_LAND, addresses.treasury, 
        ethers.constants.AddressZero, addresses.stakingFlexible, addresses.address.DAO, deployer.address, PriceUpdater.address, addresses.biconomy.forwarder
        ])

    await bondContract.deployed()

    let priceUpdater = await ethers.getContractAt("PriceUpdater", PriceUpdater.address, deployer)
    await priceUpdater.updatePriceApi(bondContract.address, "https://api.opensea.io/api/v1/collection/decentraland/stats",
        "stats.floor_price", ethers.utils.parseEther("1"))

    await bondContract.initializeBondTerms(
        400000,
        // 1000,// 2581, // _controlVariable
        432000,//28800,// _vestingTerm in seconds
        ethers.utils.parseEther("0.417"), // _minimumPrice
        500000000000000, // _maxPayout //3 dcimals // % of totalSupply in 1 tx
        0, // _fee //10%
        "600000000000000000000000000", // _maxDebt
        "0"//"450000000000000000000000"// _initialDebt
    )

    let Treasury = await ethers.getContractAt("Treasury", addresses.treasury, deployer)

    await Treasury.connect(deployer).toggle(8, bondContract.address, ethers.constants.AddressZero)
    // await Treasury.connect(deployer).toggle(9, addresses.NFT.LAND, ethers.constants.AddressZero)

    console.log('price updater', priceUpdater.address)
    console.log("NFT BOND Proxy: ", bondContract.address)
  
  };
  
  
  
  module.exports.tags = ["testnet_deploy_decentralandBond"]
//   module.exports.dependencies = ["mainnet_deploy_D33D","mainnet_deploy_treasury"/* , "mainnet_deploy_staking" */]
