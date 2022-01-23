import { ethers, upgrades } from "hardhat"
import routerABI from "../abis/router_ABI.json"
import IERC20ABI from "../abis/IERC20_ABI.json"

const USDCAddr = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
const WETHAddr = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
const routerAddr = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

describe("pD33D", () => {
    it("Should work", async () => {
        const [deployer, signer] = await ethers.getSigners()

        // Deploy D33D
        const D33DFac = await ethers.getContractFactory("D33DImplementation", deployer)
        const D33D = await upgrades.deployProxy(D33DFac, ["D33D", "D33D"])
        await D33D.unlock()

        // Deploy pD33D
        const pD33DFac = await ethers.getContractFactory("pD33D", deployer)
        const pD33D = await upgrades.deployProxy(pD33DFac, [ethers.utils.parseEther("2100")])

        // Deploy pD33DRedeemer
        const pD33DRedeemerFac = await ethers.getContractFactory("pD33DRedeemer", deployer)
        const pD33DRedeemer = await upgrades.deployProxy(pD33DRedeemerFac, [D33D.address, pD33D.address, signer.address])
        await pD33D.setRedeemer(pD33DRedeemer.address)

        // Deploy treasury
        const treasuryFac = await ethers.getContractFactory("Treasury", deployer)
        const treasury = await upgrades.deployProxy(treasuryFac, [
            D33D.address, // D33D
            USDCAddr, // USDC - Initial reserve token
            deployer.address, // owner
            ethers.utils.parseUnits("1", "17") // D33DPrice - 1e17, 0.1 USD
        ])
        await D33D.setTreasury(treasury.address)
        await pD33DRedeemer.setTreasury(treasury.address)
        await treasury.toggle(0, pD33DRedeemer.address, ethers.constants.AddressZero)
        // await treasury.toggle(2, USDCAddr, ethers.constants.AddressZero)

        // Get some USDC
        const uRouter = new ethers.Contract(routerAddr, routerABI, deployer)    
        await uRouter.swapETHForExactTokens(
            ethers.utils.parseUnits("220", 6), [WETHAddr, USDCAddr], deployer.address, Math.ceil(Date.now() / 1000),
            {value: ethers.utils.parseEther("9999")}
        )
        const USDC = new ethers.Contract(USDCAddr, IERC20ABI, deployer)
        await USDC.approve(pD33DRedeemer.address, ethers.constants.MaxUint256)

        // Redeem D33D (with signature)
        const message = ethers.utils.solidityKeccak256(["address"], [deployer.address])
        const signature = await signer.signMessage(ethers.utils.arrayify(message))
        // console.log(ethers.utils.formatEther(await pD33DRedeemer.redeemableFor(deployer.address)))
        await pD33DRedeemer.redeem(ethers.utils.parseEther("2000"), signature, false)
        // console.log(ethers.utils.formatEther(await pD33DRedeemer.redeemableFor(deployer.address)))
        // console.log(ethers.utils.formatEther(await D33D.balanceOf(deployer.address)))

        // Redeem D33D (with on-chain whitelist)
        // Set whitelist
        await pD33DRedeemer.setTerms(deployer.address, ethers.utils.parseEther("100"), 1000)
        await pD33DRedeemer.changeWhitelistedAddress(signer.address)
        await pD33D.transfer(signer.address, ethers.utils.parseEther("100"))
        await USDC.transfer(signer.address, ethers.utils.parseUnits("10", 6))
        // console.log(ethers.utils.formatEther(await pD33DRedeemer.redeemableFor(deployer.address)))
        // Redeem
        // console.log(ethers.utils.formatEther(await pD33DRedeemer.redeemableFor(signer.address)))
        await USDC.connect(signer).approve(pD33DRedeemer.address, ethers.constants.MaxUint256)
        await pD33DRedeemer.connect(signer).redeem(ethers.utils.parseEther("100"), [], false)
        // console.log(ethers.utils.formatEther(await pD33DRedeemer.redeemableFor(signer.address)))
        // console.log(ethers.utils.formatEther(await D33D.balanceOf(signer.address)))
        // console.log(await pD33DRedeemer.isContractWhitelisted(deployer.address))
        // console.log(await pD33DRedeemer.isContractWhitelisted(signer.address))
    })
})