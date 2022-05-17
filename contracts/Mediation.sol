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
    function getAllMediatorsByCategory(uint256 _category) external view returns(address[] memory);
    function minusCaseCount(uint _id) external returns(bool);
    function addCaseCount(uint _id) external returns(bool);
}

contract Mediation is VRFConsumerBaseV2, Ownable {
    IMediator immutable i_Mediator;
    VRFCoordinatorV2Interface immutable i_COORDINATOR;
    //Rinkeby coordinator, These test values are coming from https://docs.chain.link/docs/vrf-contracts/#configurations
    address constant c_vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    //subscription id, gotten from when you subscribe for LINK
    uint64 immutable i_subscriptionId;  //Subscription ID 4079
    bytes32 constant c_keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint32 constant c_callbackGasLimit = 100000;    
    uint16 constant c_requestConfirmations = 3;
    uint32 constant c_numWords =  1;
    uint256[] public s_randomWords;
    uint256 public requestId;

    struct Case {
        uint256 caseId;
        address payable firstParty;
        address payable secondParty;
        address payable mediator;
        string tokenURI;
        bool caseClosed;
        uint256 caseCreatedAt;
        uint256 numberOfSession;
        bool sessionStarted;
        uint256 category;
    }
    uint256 public nextCaseId;

    /*
    *  Number of default sessions that users have to pay upfront when creating a case,
    *  If they don't use the number of sessions, they will be refunded part of the funds
    */
    uint256 constant numberOfSessions = 3; 

    struct BookedSession {
        uint256 caseId;
        address firstParty;
        address secondParty;
        address payable mediator;
        address[] firstPartyMembers;
        address[] secondPartyMembers;
        bool bookedSessionClosed;
        bool bookedSessionStarted;
        uint256 bookedSessionCreatedAt;
    }


    /*
    * WE MAY NEED CHAINLINK DATA FEED TO GET THE CURRENT PRICE OF ETH AND KNOW WHAT TO PRICE USERS
    */
    uint256 juniorMediatorPrice = 0.001 ether;
    uint256 intermediateMediatorPrice = 0.002 ether;
    uint256 expertMediatorPrice = 0.003 ether;

    mapping(uint256 => uint256) private ethBalances;//This container keep tracks of the amount eth for each case
    mapping(uint256 => Case) public cases; //Holds all the information for a particular case id
    mapping(uint256 => BookedSession) public bookedSessions; //Holds all the information for a particular case id
    mapping(uint256 => bool) public sessionStarted; //Checks if a case id session has been started
    mapping(uint256 => bool) public paymentAccepted; //Checks if payment has been accepted for a case id

    mapping(uint256 => address[]) public firstPartyMembers; //Array of addresses of all the party one members
    mapping(uint256 => address[]) public secondPartyMembers; //Array of addresses of all the party two members

    mapping(uint256 => uint256) private acceptedByFirstParty; //The number of party one members who accepted to pay for a particular case session
    mapping(uint256 => uint256) private acceptedBySecondparty; //The number of party two members who accepted to pay for a particular case session
    mapping(uint256 => bool) private doesCaseExist;

    enum Category {
        junior,
        intermediate,
        expert
    }


    //Events
    event case_Created(
        uint256 _caseId, 
        address firstParty,
        address secondParty,
        address mediator,
        string tokenUri,
        bool caseClosed,
        uint256 caseCreatedAt,
        uint256 numberOfSession,
        bool sessionStarted,
        uint256 category);

    event case_SecondPartyJoint(uint256 _caseId);
    event case_Completed(uint256 _caseId, address[] _winner);
    event case_JoinedCase(uint256 _caseId, uint256 _party, address _address);
    event BookedSessionCreated(uint256 _caseId);
    event JoinedBookedSession(uint256 _caseId);
    event AssignMediator(uint256 _caseId, address _mediator);


    //Custom errors
    error Mediation__PartyDoesNotExist();
    error Mediation__CaseDoesNotExistOrCaseIsClosed();
    error Mediation__OnlyMediatorCanDoThis();
    error Mediation__SessionAlredyStarted();
    error Mediation__ExceededDefaultNumberOfSessions();
    error Mediation__CannotReceivePaymentPartiesNeedToApprove();
    error Mediation__FailedToSendPayment();
    error Mediation__FailedToWithdrawFunds();
    error Mediation__NotEnoughFundsInContract();
    error Mediation__YouAreNotPartOfThisSession();
    error Mediation__BookedSessionAlreadyStarted();
    error Mediation__BookedSessionIsStillclosed();
    error Mediation__FailedToRefundFundsToParty1();
    error Mediation__FailedToRefundFundsToParty2();


    constructor(uint64 subscriptionId, address _mediator) VRFConsumerBaseV2(c_vrfCoordinator) {
        i_COORDINATOR = VRFCoordinatorV2Interface(c_vrfCoordinator);
        i_subscriptionId = subscriptionId;
        i_Mediator = IMediator(_mediator);
    }

    //discuss, if two users are calling this function at the same time, what will happened with the Id
    
    /*
    * One of the parties involved will create a case specifying the category of the case
    * From the category, we will be able to get a mediator 
    * User will pay eth with respect to the fee of the mediator for the numberOfSessions
    */
    function createCase(uint256 _category) external payable payByCategory(_category, numberOfSessions){
        ethBalances[nextCaseId] += msg.value;
        nextCaseId++;
        
        cases[nextCaseId] = Case({
            caseId: nextCaseId,
            firstParty: payable(msg.sender),
            secondParty: payable(address(0)),
            mediator: payable(address(0)),
            tokenURI: "tokenuri",
            caseClosed: true,
            caseCreatedAt: block.timestamp,
            numberOfSession: 0,
            sessionStarted: false,
            category: _category
        });

        doesCaseExist[nextCaseId] = true;

        emit case_Created(nextCaseId,
        cases[nextCaseId].firstParty,
        cases[nextCaseId].secondParty,
        cases[nextCaseId].mediator,
        cases[nextCaseId].tokenURI,
        cases[nextCaseId].caseClosed,
        cases[nextCaseId].caseCreatedAt,
        cases[nextCaseId].numberOfSession,
        cases[nextCaseId].sessionStarted,
        cases[nextCaseId].category);
    }

    /*
    * Company starts a case and pay for the two parties, 
    * They then assign a mediator and he starts the sessions
    */
    function companyCreateCase(uint256 _category, address payable _firstParty, address payable _secondParty) 
        external payable payFullFeeByCategory(_category, numberOfSessions){
            nextCaseId++;
            ethBalances[nextCaseId] += msg.value;
            
            cases[nextCaseId] = Case({
                caseId: nextCaseId,
                firstParty: _firstParty,
                secondParty: _secondParty,
                mediator: payable(address(0)),
                tokenURI: "tokenuri",
                caseClosed: false,
                caseCreatedAt: block.timestamp,
                numberOfSession: 0,
                sessionStarted: false,
                category: _category
            });

            doesCaseExist[nextCaseId] = true;
            emit case_Created(
            nextCaseId,
            cases[nextCaseId].firstParty,
            cases[nextCaseId].secondParty,
            cases[nextCaseId].mediator,
            cases[nextCaseId].tokenURI,
            cases[nextCaseId].caseClosed,
            cases[nextCaseId].caseCreatedAt,
            cases[nextCaseId].numberOfSession,
            cases[nextCaseId].sessionStarted,
            cases[nextCaseId].category);
    }

    /*
    * This calls the mediator contracts and get a random winner
    * The selected mediator is then added to the case
    */
    function assignMediator(uint _category, uint256 _caseId) external {
        _requestRandomWords();
        address[] memory mediators = i_Mediator.getAllMediatorsByCategory(_category);
        uint256 selectedMediatorIndex = s_randomWords[0] % mediators.length;
        require(i_Mediator.addCaseCount(selectedMediatorIndex), "error updating caseCount");
        address selectedMediator = mediators[selectedMediatorIndex];
        cases[_caseId].mediator = payable(selectedMediator);
        emit AssignMediator(_caseId, selectedMediator);
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

        emit case_SecondPartyJoint(_caseId);
    }

    /*
    * This method, other party members can join the case. 
    * When joining the case, they specify the case id and the party that they are joining
    */
    function joinCase(uint256 _caseId, uint256 _party) external {
        if(_party != 1 && _party != 2) {
            revert Mediation__PartyDoesNotExist();
        }
        if(cases[_caseId].caseClosed){
            revert Mediation__CaseDoesNotExistOrCaseIsClosed();
        }

        if(_party == 1) {
            firstPartyMembers[_caseId].push(msg.sender);
        }
        else {
            secondPartyMembers[_caseId].push(msg.sender);
        }

        emit case_JoinedCase(_caseId, _party, msg.sender);
    }

    function getFirstPartyMembers(uint256 _caseId) external view returns(address[] memory) {
        return firstPartyMembers[_caseId];
    } 

    function getSecondPartyMembers(uint256 _caseId) external view returns(address[] memory) {
        return secondPartyMembers[_caseId];
    } 

    //we should have a message feedback on the front end for parties to rate and comment on mediator, providing their addresses.
    // we should be able to remove a mediator from the mediator contract

    /*
    * Only the mediator should be able to start a session by providing the case id.
    * If the session of that case has already been started then the mediator should not be able to start it again
    * If the case is closed, then the mediator can not start the session
    * IF the number of sessions is more that the number they have paid for, then the mediator won't be able to start a session
    */
    function startSession(uint256 _caseId) external onlyMediator(_caseId) {
        if(cases[_caseId].sessionStarted) {
            revert Mediation__SessionAlredyStarted();
        }
        if(cases[_caseId].caseClosed) {
            revert Mediation__CaseDoesNotExistOrCaseIsClosed();
        }
        if(cases[_caseId].numberOfSession > numberOfSessions) {
            revert Mediation__ExceededDefaultNumberOfSessions();
        }

        cases[_caseId].sessionStarted = true;
        cases[_caseId].numberOfSession += 1;
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
    * ON THE UI, WE WILL LET THE MEDIATORS KNOW THAT THEY ARE GETTING 90% OF THE PAY
    */

    /*
    * Only the Mediator can end a session, 
    * Payment must be accepted by the parties, after ending the sessions the mediator receive his/her payment
    */
    function endSession(uint256 _caseId) external onlyMediator(_caseId) receivePayment(_caseId) {
        if(!paymentAccepted[_caseId]){
            revert Mediation__CannotReceivePaymentPartiesNeedToApprove();
        }
        paymentAccepted[_caseId] = false;
        cases[_caseId].sessionStarted = false;
    }

    /*
    * Mediator can end a session without receiving payment, 
    */
    function endSessionWithoutPay(uint256 _caseId) external onlyMediator(_caseId) {
        cases[_caseId].sessionStarted = false;
    }

    /*
    * Once the number of default sessions has been reached but the parties still need more session,
    * They will book for a session and the first party creates the booking and pay for it according
    */
    function createBookedSession(uint256 _caseId) external payable payByCategory(cases[_caseId].category, 1){
        if(cases[_caseId].firstParty != msg.sender) {
            revert Mediation__YouAreNotPartOfThisSession();
        }
        ethBalances[_caseId] = 0;
        ethBalances[_caseId] += msg.value;

        bookedSessions[_caseId] = BookedSession(
            _caseId,
            cases[_caseId].firstParty,
            cases[_caseId].secondParty,
            cases[_caseId].mediator,
            firstPartyMembers[_caseId],
            secondPartyMembers[_caseId],
            true, //bookedSessionClosed : true because all the two parties must be available for mediator can start a session
            false,
            block.timestamp
        );

        paymentAccepted[_caseId] = false;
        acceptedByFirstParty[_caseId] = 0;
        acceptedBySecondparty[_caseId] = 0;

        emit BookedSessionCreated(_caseId);
    }

    /*
    * The second party joins the booked sessions and pay for it. 
    * When he joins, the booked session is now opened that the mediator can start it
    */
    function joinBookedSessionAsSecondParty(uint256 _caseId) external payable payByCategory(cases[_caseId].category, 1) {
        if(cases[_caseId].secondParty != msg.sender) {
            revert Mediation__YouAreNotPartOfThisSession();
        }

        ethBalances[_caseId] += msg.value;
        bookedSessions[_caseId].bookedSessionClosed = false;

        emit JoinedBookedSession(_caseId);
    }

    /*
    * Mediator can start a booked session
    */
    function startBookedSession(uint256 _caseId) external onlyMediator(_caseId) {
        if(bookedSessions[_caseId].bookedSessionClosed) {
            revert Mediation__BookedSessionIsStillclosed();
        }
        if(bookedSessions[_caseId].bookedSessionStarted) {
            revert Mediation__BookedSessionAlreadyStarted();
        }

        bookedSessions[_caseId].bookedSessionStarted = true;
    }

    /*
    * When a mediator ends a booked session, the funds for the booked sessions are send to him
    */
    function endBookedSession(uint256 _caseId) external onlyMediator(_caseId) {
        if(!paymentAccepted[_caseId]){
            revert Mediation__CannotReceivePaymentPartiesNeedToApprove();
        }
        paymentAccepted[_caseId] = false;
        bookedSessions[_caseId].bookedSessionStarted = false;
        bookedSessions[_caseId].bookedSessionClosed = true;

        uint256 mediatorPay = (ethBalances[_caseId] * 90)/100;
        (bool success, ) = bookedSessions[_caseId].mediator.call{value: mediatorPay}("");
        if(!success) {
            revert Mediation__FailedToSendPayment();
        }
    }

    /*
    * Only the mediator or Owner can close a session
    * Closing a session when the max number of sessions has not reached, the parties receives the excess fund they provided
    */
    function closeCase(uint256 _caseId) external onlyMediatorOrOwner(_caseId) {
        if(cases[_caseId].numberOfSession == 0){
            //mediator should be compensated, I THINK and Parties receive their money after compensation 
        }

        uint256 numbSessions = numberOfSessions - cases[_caseId].numberOfSession;
        if(numbSessions > 0) {
            uint256 _price = _getPriceByCategory(cases[_caseId].category);
            uint256 _pricePerParty = _price/2;

            (bool success1, ) = cases[_caseId].firstParty.call{value: _pricePerParty*numbSessions}("");
            (bool success2, ) = cases[_caseId].secondParty.call{value: _pricePerParty*numbSessions}("");
            if(!success1) {
                revert Mediation__FailedToRefundFundsToParty1();
            }
            if(!success2) {
                revert Mediation__FailedToRefundFundsToParty2();
            }
        }

        cases[_caseId].caseClosed = true;
        doesCaseExist[_caseId] = false;
    }

    /*
    * Only the owner can withdraw all the funds in the contract
    */
    function withdraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        if(!success) {
            revert Mediation__FailedToWithdrawFunds();
        }
    }

    /*
    * Owner can send fund to a paticular address
    */
    function withdrawToAddress(address payable _address, uint256 _amount) external onlyOwner {
        if(_amount > address(this).balance){
            revert Mediation__NotEnoughFundsInContract();
        }

        (bool success, ) = _address.call{value: _amount}("");
        if(!success) {
            revert Mediation__FailedToWithdrawFunds();
        }
    }

    /*
    * Returns the price with respect to the category 
    */
    function _getPriceByCategory(uint256 category) internal view returns(uint256 ) {
        if(category == uint256(Category.junior)) {
            return juniorMediatorPrice;
        }
        else if(category == uint256(Category.intermediate)){
           return intermediateMediatorPrice;
        }
        else if(category == uint256(Category.expert)) {
            return expertMediatorPrice;
        }
        else {
            return 0;
        }
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

    /*
    * A modifier to receive payment, 
    * Mediators use this to receive their payments when they end a session
    */
    modifier receivePayment(uint256 _caseId) {
        _;
        uint256 balance = ethBalances[_caseId] / numberOfSessions;
        uint256 ethToSendToMediator = (balance*90)/100; //90%
        (bool success, ) = cases[_caseId].mediator.call{value: ethToSendToMediator}("");
        if(!success) {
            revert Mediation__FailedToSendPayment();
        }
    }


    /*
    * Parties involved use this to pay for a case with respect to the category
    */
    modifier payByCategory(uint256 category, uint256 _numberOfSessions) {
        if(category == uint256(Category.junior)) {
            require(msg.value == (juniorMediatorPrice/2)*_numberOfSessions, "Not enough or too much eth to create a case");
        }
        else if(category == uint256(Category.intermediate)){
            require(msg.value == (intermediateMediatorPrice/2)*_numberOfSessions, "Not enough or too much eth to create a case");
        }
        else if(category == uint256(Category.expert)) {
            require(msg.value == (expertMediatorPrice/2)*_numberOfSessions, "Not enough or too much eth to create a case");
        }
        _;
    }

    modifier payFullFeeByCategory(uint256 category, uint256 _numberOfSessions) {
        if(category == uint256(Category.junior)) {
            require(msg.value == juniorMediatorPrice*_numberOfSessions, "Not enough or too much eth to create a case");
        }
        else if(category == uint256(Category.intermediate)){
            require(msg.value == intermediateMediatorPrice*_numberOfSessions, "Not enough or too much eth to create a case");
        }
        else if(category == uint256(Category.expert)) {
            require(msg.value == expertMediatorPrice*_numberOfSessions, "Not enough or too much eth to create a case");
        }
        _;
    }

    modifier onlyMediator(uint256 _caseId) {
        if(msg.sender != cases[_caseId].mediator) {
            revert Mediation__OnlyMediatorCanDoThis();
        }
        _;
    }

    modifier onlyMediatorOrOwner(uint256 _caseId) {
        require(msg.sender == cases[_caseId].mediator || msg.sender == owner(), "Only Mediator or Owner can do this");
        _;
    }

    receive() external payable {}
    fallback() external payable {}
}
