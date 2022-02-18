const { expect } = require("chai")
const { ethers, deployments, network, artifacts } = require('hardhat')
const {mainnet: addresses} = require("../addresses/d33d")
const IERC20_ABI = require("../abis/IERC20_ABI.json")
const IERC721_ABI = require("../abis/IERC721.json")


const setup = async() => {
    let [deployer] = await ethers.getSigners()

    let Bond = await ethers.getContractAt("NFTBond", addresses.bond.LAND_Bond)

    return {deployer, Bond}
}

describe("NFT test", () => {
    it('Should work', async() => {
        let {deployer, Bond} = await setup()

        await Bond.connect(deployer).deposit("4", ethers.utils.parseEther("10000000"), deployer.address)
    })
})