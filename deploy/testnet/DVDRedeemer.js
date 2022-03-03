const { ethers, upgrades } = require("hardhat");
const {testnet: addresses} = require("../../addresses/d33d")
module.exports = async () => {

    const [deployer] = await ethers.getSigners();

    let DvDRedeemer = await ethers.getContractFactory("DvDRedeemerTestnet", deployer)

    await redeemer.connect(deployer).setTrustedForwarder(addresses.biconomy.forwarder)

    let redeemer = await upgrades.deployProxy(DvDRedeemer, [addresses.tokens.DVD, addresses.tokens.VIPDVD, addresses.pD33D.pD33D,
        [500000, 1000000, 1500000, 2000000, 2500000], // pD33dRedeemedAmt,
        [604800, 1209600, 1814400, 2419200, 2419200], //interval
        [10, 12, 14, 16, 18], //PriceInDVD //FOR DVD
        
        
        [500000, 1000000, 1500000, 2000000, 2500000], // pD33dRedeemedAmt,
        [604800, 1209600, 1814400, 2419200, 2419200], //interval
        [5, 6, 7, 8, 9], //PriceInVIPDVD //FOR DVD //FOR VIP DVD
           addresses.biconomy.forwarder
        ])

    await redeemer.deployed()
  
    console.log("Redeemer Proxy: ", redeemer.address)
  
  };
  
  
  
  module.exports.tags = ["testnet_deploy_DVDRedeemer"]