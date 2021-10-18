const flightSuretyApp = artifacts.require("FlightSuretyApp");
const flightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function(deployer) {

    let firstAirlineAddress = '0x5FfF5C8c4BCfBE1c67EF487Ca7911062f05aa1dE'; // replace with address from your network
    let firstAirlineName = 'ELAL';
    
    deployer.deploy(flightSuretyData, firstAirlineAddress, firstAirlineName)
    .then(() => {
        return deployer.deploy(flightSuretyApp,flightSuretyData.address)
                .then(() => {
                    let config = {
                        localhost: {
                            url: 'http://localhost:8545',
                            dataAddress: flightSuretyData.address,
                            appAddress: flightSuretyApp.address
                        }
                    }
                    fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                    fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                });
    });
}