#!/usr/bin/sh

function restart_ganache() {
  echo "Restart ganache-cli..."
  if [ $ganache_pid ]
  then
    echo "kill old ganache..."
    kill -9 $ganache_pid
  fi

  ganache-cli -i test > /dev/null &
  ganache_pid=$!

  sleep 5
}

truffle compile
restart_ganache

echo "truffle test Bank..."
truffle test test/testComplexBank.js test/token/* test/testOracle.js --network testBank

restart_ganache

echo "truffle test Exchanger..."
truffle test test/testLoans.js test/testComplexExchanger.js test/testDeposit.js --network testExchanger

restart_ganache

echo "truffle test DAO..."
truffle test test/testAssociation.js --network testDAO

kill -9 $ganache_pid