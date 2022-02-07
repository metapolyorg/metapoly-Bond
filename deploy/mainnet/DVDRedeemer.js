const { ethers, upgrades } = require("hardhat");
const {mainnet: addresses} = require("../../addresses/d33d")
module.exports = async () => {

    const [deployer] = await ethers.getSigners();

    let DvDRedeemer = await ethers.getContractFactory("DvDRedeemer", deployer)

    let redeemer = await upgrades.deployProxy(DvDRedeemer, [addresses.tokens.DVD, addresses.tokens.VIPDVD, addresses.pD33D.pD33D,
        [500000, 1000000, 1500000, 2000000, 2500000], // pD33dRedeemedAmt,
        [604800, 1209600, 1814400, 2419200, 2419200], //interval
        [10, 12, 14, 16, 18], //PriceInDVD //FOR DVD
        
        
        [500000, 1000000, 1500000, 2000000, 2500000], // pD33dRedeemedAmt,
        [604800, 1209600, 1814400, 2419200, 2419200], //interval
        [5, 6, 7, 8, 9] //PriceInVIPDVD //FOR DVD //FOR VIP DVD
        ])

    await redeemer.deployed()
  
    console.log("Redeemer Proxy: ", redeemer.address)
  
  };
  
  
  
  module.exports.tags = ["mainnet_deploy_DVDRedeemer"]