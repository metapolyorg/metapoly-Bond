const { ethers, upgrades } = require( "hardhat")
const {mainnet: addresses} = require("../addresses/d33d")
const IERC20_ABI = require("../abis/IERC20_ABI.json")
const { expect } = require("chai")
const unlockedAddress = "0xEC4486a90371c9b66f499Ff3936F29f0D5AF8b7E"

const setup = async () => {
    const [deployer, signer, feeReceiver, user1, user2, user3] = await ethers.getSigners()
    const D33DFac = await ethers.getContractFactory("D33DImplementation", deployer)
    const D33D = await upgrades.deployProxy(D33DFac, ["D33D", "D33D", ethers.utils.parseEther("1000000000")])
    await D33D.unlock()

    let Airdrop = await ethers.getContractFactory("Airdrop", deployer)
    const airdrop = await upgrades.deployProxy(Airdrop, [D33D.address, feeReceiver.address, signer.address,
        [ethers.utils.parseEther("0.1"), ethers.utils.parseEther("0.2"), ethers.utils.parseEther("0.3")],
        [1000, 2000, 3000]]) //10%, 20%, 30%


    let Treasury = await ethers.getContractFactory("Treasury", deployer)

    let treasury = await upgrades.deployProxy(Treasury, [D33D.address, addresses.tokens.usdc, deployer.address,
    ethers.utils.parseUnits("1", "17") //0.1 USD per d33d
    ])

    await D33D.setTreasury(treasury.address)

    await treasury.connect(deployer).toggle("0", deployer.address, ethers.constants.AddressZero)
    // await treasury.connect(deployer).toggle("2", addresses.tokens.usdc, ethers.constants.AddressZero)

    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [unlockedAddress]
    })

    let unlockedSigner = await ethers.getSigner(unlockedAddress)
    const USDC = new ethers.Contract(addresses.tokens.usdc, IERC20_ABI, deployer)

    await USDC.connect(unlockedSigner).transfer(deployer.address, ethers.utils.parseUnits("10", "6"))

    await USDC.connect(deployer).approve(treasury.address, ethers.utils.parseUnits("10000", "6"))

    await treasury.connect(deployer).deposit(ethers.utils.parseUnits("10", "6"), addresses.tokens.usdc, "0")

    await D33D.connect(deployer).transfer(airdrop.address, ethers.utils.parseEther("10"))

    return {deployer, D33D, USDC, airdrop, signer, feeReceiver, user1, user2, user3}
}

describe("Airdrop", () => {
    it("Should work", async () => {
        let {deployer, D33D, airdrop, signer, feeReceiver, user1, user2, user3} = await setup()
        
        await airdrop.connect(user1).unlock(user1.address, ethers.constants.AddressZero, { value: ethers.utils.parseEther("0.1") })
        // console.log((await feeReceiver.getBalance()).toString())

        // console.log("user1 initial", (await user1.getBalance()).toString())
        await airdrop.connect(user2).unlock(user2.address, user1.address, { value: ethers.utils.parseEther("0.1") })
        // console.log("feeReceiver",(await feeReceiver.getBalance()).toString())
        // console.log("user1",(await user1.getBalance()).toString())

        await airdrop.connect(user1).upgrade("2", { value: ethers.utils.parseEther("0.2") })
        await airdrop.connect(user3).unlock(user3.address, user1.address, { value: ethers.utils.parseEther("0.1") })
        // console.log("feeReceiver",(await feeReceiver.getBalance()).toString())
        // console.log("user1",(await user1.getBalance()).toString())

        //to check upgrade fee
        await airdrop.connect(user3).upgrade("3", { value: ethers.utils.parseEther("0.5") })

        //claim

        const message = ethers.utils.solidityKeccak256(["address", "uint256"], [user3.address, ethers.utils.parseEther("1").toString()])
        const signature = await signer.signMessage(ethers.utils.arrayify(message))

        await airdrop.connect(user3).claim(signature, ethers.utils.parseEther("1"))
        console.log("claimed amt", (await D33D.balanceOf(user3.address)).toString())

    })
})