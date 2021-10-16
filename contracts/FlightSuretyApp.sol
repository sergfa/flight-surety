// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface FlightSuretyDataInterface {
    function registerAirline(string memory name, address account) external;
     function isAirline(address account) external view returns(bool);
    function getNumberOfAirlines() external view returns(uint);
    function submitAirlineFunds(string memory name) external payable;
}

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {

    enum VoteActions {OPERATIONAL, ADD_AIRLINE}

    struct VoteItem {
        uint8 votedCount;
        mapping(address => bool) accounts; 
    }
    
    bool private _operational;
    mapping(bytes32 => VoteItem) private _votes;
    FlightSuretyDataInterface private _flightSuretyData;
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner; // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    modifier requireIsOperational() {
        require(_operational, "Contract is currently not operational");
        _;
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireNotEmptyAddress(address account) {
        require(account != address(0), "Should be valid addrress");
        _;
    }

    /****************************************************************************************** */
    /*                                       EVENTS                                              */
    /*********************************************************************************************/

    event OperationalChanged(bool value); // emitted when operational status changes
    event AirlineRegistered(string airplaneName, bool success, uint votes); // emitted when airline registered

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address dataContractAddress) {
        require(dataContractAddress != address(0), "Should be valid address of data contract");
        contractOwner = msg.sender;
        _flightSuretyData = FlightSuretyDataInterface(dataContractAddress);
        _operational = true;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return _operational;
    }

    function setOperational(bool value) public requireContractOwner {
        require(_operational != value, "New value should be different than current value");
        _operational  = value;
        emit OperationalChanged(value);
    }

    function vote(bytes32 key, address account, uint total) private returns (bool) {
        require(_votes[key].accounts[account] == false, "Account already voted");
        VoteItem storage voteItem = _votes[key];
        uint count = voteItem.votedCount + 1;
        bool allowed = (count * 100 / total ) >= 50;
        if(allowed) {
            // prepare mapping for the next voting...
            delete( _votes[key]);
        } else {
            voteItem.votedCount++;
            voteItem.accounts[account] = true;
        } 
        return allowed;   
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline(string memory name, address account)
        requireNotEmptyAddress(account)
        external
        returns (bool success, uint256 votes)
    {
        require(_flightSuretyData.isAirline(msg.sender), "Sender shoud be an Airline");
        uint airlinesCount = _flightSuretyData.getNumberOfAirlines();
        
        if (airlinesCount < 4) {
            _flightSuretyData.registerAirline(name, account);
            success = true;
        } else {
            bytes32  key = keccak256(abi.encodePacked(uint8(VoteActions.ADD_AIRLINE), name));
            success = vote(key, msg.sender, airlinesCount);
            votes = _votes[key].votedCount;
            if(success) {
                  _flightSuretyData.registerAirline(name, account);
            }
        }
            
        emit AirlineRegistered(name, success, votes);
        
        return (success, votes);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight() external pure {}

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal pure {}

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp
    ) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        ResponseInfo storage oracleResponse  = oracleResponses[key];
        oracleResponse.requester = msg.sender;
        oracleResponse.isOpen = true;
        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3] memory) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
        ) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3] memory) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
     // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;
        unchecked {
            nonce++;
        }
        return
            uint8(
                uint256(keccak256(abi.encodePacked(account, nonce))) % maxValue
            );
    }

    // endregion
}
