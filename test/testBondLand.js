const { expect } = require("chai")
const { ethers, deployments, network, artifacts, upgrades } = require('hardhat')
const { mainnet: addresses } = require("../addresses/d33d")
const IERC721_ABI = require("../abis/IERC721.json")
const unlockedAddress = "0x9cfa73b8d300ec5bf204e4de4a58e5ee6b7dc93c"

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

describe("LAND NFT BOND", () => {
    it("Should Work", async () => {
        let { user1, user2, D33D, treasury, Bond, LAND, unlockedSigner, deployer } = await setup()
        console.log("bondPrice - before deposit", String(await Bond.bondPrice()))

        await Bond.connect(unlockedSigner).deposit("19201", ethers.constants.MaxUint256, user1.address)
        console.log("price", String(await Bond.getPrice()))



        console.log(String(await Bond.bondInfo(user1.address)))
        console.log("bondPrice - after deposit", String(await Bond.bondPrice()))

        console.log("waiting for sometime...")
        // await increaseTime(14400) //4hrs
        // await mine()

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
    })
})


const setup = async () => {
    let [deployer, user1, user2] = await ethers.getSigners()

    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [unlockedAddress]
    })

    let unlockedSigner = await ethers.getSigner(unlockedAddress)

    const LAND = new ethers.Contract(addresses.NFT.LAND, IERC721_ABI, deployer)
    let D33D = await setupD33D(deployer)

    let treasury = await setupTreasury(D33D, deployer)
    let Bond = await setupBond(D33D, treasury, deployer)//await ethers.getContractAt("BondContract", addresses.bond.MANABond)

    // await treasury.connect(deployer).toggle(0, Bond.address, ethers.constants.AddressZero)

    // await treasury.connect(deployer).editPermission(0, Bond.address, true)
    // await treasury.connect(deployer).toggle(2, MANA.address, ethers.constants.AddressZero)
    await treasury.setPrice(Bond.address, ethers.utils.parseEther("2")) //floor price = 2 ETH. actual value is 4 ETH

    await LAND.connect(unlockedSigner).setApprovalForAll(Bond.address, true)

    return { user1, user2, D33D, treasury, Bond, LAND, unlockedSigner, deployer }
}

const setupD33D = async (deployer) => {

    let D33D = await ethers.getContractFactory("D33DImplementation", deployer)

    let d33d = await upgrades.deployProxy(D33D, ["MetaPoly", "D33D", ethers.utils.parseEther("100000000")])

    await d33d.deployed()

    await d33d.unlock()

    return d33d
}

const setupBond = async (d33d, treasury, deployer) => {
    const { deploy } = deployments

    let PriceUpdater = await deploy("PriceUpdater", {
        from: deployer.address,
        args: [addresses.oracle.LAND.oracle, addresses.oracle.LAND.jobID, ethers.utils.parseEther("0.1")]
    })

    // let PriceUpdater = await upgrades.deployProxy(PriceUpdaterFactory, [addresses.oracle.LAND.oracle, addresses.oracle.LAND.jobID, ethers.utils.parseEther("0.1")])

    let BondContract = await ethers.getContractFactory("NFTBond", deployer)
    let bondContract = await upgrades.deployProxy(BondContract, [d33d.address, addresses.NFT.LAND, treasury.address,
    ethers.constants.AddressZero, ethers.constants.AddressZero, addresses.address.DAO, deployer.address, PriceUpdater.address
    ])

    await bondContract.deployed()

    let priceUpdater = await ethers.getContractAt("PriceUpdater", PriceUpdater.address, deployer)
    await priceUpdater.updatePriceApi(bondContract.address, "https://api.opensea.io/api/v1/collection/sandbox/stats",
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

    await treasury.connect(deployer).toggle(8, bondContract.address, ethers.constants.AddressZero)
    await treasury.connect(deployer).toggle(9, addresses.NFT.LAND, ethers.constants.AddressZero)

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