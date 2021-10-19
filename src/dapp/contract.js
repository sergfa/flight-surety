import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
        this.flights = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0]; //owner is also an airline

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(airline, flight, timestamp, callback) {
        let self = this;
        let payload = {
            airline: airline,
            flight: flight,
            timestamp: timestamp
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner, gas: 500000}, (error, result) => {
                callback(error, payload);
            });
    }

    registerAirline(name, airline, callback) {
        let self = this;
        let payload = {
            airline: airline,
            name: name,
        }
        self.flightSuretyApp.methods
            .registerAirline(payload.name, payload.airline)
            .send({ from: this.owner, gas: 500000}, (error, result) => {
                callback(error, payload);
            });
    }

    submitAirlineFunds(airline,value, callback) {
        let self = this;
        let payload = {
            airline: airline,
            value: this.web3.utils.toWei(value, "ether"),
        }
        self.flightSuretyApp.methods
            .submitAirlineFunds()
            .send({ from: payload.airline, value: payload.value, gas: 500000}, (error, result) => {
                callback(error, result);
            });
    }

    registerFlight(airline, flight, timestamp, callback) {
        let self = this;
        self.flightSuretyApp.methods.registerFlight(airline, flight, timestamp)
            .send({gas: 500000, from: airline}, (error, result) => {
                callback(error, result);
            });
    }

    buyInsurance(airline, flight, timestamp, value, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .buyInsurance(airline, flight, timestamp)
            .send({gas: 500000, from: self.passengers[0], value: self.web3.utils.toWei(value, "ether")}, (error, result) => {
                callback(error, result);
            });
    }

    fetchFlights() {
        if(!this.flights.length) {
            this.airlines.forEach(airline => {
                for (let i = 0; i < 10; i += 1) {
                    this.flights.push({
                        airline: airline,
                        timestamp: Math.floor(this.getRandomTime() / 1000),
                        flight: this.generateFlightName()
                    });
                }
            });
        }
        return this.flights;
    }

    getRandomInt = (max) => {
        return Math.floor(Math.random() * max);
    }

    getRandomTime = () => {
        return  Math.floor(new Date().getTime()) + this.getRandomInt(100000);
    }

    generateFlightName = () => {
        const name = (Math.random() + 1).toString(36).substring(2,7);
        return name;
    }

}