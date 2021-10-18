import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)
});

(async () => {

  const oracleRegFee = await flightSuretyApp.REGISTRATION_FEE.call();
  console.log(`Registering oracles with fee ${oracleRegFee}`);
  registerOracle(web3.eth.accounts[1], oracleRegFee);
  
  // all of the script.... 

})();

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})


const registerOracle = (oracleAddress, fee) => {
  flightSuretyApp.methods.registerOracle().send({from: web3.eth.defaultAccount, value: fee}).then((data,error)=> {
    if(error) {
      console(`Failed to register oracle ${oracleAddress}`, error);
    } else{
      console.log(`Oracle ${oracleAddress} is succeffuly registered`);
    }
});

}
export default app;


