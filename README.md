<h1 align="center">
	<img width="400" src="http://librebank.com/img/logo-black.svg" alt="Awesome">
	<br>
	<br>
</h1>

## LibreBank Contracts

LibreBank smart-contracts repository.

### Contents:

* `contracts/` - contacts folder
    - `/interfaces` - interfaces and abstract-classes (minimal version used by our DAPP's and external) 
    - `/library` - library and service-function's contracts folder,
    - `/oracles` - Oraclize-based exchanger ETH rate oracles contracts. And 
    - `/oracles/mock` - Mocked version of oracles to test it in local (eg. on testrpc)
    - `/token` - LibreToken (aka LBRS) and LibreCash ERC20 standard tokens.
    - `/zeppelin` - part of OpenZeppelin contracts used as dependencies.

* `migrtations/` - deploy and migrations scripts/
* `test/` - smart-contract tests 

## Getting Started
```sh
git clone https://github.com/LibreCash/contracts && cd contracts
npm install
```
## Deploy contracts
To deploy contracts in network run:
a) To main or test network (eg. Rinkeby) - deploy Oraclize-based oracles contracts. 
```
truffle migrate --network mainnet
```
b) To localnode (eg. testrpc or local geth node) or for testing purposes - deloy contracts and mocked version of oracles.
```
truffle migrate --network development
```
## License
Code released under the [AGPL-3.0](LICENSE).
