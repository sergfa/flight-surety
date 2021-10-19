// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlightSuretyData {
    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    struct Airline {
        address account;
        bool funded;
        bool registered;
    }

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    struct Passenger {
        uint256 balance;
        bool registered;
        mapping(bytes32 => FlightInsurance) insurances;
    }

    struct FlightInsurance {
        uint256 cost;
        bool registered;
        bool credited;
    }

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    mapping(string => Airline) private _airlines; // Maps the name of airline to its data
    mapping(address => string) private _airlinesAccounts; // Maps airline address to its name
    uint256 private _airlinesCount; // Number of registred airlines
    mapping(address => bool) private _authorizedContracts; // Defines if contract is authorized to use this data contract
    // Track all registered oracles
    mapping(address => Oracle) private _oracles;
    // Track all flights
    mapping(bytes32 => Flight) private _flights;
    // Maps flight key to insurees
    mapping(bytes32 => address[]) _flightPassengers;
    mapping(address => Passenger) _passengers;

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
        require(
            _authorizedContracts[msg.sender],
            "Contract is not authorized to use this contract"
        );
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

    function authorizeContract(address contractAddress) public requireContractOwner requireIsOperational {
        //require(_authorizedContracts[contractAddress] == false, "Contract already authorized");
        _authorizedContracts[contractAddress] = true;
    }

    function deauthorizeContract(address contractAddress) public requireContractOwner requireIsOperational {
        require(_authorizedContracts[contractAddress], "Contract  is not authorized");
        _authorizedContracts[contractAddress] = false;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(string memory name, address account)
        external
        requireIsOperational
        requireContractAuthorized
    {
        require(
            _airlines[name].registered == false,
            "Airline already regestered"
        );
        _registerAirline(name, account);
    }

    function submitAirlineFunds(address account)
        external
        requireIsOperational
        requireContractAuthorized
    {
        string memory name = _airlinesAccounts[account];
        require(_airlines[name].registered, "Airline is not registered");
        _airlines[name].funded = true;
    }

    function isAirline(address account) external view returns (bool) {
        string memory name = _airlinesAccounts[account];
        return _airlines[name].registered;
    }

    function isActiveAirline(address account) external view returns (bool) {
        string memory name = _airlinesAccounts[account];
        return _airlines[name].funded;
    }

    function getNumberOfAirlines() external view returns (uint256) {
        return _airlinesCount;
    }

    function registerFlight(bytes32 key, address airline)
        external
        requireIsOperational
        requireContractAuthorized
    {
        require(
            _flights[key].isRegistered == false,
            "Flight already registered"
        );
        _flights[key].isRegistered = true;
        _flights[key].airline = airline;
    }

    function updateFlightStatus(bytes32 flightKey, uint8 statusCode)
        external
        requireIsOperational
        requireContractAuthorized
    {
        require(_flights[flightKey].isRegistered == true, "Flight is not registered");
        _flights[flightKey].statusCode = statusCode;
        _flights[flightKey].updatedTimestamp = block.timestamp;
    }

    function registerOracle(address oracle, uint8[3] memory indexes)
        external
        requireIsOperational
        requireContractAuthorized
    {
        require(
            _oracles[oracle].isRegistered == false,
            "Oracle already registered"
        );
        Oracle storage o  = _oracles[oracle];
        o.isRegistered = true;
        o.indexes = indexes;
    }

    function getOracleIndecies(address oracle)
        external
        view
        returns (uint8[3] memory)
    {
        require(_oracles[oracle].isRegistered == true, "Oracle is not registered");
        return _oracles[oracle].indexes;
    }

    function updateFlightInsurance(
        bytes32 flightKey,
        address passenger,
        uint256 cost
    ) external requireIsOperational requireContractAuthorized {
        require(
            _passengers[passenger].insurances[flightKey].registered == false,
            "Passenger already registered to the flight"
        );
        if (!_passengers[passenger].registered) {
            _passengers[passenger].registered = true;
        }
        _passengers[passenger].insurances[flightKey].registered = true;
        _passengers[passenger].insurances[flightKey].cost = cost;
        _flightPassengers[flightKey].push(passenger);
    }

    function getFlightPassengers(bytes32 flightKey)
        external
        view
        returns (address[] memory)
    {
        require(_flights[flightKey].isRegistered == true, "Flight is not registered");
        return _flightPassengers[flightKey];
    }

    function getFlightStatus(bytes32 flightKey) external view returns (uint8) {
        require(_flights[flightKey].isRegistered == true, "Flight is not registered");
        return _flights[flightKey].statusCode;
    }

    function creditInsuree(
        bytes32 flightKey,
        address passenger,
        uint256 amount
    ) external requireIsOperational requireContractAuthorized {
        require(
            _passengers[passenger].insurances[flightKey].registered,
            "Passenger is not registered to the flight"
        );
        require(
            _passengers[passenger].insurances[flightKey].credited == false,
            "Passenger is already credited"
        );
        _passengers[passenger].insurances[flightKey].credited = true;
        _passengers[passenger].balance += amount;
    }

    function withdrawPassengerBalance(address passenger)
        external
        requireIsOperational
        requireContractAuthorized
    {
        require(
            _passengers[passenger].registered,
            "Passenger is not registered"
        );
        _passengers[passenger].balance = 0;
    }

    function getPassengerBalance(address passenger)
        external
        view
        returns (uint256)
    {
        require(
            _passengers[passenger].registered,
            "Passenger is not registered"
        );
        return _passengers[passenger].balance;
    }

    function getPassengerInsuranceCost(address passenger, bytes32 flightKey)
        external
        view
        returns (uint256)
    {
        require(
            _passengers[passenger].registered,
            "Passenger is not registered"
        );
        require(
            _passengers[passenger].insurances[flightKey].registered,
            "Passenger is not registered to the flight"
        );
        return _passengers[passenger].insurances[flightKey].cost;
    }

    function _registerAirline(string memory name, address account) private {
        Airline storage airline = _airlines[name];
        airline.account = account;
        airline.registered = true;
        _airlinesAccounts[account] = name;
        _airlinesCount++;
    }
}
