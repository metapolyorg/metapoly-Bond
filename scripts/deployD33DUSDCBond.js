const { ethers, network, upgrades } = require("hardhat")
const IERC20_ABI = require("../abis/IERC20_ABI.json")

const D33DAddr = "0xEa6cFeAcD4c7f29bD56b0d42083e12f0430cd2D3"
const stakingAddr = "0x4a3d9D2099224f9e25e618Bda05e1022b3ea3eb9"
const fsD33DAddr = "0xF667464696B5802aA48886db3306b33Cf9770b7A"
const treasuryAddr = "0x9dB81A0FB5c3C6Cb23ab1b0098E1848705715F7B"
// const proxyAdminAddr = "0x2eC9C33F82da1384706F52E28f4E5E3B03A22FC4"

const D33DUSDCAddr = "0xcAC4c813535847A6801f55300d145883f0EC3247"
const routerAddr = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

const USDCAddr = "0xdf5324ebe6f6b852ff5cbf73627ee137e9075276"

const main = async () => {
    const [deployer] = await ethers.getSigners()
    let tx

    // const deployerAddr = "0x891F4bDc41455CD2491B6950c1A2Ab46021Dd647"
    // await network.provider.request({method: "hardhat_impersonateAccount", params: [deployerAddr]})
    // const deployer = await ethers.getSigner(deployerAddr)

    const D33DUSDC = new ethers.Contract(D33DUSDCAddr, IERC20_ABI, deployer)
    const D33D = await ethers.getContractAt("D33DImplementation", D33DAddr, deployer)
    const fsD33D = await ethers.getContractAt("StakingToken", fsD33DAddr, deployer)
    const staking = await ethers.getContractAt("Staking", stakingAddr, deployer)
    const treasury = await ethers.getContractAt("Treasury", treasuryAddr, deployer)

    const bondCalcFac = await ethers.getContractFactory("BondingCalculatorD33D_USDC", deployer)
    const bondCalc = await upgrades.deployProxy(bondCalcFac, [5000, deployer.address, D33DUSDCAddr, D33DAddr, routerAddr, USDCAddr])
    await bondCalc.deployTransaction.wait()
    console.log("Bond calculator contract deploy successfully at:", bondCalc.address)

    // console.log(ethers.utils.formatEther(await bondCalc.getRawPrice())) // 2021644566528.334101658631650147

    const bondContractFac = await ethers.getContractFactory("BondD33DUSDCLP", deployer)
    const bondContract = await upgrades.deployProxy(bondContractFac, [
        D33DAddr, // D33D
        D33DUSDCAddr, // principle
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
    tx = await treasury.toggle(5, D33DUSDCAddr, bondCalc.address) // LiquidityToken
    await tx.wait()
    console.log("Token add to treasury successfully")

    tx = await bondContract.initializeBondTerms(
        "800000", // controlVariable
        "432000", // vestingTerm
        ethers.utils.parseEther("0.000000416700"), // 1 LP = 2 USD so bond price / 2
        "500000000000000", // maxPayout - % of totalSupply in 1 tx
        "0", // fee
        ethers.utils.parseUnits("6", 26), // maxDebt - max deposit value
        "0" // initialDebt
    )
    await tx.wait()
    console.log("Bond initialize terms successfully")
}
main()