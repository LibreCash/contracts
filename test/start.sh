#!/usr/bin/sh

ganache-cli -i test > /dev/null &
ganache_pid=$!

sleep 5

echo "truffle test Bank..."
truffle test test/testComplexBank.js test/token/* test/testOracle.js --network testBank

kill -9 $ganache_pid

ganache-cli -i test > /dev/null &
ganache_pid=$!

sleep 5 > /dev/null

echo "truffle test Exchanger..."
truffle test test/testLoans.js test/testComplexExchanger.js test/testDeposit.js --network testExchanger

kill -9 $ganache_pid > /dev/null

ganache-cli -i test > /dev/null &
ganache_pid=$!

sleep 5 > /dev/null

echo "truffle test DAO..."
truffle test test/testAssociation.js --network testDAO

kill -9 $ganache_pid