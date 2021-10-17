// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface FlightSuretyDataInterface {
    function registerAirline(string memory name, address account) external;

    function isAirline(address account) external view returns (bool);

    function isActiveAirline(address account) external view returns (bool);

    function getNumberOfAirlines() external view returns (uint256);

    function submitAirlineFunds(address account) external;

    function registerFlight(bytes32 key, address airline) external;

    function registerOracle(address oracle, uint8[3] memory indexes) external;

    function getOracleIndecies(address oracle)
        external
        view
        returns (uint8[3] memory);

    function updateFlightInsurance(
        bytes32 flightKey,
        address passenger,
        uint256 cost
    ) external;

    function withdrawPassengerBalance(address passenger) external;

    function creditInsuree(
        bytes32 flightKey,
        address passenger,
        uint256 amount
    ) external;

    function getPassengerBalance(address passenger)
        external
        view
        returns (uint256);

    function updateFlightStatus(bytes32 flightKey, uint8 statusCode) external;

    function getFlightPassengers(bytes32 flightKey)
        external
        view
        returns (address[] memory);

    function getFlightStatus(bytes32 flightKey) external view returns (uint8);

    function getPassengerInsuranceCost(address passenger, bytes32 flightKey)
        external
        returns (uint256);
}

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    enum VoteActions {
        ADD_AIRLINE
    }

    struct VoteItem {
        uint8 votedCount;
        mapping(address => bool) accounts;
    }

    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
    }

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    uint256 private constant MIN_AIRLINE_FUND = 10 ether;
    bool private _operational;
    mapping(bytes32 => VoteItem) private _votes;
    FlightSuretyDataInterface private _flightSuretyData;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner; // Account used to deploy contract

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    uint256 public constant MAX_INSURANCE = 1 ether;

    mapping(bytes32 => ResponseInfo) private oracleResponses;

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

    modifier requireIsAirlineActive(address account) {
        require(
            _flightSuretyData.isActiveAirline(account),
            "The airline is not activated yet. Submit funds to activate it"
        );
        _;
    }

    modifier requireIsAirline() {
        require(
            _flightSuretyData.isAirline(msg.sender),
            "Sender address is not an Airline"
        );
        _;
    }

    /****************************************************************************************** */
    /*                                       EVENTS                                              */
    /*********************************************************************************************/

    event OperationalChanged(bool value); // emitted when operational status changes
    event AirlineRegistered(string airplaneName, bool success, uint256 votes); // emitted when airline registered
    event AirlineSubmittedFunds(address account); // fired when airline transfers funds to the contract
    event FlightRegistered(address airline, string flight, uint256 timestamp); // fired when flight is registered
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

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address dataContractAddress) {
        require(
            dataContractAddress != address(0),
            "Should be a valid address of the data contract"
        );
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
        require(
            _operational != value,
            "New value should be different than current value"
        );
        _operational = value;
        emit OperationalChanged(value);
    }

    function vote(
        bytes32 key,
        address account,
        uint256 total
    ) private returns (bool) {
        require(
            _votes[key].accounts[account] == false,
            "Account already voted"
        );
        VoteItem storage voteItem = _votes[key];
        uint256 count = voteItem.votedCount + 1;
        bool allowed = ((count * 100) / total) >= 50;
        if (allowed) {
            // prepare mapping for the next voting...
            delete (_votes[key]);
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
        external
        requireIsOperational
        requireIsAirline
        returns (bool success, uint256 votes)
    {
        uint256 airlinesCount = _flightSuretyData.getNumberOfAirlines();

        if (airlinesCount < 4) {
            _flightSuretyData.registerAirline(name, account);
            success = true;
        } else {
            bytes32 key = keccak256(
                abi.encodePacked(uint8(VoteActions.ADD_AIRLINE), name)
            );
            success = vote(key, msg.sender, airlinesCount);
            votes = _votes[key].votedCount;
            if (success) {
                _flightSuretyData.registerAirline(name, account);
            }
        }

        emit AirlineRegistered(name, success, votes);

        return (success, votes);
    }

    function submitAirlineFunds()
        external
        payable
        requireIsOperational
        requireIsAirline
    {
        require(msg.value >= MIN_AIRLINE_FUND);
        _flightSuretyData.submitAirlineFunds(msg.sender);
        emit AirlineSubmittedFunds(msg.sender);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(
        address airline,
        string memory flight,
        uint256 timestamp
    )
        external
        requireIsOperational
        requireIsAirline
        requireIsAirlineActive(airline)
    {
        bytes32 key = keccak256(abi.encodePacked(airline, flight, timestamp));
        _flightSuretyData.registerFlight(key, airline);
        emit FlightRegistered(airline, flight, timestamp);
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        _flightSuretyData.updateFlightStatus(flightKey, statusCode);
    }

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
        ResponseInfo storage oracleResponse = oracleResponses[key];
        oracleResponse.requester = msg.sender;
        oracleResponse.isOpen = true;
        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Register an oracle with the contract
    function registerOracle() external payable requireIsOperational {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");
        uint8[3] memory indexes = generateIndexes(msg.sender);
        _flightSuretyData.registerOracle(msg.sender, indexes);
    }

    function submitOracleResponse(
        uint8 index,
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) external requireIsOperational {
        //*************Oracles are registered via server, so we do not have any real oracles in the system ******************* */
        uint8[3] memory idx = _flightSuretyData.getOracleIndecies(msg.sender);
        require(
            (idx[0] == index) || (idx[1] == index) || (idx[2] == index),
            "Invalid index"
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

    function buyInsurance(
        address airline,
        string memory flight,
        uint256 timestamp
    ) external payable requireIsOperational requireIsAirlineActive(airline) {
        require(
            msg.value > 0 && msg.value <= MAX_INSURANCE,
            "Invalid insurance value, must be between 0 and 1 ether"
        );
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        _flightSuretyData.updateFlightInsurance(
            flightKey,
            msg.sender,
            msg.value
        );
    }

    function payToPassenger() external requireIsOperational {
        uint256 balance = _flightSuretyData.getPassengerBalance(msg.sender);
        require(balance > 0, "Balance of the passanger is zero");
        _flightSuretyData.withdrawPassengerBalance(msg.sender);
        payable(msg.sender).transfer(balance);
    }

    function creditPassengers(
        address airline,
        string memory flight,
        uint256 timestamp
    ) external requireIsOperational {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        uint8 statusCode = _flightSuretyData.getFlightStatus(flightKey);
        require(
            statusCode == STATUS_CODE_LATE_AIRLINE,
            "Status code should be Late by Airline"
        );
        address[] memory passengers = _flightSuretyData.getFlightPassengers(
            flightKey
        );
        for (uint256 i = 0; i < passengers.length; i += 1) {
            uint256 insCost = _flightSuretyData.getPassengerInsuranceCost(
                passengers[i],
                flightKey
            );
            uint256 amount = (insCost * 3) / 2;
            _flightSuretyData.creditInsuree(flightKey, passengers[i], amount);
        }
    }

    function getMyIndexes() external view returns (uint8[3] memory) {
        uint8[3] memory idx = _flightSuretyData.getOracleIndecies(msg.sender);
        return idx;
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account)
        internal
        returns (uint8[3] memory)
    {
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

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund() public payable {}

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    fallback() external payable {
        fund();
    }
}
