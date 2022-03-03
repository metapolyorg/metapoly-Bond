const { expect } = require("chai")
const { ethers, deployments, network, artifacts, upgrades } = require('hardhat')
const { mainnet: addresses } = require("../addresses/d33d")
const IERC20_ABI = require("../abis/IERC20_ABI.json")
const { Description } = require("@ethersproject/properties")
const unlockedAddress = "0xfdA18D042d069370842b9bb988f2492e6089CdbC"//"0x94dFcE828c3DAaF6492f1B6F66f9a1825254D24B"

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

describe("USDC BOND", () => {
    it("Should Work", async () => {
        let { user1, user2, D33D, treasury, Bond, USDC, staking, deployer } = await setup()
        let user1Balance = await USDC.balanceOf(user1.address)
        console.log("bondPrice - before deposit", String(await Bond.bondPrice()))
        console.log("bondPrice In USD", String(await Bond.bondPriceInUSD()))

        await Bond.connect(user1).deposit(user1Balance, ethers.constants.MaxUint256, user1.address, false)

        console.log(String(await Bond.bondInfo(user1.address)))
        console.log("bondPrice - after deposit", String(await Bond.bondPrice()))
        console.log("bondPrice - usd", String(await Bond.bondPriceInUSD()))

        let user2Balance = await USDC.balanceOf(user2.address)
        await Bond.connect(user2).deposit(user2Balance, ethers.constants.MaxUint256, user2.address, true)

        console.log("bondPrice", String(await Bond.bondPrice()))
        console.log("bondPrice - usd", String(await Bond.bondPriceInUSD()))
        console.log("waiting for sometime...")
        await increaseTime(14400) //4hrs
        await mine()

        let stakingBalance = await staking.connect(user2).bondDeposits(user2.address)
        console.log("stakingBalance", String(stakingBalance))

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

    const USDC = new ethers.Contract(addresses.tokens.usdc, IERC20_ABI, deployer)
    let D33D = await setupD33D(deployer)

    let treasury = await setupTreasury(D33D, deployer)
    let Bond = await setupBond(D33D, treasury, deployer)//await ethers.getContractAt("BondContract", addresses.bond.USDCBond)

    await treasury.connect(deployer).toggle(0, Bond.address, ethers.constants.AddressZero)

    let staking = await setupStaing(D33D, treasury, Bond, deployer)

    // await treasury.connect(deployer).editPermission(0, Bond.address, true)
    // await treasury.connect(deployer).toggle(2, USDC.address, ethers.constants.AddressZero)

    await USDC.connect(unlockedSigner).transfer(user1.address, ethers.utils.parseUnits("5", "6"))
    await USDC.connect(unlockedSigner).transfer(user2.address, ethers.utils.parseUnits("500", "6"))
    await USDC.connect(user1).approve(Bond.address, ethers.constants.MaxUint256)
    await USDC.connect(user2).approve(Bond.address, ethers.constants.MaxUint256)

    return { user1, user2, D33D, treasury, Bond, USDC, staking, deployer }
}

const setupD33D = async (deployer) => {

    let D33D = await ethers.getContractFactory("D33DImplementation", deployer)

    let d33d = await upgrades.deployProxy(D33D, ["MetaPoly", "D33D", ethers.utils.parseEther("100000000")])

    await d33d.deployed()

    await d33d.unlock()

    return d33d
}

const setupBond = async (d33d, treasury, deployer) => {
    let BondContract = await ethers.getContractFactory("BondStaking", deployer)

    let bondContract = await upgrades.deployProxy(BondContract, [d33d.address, addresses.tokens.usdc, treasury.address,
    ethers.constants.AddressZero, ethers.constants.AddressZero, deployer.address, deployer.address, addresses.biconomy.forwarder])

    await bondContract.deployed()

    await bondContract.initializeBondTerms(
        1000000, // _controlVariable
        432000,//28800,// _vestingTerm in seconds
        ethers.utils.parseEther("0.8"), // _minimumPrice
        500000000000000, // _maxPayout //3 dcimals // % of totalSupply in 1 tx
        0, // _fee
        "600000000000000000000000000", // _maxDebt
        "0"//_initialDebt
    )

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

const setupStaing = async (d33d, treasury, bond, deployer) => {

    let Staking = await ethers.getContractFactory("Staking", deployer)
    let staking = await upgrades.deployProxy(Staking, [deployer.address, addresses.biconomy.forwarder])
    await staking.deployed()

    let StakingToken = await ethers.getContractFactory("StakingToken", deployer)
    let stakingToken = await upgrades.deployProxy(StakingToken, ["Staking d33d - flexible", "fsD33D", staking.address])
    await stakingToken.deployed()

    let StakingWarmup = await ethers.getContractFactory("StakingWarmup", deployer)
    let stakingWarmup = await upgrades.deployProxy(StakingWarmup, [deployer.address])

    /// DEPLOY gD33D
    let GD33D = await ethers.getContractFactory("gD33D", deployer)
    let gD33D = await upgrades.deployProxy(GD33D, ["Governance D33D", "gD33D", stakingToken.address, staking.address])
    await gD33D.deployed()

    console.log('gD33D', gD33D.address)

    //deploy distributor
    let Distributor = await ethers.getContractFactory("Distributor", deployer)
    //end of first epoch time
    let distributor = await upgrades.deployProxy(Distributor, [d33d.address, treasury.address, "28800", "1648050173", deployer.address])
    await distributor.deployed()
    await treasury.connect(deployer).toggle("7", distributor.address, ethers.constants.AddressZero)

    await staking.initialzeStaking(d33d.address, stakingToken.address, distributor.address, stakingWarmup.address,
        28800, 0, //length in seconds(8hrs), firstEpochNumber (same as blockNumber)
        1643126403, 432000, false, addresses.address.DAO, gD33D.address) //startingTimestampOfFIrstEpoch, lockupPeriodInseconds(5 days), isLockedStaking

    await StakingWarmup.connect(deployer).addStakingContract(staking.address)

    await Distributor.connect(deployer).addRecipient(staking.address, stakingToken.address, "2") //0.00002% 4 - decimals

    await staking.connect(deployer).setWarmupPeriodBond("28800")
    await staking.connect(deployer).updateBondAddress(bond.address, true)
    
    return staking
}