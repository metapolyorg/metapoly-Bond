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
                oracle: "", //replace before deployment
                jobID: "", //replace before deployment
            }
        }
    },
    testnet: {
        d33d: "0x69bF2A97310Ed205Db362654A051267E76A07b3D",
        fsD33D: "0xfD241B99c3502304cfBAe2bd2C4EFba9f4FF0cFE",
        stakingFlexible: "0x9c4f9a0D98e0e836FC5894FCAEe1d4d001716570",
        treasury: "0x3F9C0bb2488185b03371746CbC872acA5221e7EA",
        distributor: "0x24Abc56F2e25B6407CD47C9C32B76D3f79329A16",
        stakingWarmup: "0x599EB7225B874386136a7159E2B84ba60c683C83",

        bondCalculator: "",
        bondCalculatorStrategy: "",
        bondCalculatorSand: "",
        bondCalculatorMana: "0xb9e6226EFB2e97862c27d1aBE08D8Dd3C71C21eA",
        
        tokens: {
            dai: "",
            usdc:"0xb7a4f3e9097c08da09517b5ab877f7a917224ede",
            usdt: "",
            sand: "",
            mana: "0xa287607883c292117d759b5d2cAf97Fd53259F04"
        },
        NFT: {
            LAND: "0x1A797955928b3EB0205aC07efe59fF9a8dF7dD08"
        },
        bond: {
            USDC_bond: "0xD1dB574679f2a8B1DaBe9dfbA2B7977B7c9DB64b",
            SAND_bond: "",
            MANA_bond: "0x1e71bc7b01f92d2850f825fc68905edec33ccb6c",
            LAND_Bond: "0x6CD5F56913EF5828ca72887e8C3c532302752c13",
        },

        address: {
            DAO:"0x891F4bDc41455CD2491B6950c1A2Ab46021Dd647", //address to receive fee
            admin: "0x891F4bDc41455CD2491B6950c1A2Ab46021Dd647"
        },
        oracle: {
            LAND: {
                oracle: "0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8", //replace before deployment
                jobID: "0x6435323730643163333131393431643062303862656164323166656137373437", //replace before deployment
            },
            SAND: {
                address :"",
            },
            MANA: {
                MANA_ETH: "0x1b93D8E109cfeDcBb3Cc74eD761DE286d5771511",
                ETH_USD: "0x9326BFA02ADD2366b30bacB125260Af641031331"
            }
        }
    }
}