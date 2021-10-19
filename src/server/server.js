import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';

import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


const config = Config['localhost'];
const web3 = new Web3(config.url.replace('http', 'ws'));
const flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
const flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
const ORACLE_COUNT = 40;
const FLIGHT_STATUSES = [0, 10, 20, 30, 40, 50];
let oracles = [];
let flights = [];


let oracleRegFee;
let accounts;
flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event.returnValues);
    if (event && event.returnValues) {
        const index = event.returnValues.index;
        const airline = event.returnValues.airline;
        const flight = event.returnValues.flight;
        const timestamp = event.returnValues.timestamp;

        oracles.filter(oracle => oracle.indexes.indexOf(index) > -1).forEach(oracle => {
            const statusCode = getRandomFlightStatus();
            console.log("flight status", statusCode, "oracle", oracle.oracle);
            return flightSuretyApp.methods.submitOracleResponse(index, airline, flight, timestamp, statusCode).send({from: oracle.oracle, gas: 500000}).catch(e=>console.log(e));
        })
    }
});


const app = express();
app.get('/api', (req, res) => {
   res.send({
      message: 'An API for use with your Dapp!'
    });
});

app.get('/flights', (req, res) => {
    if(flights.length == 0) {
        for (let i = 0; i < accounts.length; i++) {
            const flight = {airline: accounts[i], timestamp: getRandomTime(), flight: generateFlightName()};
            flights.push(flight);
        }
    }
    res.send({
        data: flights
    });
});


const registerOracle = (oracleAddress, fee) => {
  flightSuretyApp.methods.registerOracle().send({from:oracleAddress, value: fee, gas: 500000}).catch(err=> {
      // in case oracle is already registered
      console.log(`Possibly that oracle ${oracleAddress} was already registered`)
      return false;
    }).then((data)=> {
        if(data){
            console.log(`Oracle ${oracleAddress} is successfully registered`);
        }
        return flightSuretyApp.methods.getMyIndexes().call({from: oracleAddress});
 }).catch(console.log).then((indexes)=> {
     console.log(oracles.length,":", indexes);
     oracles.push({oracle: oracleAddress, indexes: indexes});
  });
}

const prepareContractData = () => {
    console.log("accounts:");
     web3.eth.getAccounts().then((acc) => {
            web3.eth.defaultAccount = acc[0];
            console.log("account", acc[0]);
            accounts = acc;
        return flightSuretyData.methods.authorizeContract(config.appAddress).send({from: web3.eth.defaultAccount});

    }).then((data) => {
        return flightSuretyApp.methods.REGISTRATION_FEE().call();
    }).then((data) => {
        oracleRegFee = data;
        console.log("Oracle registration fee", data);
        for(let i = 1; i <= ORACLE_COUNT; i++) {
            registerOracle(accounts[i], oracleRegFee);
        }
    });
}

const getRandomInt = (max) => {
    return Math.floor(Math.random() * max);
}

const getRandomTime = () => {
    return  Math.floor(new Date().getTime() / 1000) + getRandomInt(100000);
}

const generateFlightName = () => {
    const name = (Math.random() + 1).toString(36).substring(2,7);
    return name;
}

const getRandomFlightStatus = () => FLIGHT_STATUSES[getRandomInt(FLIGHT_STATUSES.length)];

prepareContractData();
export default app;


