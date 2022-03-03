const { expect } = require("chai")
const { ethers, deployments, network, artifacts, upgrades } = require('hardhat')
const { mainnet: addresses } = require("../addresses/d33d")
const IERC20_ABI = require("../abis/IERC20_ABI.json")
const { Description } = require("@ethersproject/properties")
const unlockedAddress = "0x69a9bd1808a215bb6861d4b3c1b684966d1d1c53"

const increaseTime = async (seconds) => {
    await network.provider.request({
        method: "evm_increaseTime",
        params: [seconds]
    })
}

const mine = async () => {
    await network.provider.request({
        method: "evm_mine",
        params: []
    })
}

describe("MANA BOND", () => {
    it("Should Work", async () => {
        let { user1, user2, D33D, treasury, Bond, MANA, deployer } = await setup()
        let user1Balance = await MANA.balanceOf(user1.address)
        console.log("bondPrice - before deposit", String(await Bond.bondPrice()))
        console.log("bondPrice In USD", String(await Bond.bondPriceInUSD()))

        await Bond.connect(user1).deposit(user1Balance, ethers.constants.MaxUint256, user1.address)

        console.log(String(await Bond.bondInfo(user1.address)))
        console.log("bondPrice - after deposit", String(await Bond.bondPrice()))
        console.log("bondPrice - usd", String(await Bond.bondPriceInUSD()))

        let user2Balance = await MANA.balanceOf(user2.address)
        await Bond.connect(user2).deposit(user2Balance, ethers.constants.MaxUint256, user2.address)

        console.log("bondPrice", String(await Bond.bondPrice()))
        console.log("bondPrice - usd", String(await Bond.bondPriceInUSD()))
        console.log("waiting for sometime...")
        await increaseTime(14400) //4hrs
        await mine()

        let user1Payout = await Bond.pendingPayoutFor(user1.address)

        console.log("bondPrice", String(await Bond.bondPrice()))
        console.log("bondPrice - usd", String(await Bond.bondPriceInUSD()))

        console.log("D33D TotalSupply", String(await D33D.connect(user1).totalSupply()))
        console.log("balance in BOND", String(await D33D.connect(user1).balanceOf(Bond.address)))

        await Bond.connect(user1).redeem(user1.address, false);

        let user1BalanceD33D = await D33D.connect(user1).balanceOf(user1.address)
        console.log("Redeemed", String(user1BalanceD33D))

        console.log("exccess funds", String(await treasury.excessReserves()))

        expect(Number(ethers.utils.formatEther(user1BalanceD33D))).to.be.gte(Number(ethers.utils.formatEther(user1Payout)))


        await increaseTime(216000) //4.5 days
        await mine()

        console.log("bondPrice", String(await Bond.bondPrice()))

    })
})


const setup = async () => {
    let [deployer, user1, user2] = await ethers.getSigners()

    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [unlockedAddress]
    })

    let unlockedSigner = await ethers.getSigner(unlockedAddress)

    const MANA = new ethers.Contract(addresses.tokens.mana, IERC20_ABI, deployer)
    let D33D = await setupD33D(deployer)

    let treasury = await setupTreasury(D33D, deployer)
    let Bond = await setupBond(D33D, treasury, deployer)//await ethers.getContractAt("BondContract", addresses.bond.MANABond)

    // await treasury.connect(deployer).toggle(0, Bond.address, ethers.constants.AddressZero)

    // await treasury.connect(deployer).editPermission(0, Bond.address, true)
    // await treasury.connect(deployer).toggle(2, MANA.address, ethers.constants.AddressZero)

    await MANA.connect(unlockedSigner).transfer(user1.address, ethers.utils.parseUnits("5", "18"))
    await MANA.connect(unlockedSigner).transfer(user2.address, ethers.utils.parseUnits("500", "18"))
    await MANA.connect(user1).approve(Bond.address, ethers.constants.MaxUint256)
    await MANA.connect(user2).approve(Bond.address, ethers.constants.MaxUint256)

    return { user1, user2, D33D, treasury, Bond, MANA, deployer }
}

const setupD33D = async (deployer) => {

    let D33D = await ethers.getContractFactory("D33DImplementation", deployer)

    let d33d = await upgrades.deployProxy(D33D, ["MetaPoly", "D33D", ethers.utils.parseEther("100000000")])

    await d33d.deployed()

    await d33d.unlock()

    return d33d
}

const setupBond = async (d33d, treasury, deployer) => {
    let BondingCalculator = await ethers.getContractFactory("BondingCalculatorMANA", deployer)
    let bondingCalculator = await upgrades.deployProxy(BondingCalculator, ["5000", deployer.address, addresses.oracle.MANA.MANA_ETH, addresses.oracle.MANA.ETH_USD])
    await bondingCalculator.deployed()
    
    let BondContract = await ethers.getContractFactory("BondContractLP", deployer)
    let bondContract = await upgrades.deployProxy(BondContract, [d33d.address, addresses.tokens.mana, treasury.address,
    ethers.constants.AddressZero, ethers.constants.AddressZero, deployer.address, deployer.address])

    await bondContract.deployed()

    await bondContract.initializeBondTerms(
        1000000, // _controlVariable
        // 800000, // _controlVariable
        432000,//28800,// _vestingTerm in seconds
        ethers.utils.parseEther("0.2380"), // _minimumPrice //1 d33d = 0.2380 MANA
        500000000000000, // _maxPayout //3 dcimals // % of totalSupply in 1 tx
        0, // _fee
        "600000000000000000000000000", // _maxDebt
        "0"//_initialDebt
    )

    await treasury.connect(deployer).toggle(4, bondContract.address, bondingCalculator.address) //liquidiyDepositor
    await treasury.connect(deployer).toggle(5, addresses.tokens.mana, bondingCalculator.address) //liquidityToken

    return bondContract
}

const setupTreasury = async (d33d, deployer) => {
    let Treasury = await ethers.getContractFactory("Treasury", deployer)

    let treasury = await upgrades.deployProxy(Treasury, [d33d.address, addresses.tokens.usdc, deployer.address,
    ethers.utils.parseUnits("1", "17") //0.1 USD per d33d
    ])

    await d33d.connect(deployer).setTreasury(treasury.address)

    return treasury
}