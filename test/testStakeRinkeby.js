const { expect } = require("chai")
const { ethers, deployments, network, artifacts, upgrades, hardhatArguments } = require('hardhat')
const { testnet: addresses } = require("../addresses/d33d")
const IERC20_ABI = require("../abis/IERC20_ABI.json")

const unlockedAddress = "0xfdA18D042d069370842b9bb988f2492e6089CdbC"//"0x94dFcE828c3DAaF6492f1B6F66f9a1825254D24B"
const deployerAddress = "0xBE25bC1237EfC5D678C0d5883179C8147D19A1Aa"

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

describe("Staking", () => {

    beforeEach(async () => {
        await deployments.fixture([""]) //reset
    })

    it("Should rebase correctly", async () => {
        let { user1, user2, D33D, treasury, USDC, staking, stakingToken, deployer } = await setup()

        let initialBalance = await D33D.balanceOf(user1.address)
        await staking.connect(user1).stake(ethers.utils.parseEther("5000"), user1.address)
        await staking.connect(user2).stake(ethers.utils.parseEther("10"), user2.address)

        await increaseTime(32400)
        await mine()
        await staking.rebase()


        await increaseTime(32400)
        await mine()
        await staking.rebase()

        // await increaseTime(32400)
        // await mine()
        // await staking.rebase()

        await staking.connect(user1).unStake(true)
        let finalBalance = await D33D.balanceOf(user1.address)

        expect(finalBalance).to.be.gte(initialBalance)

    })

    it("Should auto-compound correctly", async () => {
        let { user1, user2, D33D, vD33D, treasury, USDC, staking, stakingToken, deployer } = await setup()

        let initialBalance = await D33D.balanceOf(user1.address)
        await staking.connect(user1).stake(ethers.utils.parseEther("5000"), user1.address)
        await staking.connect(user2).stake(ethers.utils.parseEther("10"), user2.address)

        await increaseTime(32400)
        await mine()
        await staking.rebase()


        await increaseTime(32400)
        await mine()
        await staking.rebase()

        // await increaseTime(32400)
        // await mine()
        // await staking.rebase()

        //check autocompound
        let warmupInfo = await staking.warmupInfo(user1.address)
        let pendingD33D = (await stakingToken.balanceForGons(warmupInfo.gons)).sub(warmupInfo.deposit)
        let newDepositAmt = pendingD33D.add(warmupInfo.deposit)
        await staking.connect(user1).claimAndStakeD33D()
        warmupInfo = await staking.warmupInfo(user1.address)
        expect(warmupInfo.deposit).to.be.eq(newDepositAmt)

        let vD33DBalance = await vD33D.balanceOf(user1.address)
        //vD33D balance should match
        expect(vD33DBalance).to.be.eq(newDepositAmt)
    })

    it("Shoudl claim USM rewards correctly", async () => {
        let { user1, user2, D33D, vD33D, USM, treasury, USDC, staking, stakingToken, deployer } = await setup()

        let initialUSMBalance = await USM.balanceOf(user1.address)
        await staking.connect(user1).stake(ethers.utils.parseEther("5000"), user1.address)
        await staking.connect(user2).stake(ethers.utils.parseEther("10"), user2.address)

        await increaseTime(32400)
        await mine()
        await staking.rebase()

        await staking.connect(user1).claimRewards()
        let finalUSMBalance = await USM.balanceOf(user1.address)

        expect(finalUSMBalance).to.be.gt(initialUSMBalance)
    })

    it("Should mint and burn vD33D correctly", async () => {
        let { user1, user2, D33D, vD33D, treasury, USDC, staking, stakingToken, deployer } = await setup()

        let initialD33DBalanceUser1 = await D33D.balanceOf(user1.address)

        let user1DepostedAmt = ethers.utils.parseEther("5000")
        await staking.connect(user1).stake(user1DepostedAmt, user1.address)
        await staking.connect(user2).stake(ethers.utils.parseEther("10"), user2.address)

        //SHOULD mint same vD33D as deposited D33D
        let vD33DUser1 = await vD33D.balanceOf(user1.address)
        expect(user1DepostedAmt).to.be.eq(vD33DUser1)

        await increaseTime(32400)
        await mine()
        await staking.rebase()

        let warmupInfo = await staking.warmupInfo(user1.address)
        let pendingD33D = (await stakingToken.balanceForGons(warmupInfo.gons)).sub(warmupInfo.deposit)
        let newDepositAmt = pendingD33D.add(warmupInfo.deposit)
        await staking.connect(user1).claimAndStakeD33D()

        //Should mint correct amt of vD33D on claimAndStake
        vD33DUser1 = await vD33D.balanceOf(user1.address)
        expect(vD33DUser1).to.be.eq(newDepositAmt)

        //should burn correct vD33D on unstake
        await staking.connect(user1).unStake(true)
        vD33DUser1 = await vD33D.balanceOf(user1.address)
        expect(vD33DUser1).to.be.eq(ethers.constants.Zero)

    })

    it("Should withdraw correct amount of D33D on unstake", async () => {
        let { user1, user2, D33D, treasury, USDC, staking, stakingToken, deployer } = await setup()

        let initialBalanceUser1 = await D33D.balanceOf(user1.address)
        let initialBalanceUser2 = await D33D.balanceOf(user2.address)

        let amtToStakeUser2 = ethers.utils.parseEther("10")
        await staking.connect(user1).stake(ethers.utils.parseEther("5000"), user1.address)
        await staking.connect(user2).stake(amtToStakeUser2, user2.address)
        let afterDepositBalanceUser2 = await D33D.balanceOf(user2.address)


        await increaseTime(32400)
        await mine()
        await staking.rebase()


        await increaseTime(32400)
        await mine()
        await staking.rebase()

        // await increaseTime(32400)
        // await mine()
        // await staking.rebase()
        await staking.connect(user1).claimRewards()
        await staking.connect(user1).unStake(true)
        let finalBalanceUser1 = await D33D.balanceOf(user1.address)
        expect(finalBalanceUser1).to.be.eq(initialBalanceUser1)


        await staking.connect(user2).claimAndStakeD33D()
        let warmupInfo = await staking.warmupInfo(user2.address)
        let d33dToBeWithdrawn = warmupInfo.deposit
        await staking.connect(user2).unStake(true)
        let finalBalanceUser2 = await D33D.balanceOf(user2.address)
        expect(finalBalanceUser2).to.be.eq(d33dToBeWithdrawn.add(afterDepositBalanceUser2))
        expect(d33dToBeWithdrawn).to.be.gt(amtToStakeUser2)
    })

})


