# D33D token

D33D is an ERC20 token inherit from Openzeppelin with additional funtion as below:

### Fee on transfer through DeX

A certain percentage of fee will be impose to any transfer that through decentralized exchange. Default is off. There is possible to whitelist certain address to not impose by fee when transfer through DeX.

### Maximum of amount minted

A cap is set and the token contract can't mint more than the cap.

### Anti-snipe by lock the transfer

The transfer function will only available at random time after first liquidity added before announce to public. This is to prevent bot manipulate the token price.
