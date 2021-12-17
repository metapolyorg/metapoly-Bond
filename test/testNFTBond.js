const { expect } = require("chai")
const { ethers, deployments, network, artifacts } = require('hardhat')
const {mainnet: addresses} = require("../addresses/d33d")
const IERC20_ABI = require("../abis/IERC20_ABI.json")
const IERC721_ABI = require("../abis/IERC721.json")
const unlockedAddress = "0x9cfa73b8d300ec5bf204e4de4a58e5ee6b7dc93c"

const increaseTime = async(seconds) => {
    await network.provider.request({
        method: "evm_increaseTime",
        params:[seconds]
    })
}

const mine = async() => {
    await network.provider.request({
        method: "evm_mine",
        params:[]
    })
}


const setup = async() => {
    let [deployer, user1, user2, reserveDepositor, topup] = await ethers.getSigners()

    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [unlockedAddress]
    })

    let unlockedSigner = await ethers.getSigner(unlockedAddress)

    const DAI = new ethers.Contract(addresses.tokens.dai, IERC20_ABI, deployer)
    const LAND = new ethers.Contract(addresses.NFT.LAND, IERC721_ABI, deployer)
    const D33D = await ethers.getContractAt("D33DImplementation", addresses.d33d)
    // const sD33D = new ethers.Contract(addresses.sD33D, IERC20_ABI, deployer)



    let Bond = await ethers.getContractAt("NFTBond", addresses.bond.LAND_Bond)
    let treasury = await ethers.getContractAt("Treasury", addresses.treasury, deployer)

    await treasury.setPrice(Bond.address, ethers.utils.parseEther("2")) //floor price = 2 ETH. actual value is 4 ETH

    await LAND.connect(unlockedSigner).setApprovalForAll(Bond.address, true)


    return {user1, user2, D33D, treasury, Bond, DAI, LAND, deployer, unlockedSigner}
}

describe("LAND - Bond", async() => {
    it ("Should work correctly", async() => {
        let {user1, user2, D33D, unlockedSigner, treasury, Bond, DAI, LAND, deployer} = await setup()


        console.log("bondPrice - before deposit", String(await Bond.bondPrice()))
        
        await Bond.connect(unlockedSigner).deposit("19201", ethers.constants.MaxUint256, user1.address)

        

        console.log(String(await Bond.bondInfo(user1.address)))
        console.log("bondPrice - after deposit", String(await Bond.bondPrice()))

        console.log("waiting for sometime...")
        await increaseTime(14400) //4hrs
        await mine()

        let user1Payout = await Bond.pendingPayoutFor(user1.address)

        console.log("bondPrice", String(await Bond.bondPrice()))
        // console.log("bondPrice", String(await Bond.bondPriceInUSD()))

        console.log("D33D TotalSupply", String(await D33D.connect(user1).totalSupply()))
        console.log("balance in BOND", String(await D33D.connect(user1).balanceOf(Bond.address)))

        await Bond.connect(user1).redeem(user1.address, false);

        let user1BalanceD33D = await D33D.connect(user1).balanceOf(user1.address)
        console.log("Redeemed", String(user1BalanceD33D))

        console.log("exccess funds", String(await treasury.excessReserves()))

        expect(Number(ethers.utils.formatEther(user1BalanceD33D))).to.be.gte(Number(ethers.utils.formatEther(user1Payout)))


        // await increaseTime(216000) //4.5 days
        // await mine()

        // console.log("bondPrice", String(await Bond.bondPrice()))

    })
})