const setup = async () => {
    let [/* deployer, */ user1, user2, topup] = await ethers.getSigners()

    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [unlockedAddress]
    })

    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [deployerAddress]
    })

    let unlockedSigner = await ethers.getSigner(unlockedAddress)
    let deployer = await ethers.getSigner(deployerAddress)

    const USDC = new ethers.Contract(addresses.tokens.usdc, [
        "function transfer(address to, uint amount) external",
        "function approve(address spender, uint amount)  external",
        "function mint(uint amount) external",
        "function balanceOf(address) public view returns (uint)"],
        deployer)

    const USM = new ethers.Contract(addresses.USM.USM, IERC20_ABI, deployer)
    let D33D = new ethers.Contract(addresses.d33d, IERC20_ABI, deployer)
    // let D33D = await setupD33D(deployer)

    // let treasury = await setupTreasury(D33D, deployer)
    // let Bond = await setupBond(D33D, treasury, deployer)//await ethers.getContractAt("BondContract", addresses.bond.USDCBond)

    // await treasury.connect(deployer).toggle(0, Bond.address, ethers.constants.AddressZero)

    let treasury = await ethers.getContractAt("Treasury", addresses.treasury, deployer)

    let { staking, stakingToken, vD33D } = await setupStaing(D33D, treasury, deployer)


    // await USDC.connect(unlockedSigner).transfer(topup.address, ethers.utils.parseUnits("1000", "6"))
    await USDC.connect(topup).mint(ethers.utils.parseUnits("10000", "6"))
    await USDC.connect(topup).approve(treasury.address, ethers.constants.MaxUint256)

    // await USDC.connect(unlockedSigner).transfer(user2.address, ethers.utils.parseUnits("500", "6"))
    await D33D.connect(user1).approve(staking.address, ethers.constants.MaxUint256)
    await D33D.connect(user2).approve(staking.address, ethers.constants.MaxUint256)

    await vD33D.connect(user1).approve(staking.address, ethers.constants.MaxUint256)
    await vD33D.connect(user2).approve(staking.address, ethers.constants.MaxUint256)


    await treasury.connect(deployer).toggle(0, topup.address, ethers.constants.AddressZero)
    // await treasury.connect(deployer).toggle(2, USDC.address, ethers.constants.AddressZero)
    await treasury.connect(topup).deposit(ethers.utils.parseUnits("900", "6"), USDC.address, 0)
    await treasury.connect(topup).deposit(ethers.utils.parseUnits("50", "6"), USDC.address, ethers.utils.parseUnits("50", "18"))


    await D33D.connect(topup).transfer(user1.address, ethers.utils.parseEther("5000"))
    await D33D.connect(topup).transfer(user2.address, ethers.utils.parseEther("100"))

    return { user1, user2, D33D, vD33D, USM, treasury, USDC, staking, stakingToken, deployer }
}



