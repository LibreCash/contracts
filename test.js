module.exports = function(callback) {
  console.log("Hello!",artifacts);

  artifacts.require('./LibreCash.sol').deployed().then(result => {
    console.log(result,result.address);
    callback()
  })
  
}