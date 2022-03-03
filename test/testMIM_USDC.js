const { expect } = require("chai")
const { ethers, deployments, network, artifacts } = require('hardhat')
const {mainnet: addresses} = require("../addresses/d33d")
const IERC20_ABI = require("../abis/IERC20_ABI.json")
const IERC721_ABI = require("../abis/IERC721.json")
const unlockedAddress = "0x7d812B62Dc15e6F4073ebA8a2bA8Db19c4E40704"

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

    const USDC = new ethers.Contract(addresses.tokens.usdc, IERC20_ABI, deployer)
    const D33D = await ethers.getContractAt("D33DImplementation", addresses.d33d)
    // const sD33D = new ethers.Contract(addresses.sD33D, IERC20_ABI, deployer)



    let Bond = await ethers.getContractAt("BondD33DUSDCLP", addresses.bond.D33D_USDC_BOND) //change
    let treasury = await ethers.getContractAt("Treasury", addresses.treasury, deployer)

    await USDC.connect(unlockedSigner).transfer(user1.address, ethers.utils.parseUnits("0.001", "6"))
    await USDC.connect(unlockedSigner).transfer(user2.address, ethers.utils.parseUnits("0.001", "6"))

    await USDC.connect(user1).approve(Bond.address, ethers.constants.MaxUint256)
    await USDC.connect(user2).approve(Bond.address, ethers.constants.MaxUint256)

    return {user1, user2, D33D, treasury, Bond, USDC, deployer, unlockedSigner}
}

describe("D33D_USDC - Bond", async() => {
    it ("Should work correctly", async() => {
        let {user1, user2, D33D, unlockedSigner, treasury, Bond, USDC, LAND, deployer} = await setup()
        console.log('here')
        console.log("bondPrice - before deposit", String(await Bond.bondPrice()))
        
        await Bond.connect(user1).deposit(ethers.utils.parseUnits("0.001", "6"), ethers.constants.MaxUint256, user1.address)
        

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

        // console.log("exccess funds", String(await treasury.excessReserves()))

        // expect(Number(ethers.utils.formatEther(user1BalanceD33D))).to.be.gte(Number(ethers.utils.formatEther(user1Payout)))


        await increaseTime(216000) //4.5 days
        await mine()

        console.log("bondPrice", String(await Bond.bondPrice()))

    })
})