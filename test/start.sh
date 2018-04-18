#!/usr/bin/sh

function restart_ganache() {
  echo "Start ganache-cli..."
  if [ $ganache_pid ]
  then
    echo "Kill old ganache-cli instance..."
    kill -9 $ganache_pid
  fi

  ganache-cli -i test > /dev/null &
  ganache_pid=$!

  sleep 5
}

restart_ganache

echo "[Truffle-test] Running tests of tokens LibreCash & LBRS"
truffle test test/token/* --network testBank
echo "[Truffle-test] Running tests of Oraclize-like oracles"
truffle test test/testOracle.js --network testBank

restart_ganache

echo "[Truffle-test] Running tests of ComplexExchanger (LibreCash Exchanger)"
truffle test test/testComplexExchanger.js --network testExchanger

kill -9 $ganache_pid