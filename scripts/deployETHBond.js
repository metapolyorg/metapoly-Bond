const { ethers, network, upgrades } = require("hardhat")

const WETHAddr = "0xc778417E063141139Fce010982780140Aa0cD5Ab"
const D33DAddr = "0xEa6cFeAcD4c7f29bD56b0d42083e12f0430cd2D3"
const stakingAddr = "0x4a3d9D2099224f9e25e618Bda05e1022b3ea3eb9"
const treasuryAddr = "0x9dB81A0FB5c3C6Cb23ab1b0098E1848705715F7B"

const oracleWETHAddr = "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e"

const proxyAdminAddr = "0x2eC9C33F82da1384706F52E28f4E5E3B03A22FC4"

const main = async () => {
    const [deployer] = await ethers.getSigners()
    let tx

    // const deployerAddr = "0x891F4bDc41455CD2491B6950c1A2Ab46021Dd647"
    // await network.provider.request({method: "hardhat_impersonateAccount", params: [deployerAddr]})
    // const deployer = await ethers.getSigner(deployerAddr)

    const staking = await ethers.getContractAt("Staking", stakingAddr, deployer)
    const treasury = await ethers.getContractAt("Treasury", treasuryAddr, deployer)

    const bondCalcFac = await ethers.getContractFactory("BondingCalculatorSAND", deployer)
    const bondCalc = await upgrades.deployProxy(bondCalcFac, [5000, deployer.address, oracleWETHAddr])
    await bondCalc.deployTransaction.wait()
    console.log("Bond calculator contract deploy successfully at:", bondCalc.address)

    const bondContractFac = await ethers.getContractFactory("BondContractETH", deployer)
    const bondContract = await upgrades.deployProxy(bondContractFac, [
        D33DAddr, // D33D
        WETHAddr, // principle
        treasury.address, // treasury
        bondCalc.address, // bondCalculator
        staking.address, // staking
        deployer.address, // DAO
        deployer.address // admin
    ])
    await bondContract.deployTransaction.wait()
    console.log("Bond contract deploy successfully at:", bondContract.address)

    tx = await treasury.toggle(4, bondContract.address, bondCalc.address) // LiquidiyDepositor
    await tx.wait()
    tx = await treasury.toggle(5, WETHAddr, bondCalc.address) // LiquidityToken
    await tx.wait()
    console.log("Token add to treasury successfully")

    tx = await bondContract.initializeBondTerms(
        "1000000", // controlVariable
        "432000", // vestingTerm
        ethers.utils.parseEther("0.000278"), // minimumPrice - assume WETH price is $3000
        "500000000000000", // maxPayout - % of totalSupply in 1 tx
        "0", // fee
        ethers.utils.parseUnits("6", 26), // maxDebt - max deposit value
        "0" // initialDebt
    )
    await tx.wait()
    console.log("Bond initialize terms successfully")
}
main()