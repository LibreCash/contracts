#!/usr/bin/sh

#ganache-cli -i test &
echo "truffle compile..."
truffle compile

echo "truffle migrate Bank..."
truffle migrate --network testBank > /dev/null

echo "truffle test..."
truffle test test/testComplexBank.js test/token/* test/testOracle.js

#echo "truffle migrate DAO..."
#truffle migrate --network testDAO > /dev/null

#echo "truffle test..."
#truffle test test/testAssociation.js

echo "truffle migrate Exchanger..."
truffle migrate --network testExchanger > /dev/null

echo "truffle test..."
truffle test test/testComplexExchanger.js test/testDeposit.js test/testLoans.js

