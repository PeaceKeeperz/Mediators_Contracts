//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
 *This will be removed and the contract will inherit the mediator.sol
 *We can still use the interface method if we want to deploy more than one contract
 */
interface IMediator {
    function getAllMediatorsByCategory(uint256 _category)
        external
        view
        returns (address[] memory);

    function minusCaseCount(uint256 _id) external returns (bool);

    function addCaseCount(uint256 _id) external returns (bool);
}

contract Nmediation is VRFConsumerBaseV2, Ownable {
    IMediator immutable  i_Mediator;
    VRFCoordinatorV2Interface immutable i_COORDINATOR;
    //Rinkeby coordinator, These test values are coming from https://docs.chain.link/docs/vrf-contracts/#configurations
    address constant c_vrfCoordinator =
        0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    //subscription id, gotten from when you subscribe for LINK
    uint64 immutable i_subscriptionId; //Subscription ID 4079
    bytes32 constant c_keyHash =
        0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint32 constant c_callbackGasLimit = 100000;
    uint16 constant c_requestConfirmations = 3;
    uint32 constant c_numWords = 1;
    uint256[] public s_randomWords;
    uint256 public requestId;

    /******** Struct Varables *********/
    uint256 public caseId;
    uint256 public sessionId; // session id

    uint256 constant numberOfSessions = 3;

    enum Category {
        junior,
        intermediate,
        expert
    }

    /********** Mappings **************************/

    mapping(uint256 => mapping(uint256 => Session)) public sessions; //mapping caseId => sessionId => session struct;

    mapping(uint256 => uint256) private ethBalances; //This container keep tracks of the amount eth for each case
    mapping(uint256 => Case) public cases; //Holds all the information for a particular case id
    mapping(uint256 => bool) public sessionStarted; //Checks if a case id session has been started
    mapping(uint256 => bool) public paymentAccepted; //Checks if payment has been accepted for a case id

    mapping(uint256 => address[]) public firstPartyMembers; //Array of addresses of all the party one members
    mapping(uint256 => address[]) public secondPartyMembers; //Array of addresses of all the party two members

    mapping(uint256 => uint256) private acceptedByFirstParty; //The number of party one members who accepted to pay for a particular case session
    mapping(uint256 => uint256) private acceptedBySecondparty; //The number of party two members who accepted to pay for a particular case session
    mapping(uint256 => bool) public doesCaseExist;
    mapping(uint256 => bool) public doesSessionExist;

    /***** Structs  *******/
    struct Case {
        uint256 caseId;
        address firstParty;
        address secondParty;
        address payable mediator;
        string tokenURI;
        bool caseClosed;
        uint256 caseCreatedAt;
        uint256 numberOfSession;
        uint256[] sessionIds; // session id storage
        uint256 category;
    }

    struct Session {
        uint256 caseId;
        uint256 sessionId;
        address[] firstPartyMembers;
        address[] secondPartyMembers;
        address payable mediator;
        bool sessionClosed;
        uint256 timestamp;
    }

    /*** Events ***/

    event case_Created(
        uint256 _caseId,
        address firstParty,
        address secondParty,
        address mediator,
        string tokenUri,
        bool caseClosed,
        uint256 caseCreatedAt,
        uint256 numberOfSession,
        uint256[] sessionIds,
        uint256 category
    );

    event BookedSession(
        uint256 caseId,
        uint256 sessionId,
        address[] firstPartyMembers,
        address[] secondPartyMembers,
        address payable mediator,
        bool sessionClosed,
        uint256 timestamp
    );

    event AssignMediator(uint256 _caseId, address _mediator);
    event AssignPartyMembers(
        uint256 sessionId,
        uint8 partyNumber,
        address[] partyMembers
    );
    event EndSession(uint256 caseId, uint256 sessionId);
    event SecondPartyJoin(uint256 caseId, address secondParty);

    /** Custom Errors **/
    error Mediation__CaseDoesNotExistOrCaseIsClosed();
    error Mediation__OnlyMediatorCanDoThis();
    error Mediation__CannotReceivePaymentPartiesNeedToApprove();
    error Mediation__FailedToSendPayment();
    error Mediation__FailedToWithdrawFunds();
    error Mediation__NotEnoughFundsInContract();
    error Mediation__YouAreNotPartOfThisSession();
    error Mediation__BookedSessionAlreadyStarted();
    error Mediation__BookedSessionIsStillclosed();
    error Mediation__FailedToRefundFundsToParty1();
    error Mediation__FailedToRefundFundsToParty2();

    error Mediation_SessionDoesNotExist(); //new error

    /*
     * WE MAY NEED CHAINLINK DATA FEED TO GET THE CURRENT PRICE OF ETH AND KNOW WHAT TO PRICE USERS
     */
    uint256 juniorMediatorPrice = 0.001 ether;
    uint256 intermediateMediatorPrice = 0.002 ether;
    uint256 expertMediatorPrice = 0.003 ether;

    constructor(uint64 subscriptionId, address _mediator)
        VRFConsumerBaseV2(c_vrfCoordinator)
    {
        i_COORDINATOR = VRFCoordinatorV2Interface(c_vrfCoordinator);
        i_subscriptionId = subscriptionId;
        i_Mediator = IMediator(_mediator);
    }


    /***
    * @notice create case - will create a mediation case to be filled with mediator and sessions
    *
    * @param _category uint256 category level number for type of mediator they want. lvl 1,2,3.
    * @param _secondPartyMember address of the second party member for the case
    * @param _sessionId  uint256 [] that should be empty. This is to add sessions to case later with create session function.
    * @param numberOfSession number of session to use for payByCategory. 
    ***/
    function createCase(
        uint256 _category,
        uint256[] _sessionId,
    ) external payable payByCategory(_category, numberOfSessions) {
        caseId++;
        ethBalances[caseId] += msg.value;

        cases[caseId] = Case({
            caseId: caseId,
            firstParty: payable(msg.sender),
            secondParty: payable(address(0)),
            mediator: payable(address(0)),
            tokenURI: "tokenuri",
            caseClosed: true,
            caseCreatedAt: block.timestamp,
            numberOfSession: 0, //this would need to change
            sessionIds: _sessionId,
            category: _category
        });

        doesCaseExist[caseId] = true;

        emit case_Created(
            caseId,
            cases[caseId].firstParty,
            cases[caseId].secondParty,
            cases[caseId].mediator,
            cases[caseId].tokenURI,
            cases[caseId].caseClosed,
            cases[caseId].caseCreatedAt,
            cases[caseId].numberOfSession,
            cases[caseId].sessionIds,
            cases[caseId].category
        );
    }

    /*
    * The other party has to join the case before mediator will be able to start a session
    * When joining, he has to specify the case that he is joining and pay the fee accordingly
    */
    function joinCaseAsSecondParty(uint256 _caseId) external payable payByCategory(cases[_caseId].category, numberOfSessions){
        if(!doesCaseExist[_caseId]) {
            revert Mediation__CaseDoesNotExistOrCaseIsClosed();
        }
        ethBalances[_caseId] += msg.value;
        cases[_caseId].secondParty = payable(msg.sender);
        cases[_caseId].caseClosed = false;

        emit SecondPartyJoin(_caseId, msg.sender);
    }

    /*
     * This calls the mediator contracts and get a random winner
     * The selected mediator is then added to the case
     */
    function assignMediator(uint256 _category, uint256 _caseId) external {
        _requestRandomWords();
        address[] memory mediators = i_Mediator.getAllMediatorsByCategory(
            _category
        );
        uint256 selectedMediatorIndex = s_randomWords[0] % mediators.length;
        require(
            i_Mediator.addCaseCount(selectedMediatorIndex),
            "error updating caseCount"
        );
        address selectedMediator = mediators[selectedMediatorIndex];
        cases[_caseId].mediator = payable(selectedMediator);
        emit AssignMediator(_caseId, selectedMediator);
    }

    /**
     * @notice Starts a new session for a case.
     *
     * @param _caseId  uint of the caseId
     * @param _firstPartyMembers address [] of all the first party members who attended the session
     * @param _secondPartyMembers address [] of all the second party members who attended the session
     */
    function createSession(
        uint256 _caseId,
        address[] memory _firstPartyMembers,
        address[] memory _secondPartyMembers
    ) public onlyMediator(_caseId) {
        if (!doesCaseExist[_caseId]) {
            revert Mediation__CaseDoesNotExistOrCaseIsClosed();
        } else {
            sessionId++;
            sessions[_caseId][sessionId] = Session({
                caseId: _caseId,
                sessionId: sessionId,
                firstPartyMembers: _firstPartyMembers,
                secondPartyMembers: _secondPartyMembers,
                mediator: payable(msg.sender),
                sessionClosed: false,
                timestamp: block.timestamp
            });

            Case storage myCase = cases[_caseId];
            myCase.sessionIds.push(sessionId); //adds new session to session id array

            doesSessionExist[sessionId] = true;

            emit BookedSession(
                _caseId,
                sessionId,
                _firstPartyMembers,
                _secondPartyMembers,
                payable(msg.sender),
                false,
                block.timestamp
            );
        }
    }

    /**
     * latePartyMembers
     * @notice adds any party memebers who did not get added to the list when the session was started.
     * Typically when someone comes in late.
     *
     * @param _caseId uint256 case ID number for access to case sessions
     * @param _sessionId uint256 session ID number to access specific session
     * @param _partyNumber uint8 1 for first party or 2 for second party
     * @param _partyMembers address [] of the party memebers to add
     *
     */

    function latePartyMembers(
        uint256 _caseId,
        uint256 _sessionId,
        uint8 _partyNumber,
        address[] memory _partyMembers
    ) public onlyMediator(_caseId) {
        if (!doesSessionExist[_sessionId]) {
            revert Mediation_SessionDoesNotExist();
        }
        if (_partyNumber == 1) {
            Session storage session = sessions[caseId][sessionId];
            for (uint8 i = 0; i < _partyMembers.length; i++) {
                session.firstPartyMembers.push(_partyMembers[i]);
            }
        } else {
            Session storage session = sessions[caseId][sessionId];
            for (uint8 i = 0; i < _partyMembers.length; i++) {
                session.secondPartyMembers.push(_partyMembers[i]);
            }
        }
        emit AssignPartyMembers(_sessionId, _partyNumber, _partyMembers);
    }

    /**
     * @notice endSession will change the session boolean sessionClosed to true.
     * which will end the session.
     * @param _caseId uint256 case id number.
     * @param _sessionId uint256 session id number.
     *
     */

    function endSession(uint256 _caseId, uint256 _sessionId)
        public
        onlyMediator(_caseId)
    {
        if (!doesSessionExist[_sessionId]) {
            revert Mediation_SessionDoesNotExist();
        } else {
            Session storage session = sessions[caseId][sessionId];
            session.sessionClosed = true;
        }

        emit EndSession(_caseId, _sessionId);
    }

    //LETS DISCUSS MORE ON THIS FEATURE

    /*
    * Both parties involved, have to accept to pay the mediator before the mediator can get paid when he ends the session
    */
    function acceptPayment(uint256 _caseId) external {
        if(cases[_caseId].firstParty == msg.sender) {
            acceptedByFirstParty[_caseId] = 1;
        }

        if(cases[_caseId].secondParty == msg.sender){
            acceptedBySecondparty[_caseId] = 1;
        }

        if((acceptedByFirstParty[_caseId] + acceptedBySecondparty[_caseId]) == 2){
            paymentAccepted[_caseId] = true;
        }else{
            paymentAccepted[_caseId] = false;
        }
    }



    /*
     * A modifier to receive payment,
     * Mediators use this to receive their payments when they end a session
     */
    modifier receivePayment(uint256 _caseId) {
        _;
        uint256 balance = ethBalances[_caseId] / numberOfSessions;
        uint256 ethToSendToMediator = (balance * 90) / 100; //90%
        (bool success, ) = cases[_caseId].mediator.call{
            value: ethToSendToMediator
        }("");
        if (!success) {
            revert Mediation__FailedToSendPayment();
        }
    }

    /*
     * Parties involved use this to pay for a case with respect to the category
     */
    modifier payByCategory(uint256 category, uint256 _numberOfSessions) {
        if (category == uint256(Category.junior)) {
            require(
                msg.value == (juniorMediatorPrice / 2) * _numberOfSessions,
                "Not enough or too much eth to create a case"
            );
        } else if (category == uint256(Category.intermediate)) {
            require(
                msg.value ==
                    (intermediateMediatorPrice / 2) * _numberOfSessions,
                "Not enough or too much eth to create a case"
            );
        } else if (category == uint256(Category.expert)) {
            require(
                msg.value == (expertMediatorPrice / 2) * _numberOfSessions,
                "Not enough or too much eth to create a case"
            );
        }
        _;
    }

    //Get random word.
    function _requestRandomWords() internal {
        // Will revert if subscription is not set and funded.
        requestId = i_COORDINATOR.requestRandomWords(
            c_keyHash,
            i_subscriptionId,
            c_requestConfirmations,
            c_callbackGasLimit,
            c_numWords
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        s_randomWords.push(randomWords[0]);
    }

    modifier payFullFeeByCategory(uint256 category, uint256 _numberOfSessions) {
        if (category == uint256(Category.junior)) {
            require(
                msg.value == juniorMediatorPrice * _numberOfSessions,
                "Not enough or too much eth to create a case"
            );
        } else if (category == uint256(Category.intermediate)) {
            require(
                msg.value == intermediateMediatorPrice * _numberOfSessions,
                "Not enough or too much eth to create a case"
            );
        } else if (category == uint256(Category.expert)) {
            require(
                msg.value == expertMediatorPrice * _numberOfSessions,
                "Not enough or too much eth to create a case"
            );
        }
        _;
    }

    modifier onlyMediator(uint256 _caseId) {
        if (msg.sender != cases[_caseId].mediator) {
            revert Mediation__OnlyMediatorCanDoThis();
        }
        _;
    }

    modifier onlyMediatorOrOwner(uint256 _caseId) {
        require(
            msg.sender == cases[_caseId].mediator || msg.sender == owner(),
            "Only Mediator or Owner can do this"
        );
        _;
    }

    receive() external payable {}

    fallback() external payable {}
}
