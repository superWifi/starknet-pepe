# Pepe memecoin Contracts for Cairo
This is an ERC-20 contract modified according to OpenZeppelin's [implementation](https://github.com/OpenZeppelin/cairo-contracts/blob/cairo-1/src/openzeppelin/token/erc20.cairo) and it features the following characteristics:

-  All tokens are generated through minting.
-  Anyone can call the apply_mint function to mint candidates for free.
-  Every 50 seconds can call a mint and get fixed coin.
-  Coin will be halved after every 400,000 blocks.
-  The total number of tokens is 10,000,000,000, then mint will stop.

## Development

- - Install [cairo-v1.1.1](https://github.com/starkware-libs/cairo/tree/v1.1.1).
- 
- - Set `cairo-test`, `cairo-format` and `starknet-compile` in your $PATH.
- 
- Run command in [Makefile](https://github.com/superWifi/starknet-pepe/blob/master/Makefile).