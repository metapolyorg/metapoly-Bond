const { ethers, upgrades } = require( "hardhat")
const {mainnet: addresses} = require("../addresses/d33d")
const IERC20_ABI = require("../abis/IERC20_ABI.json")
const { expect } = require("chai")
const unlockedAddress = "0xaa9233eb821f3bf04b265319e5eba5607e752acd"
const vipDVDAddress = "0x1193c036833B0010fF80a3617BBC94400A284338"
const DVDAddress = "0x77dcE26c03a9B833fc2D7C31C22Da4f42e9d9582"

const setup = async () => {
    const [deployer, signer, feeReceiver, user1, user2, user3] = await ethers.getSigners()


    const pD33DFac = await ethers.getContractFactory("pD33D", deployer)
    const pD33D = await upgrades.deployProxy(pD33DFac, [ethers.utils.parseEther("2100")])

    let Redeemer = await ethers.getContractFactory("DvDRedeemer", deployer)
    const redeemer = await upgrades.deployProxy(Redeemer, [DVDAddress, vipDVDAddress, pD33D.address,
    [500000, 1000000, 1500000, 2000000, 2500000], // pD33dRedeemedAmt,
    [604800, 1209600, 1814400, 2419200, 2419200], //interval
    [10, 12, 14, 16, 18], //PriceInDVD //FOR DVD
    
    
    [500000, 1000000, 1500000, 2000000, 2500000], // pD33dRedeemedAmt,
    [604800, 1209600, 1814400, 2419200, 2419200], //interval
    [5, 6, 7, 8, 9] //PriceInVIPDVD //FOR DVD //FOR VIP DVD
    ])

    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [unlockedAddress]
    })

    let unlockedSigner = await ethers.getSigner(unlockedAddress)
   
    const DVD = new ethers.Contract(DVDAddress, IERC20_ABI, deployer)
    const vipDVD = new ethers.Contract(vipDVDAddress, IERC20_ABI, deployer)

    await DVD.connect(user1).approve(redeemer.address, ethers.utils.parseUnits("10000", "18"))
    await DVD.connect(user2).approve(redeemer.address, ethers.utils.parseUnits("10000", "18"))
    await vipDVD.connect(user1).approve(redeemer.address, ethers.utils.parseUnits("10000", "18"))
    await vipDVD.connect(user2).approve(redeemer.address, ethers.utils.parseUnits("10000", "18"))

    await vipDVD.connect(unlockedSigner).transfer(user1.address, ethers.utils.parseEther("10"))
    await vipDVD.connect(unlockedSigner).transfer(user2.address, ethers.utils.parseEther("10"))

    await DVD.connect(unlockedSigner).transfer(user1.address, ethers.utils.parseEther("10"))
    await DVD.connect(unlockedSigner).transfer(user2.address, ethers.utils.parseEther("10"))

    await pD33D.connect(deployer).transfer(redeemer.address, ethers.utils.parseEther("10"))


    return {deployer, DVD, pD33D, redeemer, signer, user1, user2, user3}
}

describe("redeemer", () => {

    beforeEach(async() => {
        await deployments.fixture("mainnet_deploy_DVDRedeemer")
    })
    // it("Should work", async () => {
    //     let {deployer, DVD, pD33D, redeemer, signer, feeReceiver, user1, user2, user3} = await setup()
        
    //     await redeemer.connect(user1).redeemDVD(ethers.utils.parseEther("1"))
    //     let redeemedpD33d = await pD33D.balanceOf(user1.address)
    //     console.log("redeemed pD33d", (ethers.utils.formatEther(redeemedpD33d.toString())).toString())

    //     await redeemer.connect(user1).redeemVipDVD(ethers.utils.parseEther("1"))

    // })

    it('test', async () => {
        const [deployer] = await ethers.getSigners()
        /* let redeemer = await ethers.getContractAt("DvDRedeemerTestnet", "0x3e6286F0e762cb67b099360738ad26AdbB5F1667")
        let user1Address =  "0xBE25bC1237EfC5D678C0d5883179C8147D19A1Aa"

        const DVD = new ethers.Contract(DVDAddress, IERC20_ABI, deployer)
        const vipDVD = new ethers.Contract(vipDVDAddress, IERC20_ABI, deployer)
        const pD33D = new ethers.Contract("0x00F428bb293F4faDA7351f5daC9e78af61401C5b", IERC20_ABI, deployer)

        // await network.provider.request({
        //     method: "hardhat_impersonateAccount",
        //     params: [user1Address]
        // })
        
        // let user1 = await ethers.getSigner(user1Address)

        // await redeemer.connect(deployer).redeemVipDVD(ethers.utils.parseEther("1"), {gasLimit: 8000000})
        let balanceBefore = await pD33D.balanceOf(deployer.address)
        await redeemer.connect(deployer).redeemDVD(ethers.utils.parseEther("1"), {gasLimit: 8000000})
        let balanceAfter = await pD33D.balanceOf(deployer.address)

        console.log("diff", (balanceAfter.sub(balanceBefore)).toString()) */


    })
})