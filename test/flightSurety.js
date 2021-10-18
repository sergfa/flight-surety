
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeContract(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline("Airline2", newAirline, {from: config.firstAirline});
    }
    catch(e) {}
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });
 
  it('(airline) should succefully submit funds', async () => {
    
    // given
    const fee = await config.flightSuretyApp.MIN_AIRLINE_FUND.call();

    // when
    await config.flightSuretyApp.submitAirlineFunds({from: config.firstAirline, value: fee});
    const expectedResult = await config.flightSuretyData.isActiveAirline.call(config.firstAirline); 
    
    // then
    assert.equal(expectedResult, true, "Airline should be acitvated");
  });


  
  it('(airline) should succefully register airline by another active airline', async () => {
    
    // given
    const newAirline = accounts[2];

    // when
    const expectedResult1 = await config.flightSuretyData.isAirline.call(newAirline);
    await config.flightSuretyApp.registerAirline("Airline2", newAirline,{from: config.firstAirline});
    const expectedResult2 = await config.flightSuretyData.isAirline.call(newAirline); 
    
    // then
    assert.equal(expectedResult1, false, "Address should not be an existing airline before registering...");
    assert.equal(expectedResult2, true, "Address should become an airline after registering...");
  });

  it('(airline) should succefully register airline by consensus of 50%', async () => {
    
    // given
    const fee = await config.flightSuretyApp.MIN_AIRLINE_FUND.call();

    const airline2 = accounts[2];
    const airline3 = accounts[3];
    const airline4 = accounts[4];
    const consensusAirline = accounts[5];

    // when
    await config.flightSuretyApp.submitAirlineFunds({from: airline2, value: fee});
    
    await config.flightSuretyApp.registerAirline("Airline3", airline3,{from: config.firstAirline});
    await config.flightSuretyApp.submitAirlineFunds({from: airline3, value: fee});
    
    await config.flightSuretyApp.registerAirline("Airline4", airline4,{from: config.firstAirline});
    await config.flightSuretyApp.submitAirlineFunds({from: airline4, value: fee});
    
    await config.flightSuretyApp.registerAirline("Consensus Airline", consensusAirline,{from: config.firstAirline});
    const expectedResult1 = await config.flightSuretyData.isAirline.call(consensusAirline); 
    
    await config.flightSuretyApp.registerAirline("Consensus Airline", consensusAirline,{from: airline2});
    const expectedResult2 = await config.flightSuretyData.isAirline.call(consensusAirline); 
    
    // then
    assert.equal(expectedResult1, false, "Address should not be an airline before it registered by 50% of airlines");
    assert.equal(expectedResult2, true, "Address should be an airline after it registered by 50% of airlines");
   
  });


});
