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
            usdc:"0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
            usdt: "",
            D33D_USDC: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        },
        NFT: {
            LAND: "0x50f5474724e0Ee42D9a4e711ccFB275809Fd6d4a"
        },
        bond: {
            LAND_Bond: "0x4b6aB5F819A515382B0dEB6935D793817bB4af28",
            D33D_USDC_BOND: "0x18E317A7D70d8fBf8e6E893616b52390EbBdb629"
        },

        address: {
            DAO:"0x575409F8d77c12B05feD8B455815f0e54797381c", //address to receive fee
            admin: "0x575409F8d77c12B05feD8B455815f0e54797381c"
        },
        oracle: {
            LAND: {
                oracle: "0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8", //replace before deployment
                jobID: "0x6435323730643163333131393431643062303862656164323166656137373437", //replace before deployment
            },
        },
        router:"0x720472c8ce72c2A2D711333e064ABD3E6BbEAdd3"
    },
    testnet: {
        d33d: "0xC6c0E14c02C2dBd4f116230f01D03836620167B9",
        fsD33D: "0x97e9e9BB83132f36D305795d5634b356fe76aF49",//"0xfD241B99c3502304cfBAe2bd2C4EFba9f4FF0cFE",
        stakingFlexible: "0x9b9B154117D602568E0d5DC8444801368cE6d03F",//"0x9c4f9a0D98e0e836FC5894FCAEe1d4d001716570",
        treasury: "0xE3e7A4B35574Ce4b9Bc661cD93e8804Da548932a",
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
            mana: "0xa287607883c292117d759b5d2cAf97Fd53259F04",
            D33D_USDC:"",
        },
        NFT: {
            LAND: "0x1A797955928b3EB0205aC07efe59fF9a8dF7dD08"
        },
        bond: {
            USDC_bond: "0xD1dB574679f2a8B1DaBe9dfbA2B7977B7c9DB64b",
            SAND_bond: "",
            MANA_bond: "0x1e71bc7b01f92d2850f825fc68905edec33ccb6c",
            LAND_Bond: "0x6CD5F56913EF5828ca72887e8C3c532302752c13",
            D33D_USDC_BOND: ""
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
        },
        router:""
    }
}