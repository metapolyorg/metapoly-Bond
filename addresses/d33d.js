module.exports ={
    mainnet: {
        d33d: "0xAA292E8611aDF267e563f334Ee42320aC96D0463",

        treasury: "0x720472c8ce72c2A2D711333e064ABD3E6BbEAdd3",
        distributor: "",
        stakingWarmup: "",

        bondCalculator: "",
        bondCalculatorStrategy: "",
        
        tokens: {
            dai: "",
            usdc:"",
            usdt: "",
        },
        NFT: {
            LAND: "0x50f5474724e0Ee42D9a4e711ccFB275809Fd6d4a"
        },
        bond: {
            LAND_Bond: "0x18E317A7D70d8fBf8e6E893616b52390EbBdb629",
        },

        address: {
            DAO:"0x575409F8d77c12B05feD8B455815f0e54797381c", //address to receive fee
            admin: "0x575409F8d77c12B05feD8B455815f0e54797381c"
        },
        oracle: {
            LAND: {
                oracle: "0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8", //replace before deployment
                jobID: "d5270d1c311941d0b08bead21fea7747", //replace before deployment
            }
        }
    }
}