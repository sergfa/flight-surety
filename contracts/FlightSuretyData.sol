// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlightSuretyData {

    
    struct Airline {
        address account;
        bool funded;
        bool registered;
    }
    
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    mapping(string => Airline) private _airlines; // Maps the name of airline to its data
    mapping(address => bool) private _airlinesAccounts; // Defines if address of airline is regestered
    uint private _airlinesCount; // Number of registred airlines
    mapping(address => bool) private _authorizedContracts; // Defines if contract is authorized to use this data contract
  
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address airlineAddress, string memory airlineName) {
        contractOwner = msg.sender;
        _registerAirline(airlineName, airlineAddress);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireContractAuthorized() {
        require(_authorizedContracts[msg.sender], "Contract is not authorized to use this contract");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(string memory name, address account) external requireIsOperational requireContractAuthorized {
       require(_airlines[name].registered, "Airline already regestered");
       _registerAirline(name, account);
    }

    function submitAirlineFunds(string memory name) external payable requireIsOperational requireContractAuthorized {
         _airlines[name].funded = true;
    }
    function isAirline(address account) external view returns(bool) {
        return _airlinesAccounts[account];
    } 

     function getNumberOfAirlines() external view returns(uint) {
         return _airlinesCount;
     }

     function _registerAirline(string memory name, address account) private {
        Airline storage airline = _airlines[name];
        airline.account = account;
        airline.registered = true;
        _airlinesAccounts[account] = true;
        _airlinesCount++;
    }


    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy() external payable {}

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure {}

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external pure {}

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund() public payable {}

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
     fallback() external payable {
        fund();
    }
}
