const { expect } = require("chai")
const { ethers, deployments, network, artifacts } = require('hardhat')
const {mainnet: addresses} = require("../addresses/d33d")
const IERC20_ABI = require("../abis/IERC20_ABI.json")

const setup = async() => {
    const [deployer, user1, user2] = await ethers.getSigners()

    let D33D = await ethers.getContractFactory("D33DImplementation", deployer)

    let d33d = await upgrades.deployProxy(D33D, ["MetaPoly", "D33D"])

    await d33d.connect(deployer).setTreasury(deployer.address) //only for test.

    await d33d.connect(deployer).mint(user1.address, ethers.utils.parseEther("10"))
    await d33d.connect(deployer).mint(user2.address, ethers.utils.parseEther("10"))


    return {d33d, deployer, user1, user2}
}


describe("D33d", () => {
    beforeEach(async() => {
        await deployments.fixture("")
    })

    it("Should transfer correctly", async() => {
        const {d33d, deployer, user1, user2} = await setup()

        let user1Balance = await d33d.balanceOf(user1.address)
        let user2Balance = await d33d.balanceOf(user2.address)

        await d33d.connect(user1).transfer(user2.address, user1Balance)

        let user1BalanceFinal = await d33d.balanceOf(user1.address)
        let user2BalanceFinal = await d33d.balanceOf(user2.address)

        expect(user1BalanceFinal).to.be.eq(ethers.BigNumber.from("0"))
        expect(user2BalanceFinal).to.be.eq(user2Balance.add(user1Balance))
    })

    it("Should deduct Sell tax correctly", async() => {
        const {d33d, deployer, user1, user2} = await setup()

        await d33d.connect(deployer).setTaxPerc(5000);
        await d33d.connect(deployer).toggleFee(true, true, false);
        await d33d.connect(deployer).updateDexAddress(user2.address, true); //set user2/receiver as dex
        
        let taxPerc = await d33d.connect(deployer).taxPerc();
        
        let user1Balance = await d33d.balanceOf(user1.address)
        let user2Balance = await d33d.balanceOf(user2.address)
        let taxReceiverBalance = await d33d.balanceOf(d33d.taxReceiver())

        let transferAmount = user1Balance.div("2")
        await d33d.connect(user1).transfer(user2.address, transferAmount)

        let user1BalanceFinal = await d33d.balanceOf(user1.address)
        let user2BalanceFinal = await d33d.balanceOf(user2.address)
        let taxReceiverBalanceFinal = await d33d.balanceOf(d33d.taxReceiver())

        //user1 : deducts transferAmount + taxPerc of transferAmt
        expect(user1BalanceFinal).to.be.eq(user1Balance.sub(
            transferAmount.add( 
                transferAmount.mul(taxPerc).div("10000")
            )
            ))

        expect(user2BalanceFinal).to.be.eq(user2Balance.add(transferAmount))
        expect(taxReceiverBalanceFinal).to.be.eq(taxReceiverBalance.add(transferAmount.mul(taxPerc).div("10000")))


    })

    it("Should deduct buy tax correctly", async() => {
        const {d33d, deployer, user1, user2} = await setup()

        await d33d.connect(deployer).setTaxPerc(5000);
        await d33d.connect(deployer).toggleFee(true, false, true);
        await d33d.connect(deployer).updateDexAddress(user1.address, true); //set user1/sender as dex

        let taxPerc = await d33d.connect(deployer).taxPerc();
        
        let user1Balance = await d33d.balanceOf(user1.address)
        let user2Balance = await d33d.balanceOf(user2.address)
        let taxReceiverBalance = await d33d.balanceOf(d33d.taxReceiver())
        let transferAmount = user1Balance

        await d33d.connect(user1).transfer(user2.address, transferAmount)

        let user1BalanceFinal = await d33d.balanceOf(user1.address)
        let user2BalanceFinal = await d33d.balanceOf(user2.address)
        let taxReceiverBalanceFinal = await d33d.balanceOf(d33d.taxReceiver())


        expect(user1BalanceFinal).to.be.eq(ethers.BigNumber.from("0"))

        //user2 balance + (transferAmount - taxPerc of transferAmt)
        expect(user2BalanceFinal).to.be.eq(user2Balance.add(user1Balance.sub(transferAmount.mul(taxPerc).div("10000"))))
        expect(taxReceiverBalanceFinal).to.be.eq(taxReceiverBalance.add(transferAmount.mul(taxPerc).div("10000")))
    })

})