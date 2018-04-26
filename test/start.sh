#!/usr/bin/sh

function restart_ganache() {
  echo "Start ganache-cli..."
  if [ $ganache_pid ]
  then
    echo "kill old ganache-cli instance..."
    kill -9 $ganache_pid
  fi

  ganache-cli -i test > /dev/null &
  ganache_pid=$!

  sleep 5
}

truffle compile --reset --compile-all
restart_ganache

echo "[Truffle-test] Running tests LibreBank & Oraclize-like oracles"
truffle test test/testComplexBank.js test/token/* test/testOracle.js --network testBank

restart_ganache

echo "[Truffle-test] Running tests of ComplexExchanger (LibreCash Exchanger)"
truffle test test/testLoans.js test/testComplexExchanger.js test/testDeposit.js --network testExchanger

restart_ganache

echo "[Truffle-test] Running tests of DAO (Association contract)"
truffle test test/testAssociation.js --network testDAO

kill -9 $ganache_pid