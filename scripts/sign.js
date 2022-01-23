const { ethers } = require("ethers")
const csv = require("csv-parser")
const fs = require("fs")
require("dotenv").config()

// Note: only signer in pD33DRedeemer contract can execute this script
const main = () => {
    let data = []
    fs.createReadStream("whitelist.csv")
        .pipe(csv())
        .on("data", async (row) => {
            const message = ethers.utils.solidityKeccak256(["address"], [ethers.utils.getAddress(row.address)])
            const signer = new ethers.Wallet(process.env.PRIVATE_KEY)
            const signature = await signer.signMessage(ethers.utils.arrayify(message))
            data.push({address: row.address, signature: signature})
        })
        .on("end", () => {
            fs.writeFile("data.json", JSON.stringify(data), () => {})
        })
}
main()