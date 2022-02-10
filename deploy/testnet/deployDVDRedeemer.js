const { ethers, upgrades } = require("hardhat");
const { testnet: addresses } = require("../../addresses/d33d")

const DVDAddress = "0x9767292B1B832192aeB030742463b64cD5797264"
const vipDVDAddress = "0x8DCe1D402Ed510aB297a0794D42B0B6CcC291d89"

module.exports = async () => {

    const [deployer] = await ethers.getSigners();

    let DvDRedeemer = await ethers.getContractFactory("DvDRedeemerTestnet", deployer)

    let _DvDRedeemer = await upgrades.deployProxy(DvDRedeemer, [DVDAddress, vipDVDAddress, addresses.pD33D.pD33D,
        [500000, 1000000, 1500000, 2000000, 2500000], // pD33dRedeemedAmt,
        [604800, 1209600, 1814400, 2419200, 2419200], //interval
        [10, 12, 14, 16, 18], //PriceInDVD //FOR DVD


        [500000, 1000000, 1500000, 2000000, 2500000], // pD33dRedeemedAmt,
        [604800, 1209600, 1814400, 2419200, 2419200], //interval
        [5, 6, 7, 8, 9] //PriceInVIPDVD //FOR DVD //FOR VIP DVD
    ])

    await _DvDRedeemer.deployed()

    console.log("DvDRedeemer: ", _DvDRedeemer.address)

};



module.exports.tags = ["testnet_deploy_dvdRedeemer"]