const setupUSM = async (staking, deployer) => {
    let USMMinter = new ethers.Contract(addresses.USM.USMMinter, [
        "function owner() external view returns (address)",
        "function addAllowedContract(address _contract) external"], deployer)

    let usmMinterOwner = await USMMinter.owner()

    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [usmMinterOwner]
    })

    let USMSigner = await ethers.getSigner(usmMinterOwner)

    await USMMinter.connect(USMSigner).addAllowedContract(staking)
}

const setupStaing = async (d33d, treasury, deployer) => {



    let Staking = await ethers.getContractFactory("Staking", deployer)
    let staking = await upgrades.deployProxy(Staking, [deployer.address, addresses.biconomy.forwarder,
    addresses.USM.USM, ethers.utils.parseEther("5000")])
    await staking.deployed()

    await setupUSM(staking.address, deployer)

    let StakingToken = await ethers.getContractFactory("StakingToken", deployer)
    let stakingToken = await upgrades.deployProxy(StakingToken, ["Staking d33d - flexible", "fsD33D", staking.address])
    await stakingToken.deployed()

    await stakingToken.setIndex(ethers.utils.parseEther("1"))

    let StakingWarmup = await ethers.getContractFactory("StakingWarmup", deployer)
    let stakingWarmup = await upgrades.deployProxy(StakingWarmup, [deployer.address])

    let distributor = await ethers.getContractAt("Distributor", addresses.distributor, deployer)
    let VD33D = await ethers.getContractFactory("VD33D", deployer)
    let vD33D = await upgrades.deployProxy(VD33D, ["Voting D33D", "vD33D", deployer.address])
    await vD33D.setAuthorised(staking.address, true)


    await staking.initialzeStaking(d33d.address, stakingToken.address, distributor.address, stakingWarmup.address,
        28800, 0, //length in seconds(8hrs), firstEpochNumber (same as blockNumber)
        1646812823, addresses.address.DAO, addresses.USM.USMMinter, vD33D.address) //startingTimestampOfFIrstEpoch, lockupPeriodInseconds(5 days), isLockedStaking

    await stakingWarmup.connect(deployer).addStakingContract(staking.address)

    await distributor.connect(deployer).addRecipient(staking.address, stakingToken.address, "200") //0.00002% 4 - decimals


    return { staking, stakingToken, vD33D }
}