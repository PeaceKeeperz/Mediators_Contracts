//SPDX-License-Identifier: MIT
pragma Solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMediator {
    function getMediators(uint256 _category) external returns(address[]) {}
}

contract Mediation is VRFConsumerBaseV2, Ownable {
    IMediator immutable i_Mediator;
    VRFCoordinatorV2Interface immutable i_COORDINATOR;
    LinkTokenInterface immutable i_LINKTOKEN;
    //Rinkeby coordinator, These test values are coming from https://docs.chain.link/docs/vrf-contracts/#configurations
    address constant c_vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    //subscription id, gotten from when you subscribe for LINK
    uint64 immutable i_subscriptionId;
    bytes32 constant c_keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint32 constant c_callbackGasLimit = 100000;
    uint16 constant c_requestConfirmations = 3;
    uint32 constant c_numWords =  1;
    uint256[] public s_randomNumbers;
    uint256 public requestId;

    struct Case {
        uint256 caseId;
        address payable[] firstParty;
        address payable[] secondParty;
        address payable mediator;
        string tokenURI;
        bool caseClosed;
        uint256 caseCreatedAt;
        uint256 numberOfSession;
        bool sessionStarted;
        uint256 category;
    }
    uint256 nextCaseId;
    uint256 constant numberOfSessions = 3;

    struct BookedSession {
        uint256 caseId;
        address[] firstParty;
        address[] secondParty;
        address payable mediator;
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

    //This container keep tracks of the amount eth for each case
    mapping(uint256 => uint256) private ethBalances;
    mapping(uint256 => Case) public cases;
    mapping(uint256 => BookedSession) public bookedSessions;
    mapping(uint256 => bool) public sessionStarted;
    mapping(uint256 => bool) public paymentAccepted;

    mapping(uint256 => uint256) private acceptedByFirstParty;
    mapping(uint256 => uint256) private acceptedBySecondparty;

    enum Category {
        junior,
        intermediate,
        expert
    }

    event case_Created(uint256 _caseId, uint256 _caseCreatedAt);
    event case_SecondPartyJoint(uint256 _caseId);
    event case_Canceled(uint256 _caseId);
    event case_Completed(uint256 _caseId, address[] _winner);
    event case_Postponed(uint256);
    event case_JoinedCase(uint256 _caseId, uint256 _party, address _address);
    event BookedSessionCreated(uint256 _caseId);
    event JoinedBookedSession(uint256 _caseId);

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


    constructor(uint64 subscriptionId, address _mediator) VRFConsumerBaseV2(vrfCoordinator) {
        i_COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
        i_Mediator = IMediator(_mediator);
    }

    //discuss, if two uses are calling this function at the same time, what will happened with the Id

    function createCase(uint256 _category) external payable payByCategory(_category, numberOfSessions){
        ethBalances[nextCaseId] += msg.value;
        cases[nextCaseId] = Case(
            nextCaseId,
            firstParty.push(msg.sender),
            ,
            ,
            ,
            true,
            block.timestamp,
            0,
            false,
            _category
        );

        _requestRandomWords();

        _assignMediator(_category, nextCaseId);

        emit case_Created(nextCaseId, cases[nextCaseId].caseCreatedAt);
        caseExist[nextCaseId] = true;
        nextCaseId++;
    }

    function _assignMediator(uint _category, uint256 _caseId) internal {
        let mediators = i_Mediator.getMediators(_category);
        let selectedMediatorIndex = s_randomNumbers[0] % mediators.length;
        let selectedMediator = mediators[selectedMediator];

        cases[_caseId].mediator = selectedMediator;
        s_randomNumbers = [];
    }

    function joinCaseAsSecondParty(uint256 _caseId) external payable payByCategory(cases[_caseId].category, numberOfSessions){
        ethBalances[_caseId] += msg.value;
        cases[_caseId].secondParty.push(msg.sender);
        cases[_caseId].caseClosed = false;

        emit case_SecondPartyJoint(_caseId);
    }

    function joinCase(uint256 _caseId, uint256 _party) external {
        if(_party != 1 || _party != 2) {
            revert Mediation__PartyDoesNotExist();
        }
        if(cases[_caseId].caseClosed){
            revert Mediation__CaseDoesNotExistOrCaseIsClosed();
        }

        if(_party == 1) {
            cases[_caseId].firstParty.push(msg.sender);
        }
        else {
            cases[_caseId].secondParty.push(msg.sender);
        }

        emit case_JoinedCase(_caseId, _party, msg.sender);
    }

    //we should have a message feedback on the front end for parties to rate and comment on mediator, providing their addresses.
    // we should be able to remove a mediator from the mediator contract

    function startSession(_caseId) external onlyMediator(_caseId) {
        if(cases[_caseId].sessionStarted) {
            revert Mediation__SessionAlredyStarted();
        }
        if(cases[_caseId].caseClosed) {
            revert Mediation__CaseDoesNotExistOrCaseIsClosed();
        }
        if(cases[_caseId].numberOfSession > numberOfSessions) {
            revert Mediation__ExceededDefaultNumberOfSessions()
        }
        cases[_caseId].sessionStarted = true;
        cases[_caseId].numberOfSession += 1;
    }

    function acceptPayment(uint256 _caseId) external {
        if(cases[_caseId].firstParty[msg.sender] >= 0) {
            acceptedByFirstParty[_caseId] = 1;
        }

        if(cases[_caseId].secondParty[msg.sender] >= 0){
            acceptedBySecondparty[_caseId] = 1;
        }

        if((acceptedByFirstParty + acceptedBySecondparty) == 2){
            paymentAccepted[_caseId] = true;
        }else{
            paymentAccepted[_caseId] = false;
        }
    }

    /*
    * ON THE UI, WE WILL LET THE MEDIATORS KNOW THAT THEY ARE GETTING 90% OF THE PAY
    */

    function endSession(_caseId) external onlyMediator(_caseId) receivePayment(_caseId) {
        if(!paymentAccepted[_caseId]){
            revert Mediation__CannotReceivePaymentPartiesNeedToApprove();
        }
        paymentAccepted[_caseId] = false;
        cases[_caseId].sessionStarted = false;
    }

    function endSessionWithoutPay(_caseId) external onlyMediator(_caseId) {
        cases[_caseId].sessionStarted = false;
    }

    function createBookedSession(uint256 _caseId) external payable payByCategory(cases[_caseId].category, 1){
        if(cases[_caseId].firstParty[msg.sender] < 0) {
            revert Mediation__YouAreNotPartOfThisSession();
        }
        ethBalances[_caseId] = 0;
        ethBalances[_caseId] += msg.value;

        bookedSessions[_caseId] = BookedSession(
            _caseId,
            cases[_caseId].firstParty,
            cases[_caseId].secondParty,
            cases[_caseId].mediator,
            true, //bookedSessionClosed : true because all the two parties must be available for mediator can start a session
            false,
            block.timestamp,
        );

        acceptPayment[_caseId] = false;
        acceptedByFirstParty[_caseId] = 0;
        acceptedBySecondparty[_caseId] = 0;

        emit BookedSessionCreated(_caseId);
    }

    function joinBookedSessionAsSecondParty(uint256 _caseId) external payable payByCategory(cases[_caseId].category, 1) {
        if(cases[_caseId].secondParty[msg.sender] < 0) {
            revert Mediation__YouAreNotPartOfThisSession();
        }

        ethBalances[_caseId] += msg.value;
        bookedSessions[_caseId].bookedSessionClosed = false;

        emit JoinedBookedSession(_caseId);
    }

    function startBookedSession(uint256 _caseId) external onlyMediator {
        if(bookedSessions[_caseId].bookedSessionClosed) {
            revert Mediation__BookedSessionIsStillclosed();
        }
        if(bookedSessions[_caseId].bookedSessionStarted) {
            revert Mediation__BookedSessionAlreadyStarted();
        }

        bookedSessions[_caseId].bookedSessionStarted = true;
    }

    function endBookedSession(uint256 _caseId) external onlyMediator {
        if(!paymentAccepted[_caseId]){
            revert Mediation__CannotReceivePaymentPartiesNeedToApprove();
        }
        paymentAccepted[_caseId] = false;
        bookedSessions[_caseId].bookedSessionStarted = false;
        bookedSessions[_caseId].bookedSessionClosed = true;

        let mediatorPay = (ethBalances[_caseId] * 90)/100;
        (bool success, ) = bookedSessions[_caseId].mediator.call{value: mediatorPay}("");
        if(!success) {
            revert Mediation__FailedToSendPayment()
        }
    }

    function closeCase(_caseId) external onlyMediatorOrOwner(_caseId) {
        if(cases[_caseId].numberOfSession == 0){
            //mediator should be compensated, I THINK and Parties receive their money after compensation 
        }

        let numbSessions = numberOfSession - cases[_caseId].numberOfSession;
        if(numbSessions > 0) {
            let _price = _getPriceByCategory(cases[_caseId].category);
            let _pricePerParty = _price/2;

            (bool success1, ) = cases[_caseId].firstParty[0].call{value: _pricePerParty*numbSessions}("");
            (bool success2, ) = cases[_caseId].secondParty[0].call{value: _pricePerParty*numbSessions}("");
        }

        cases[_caseId].caseClosed = true;
    }

    function postponeCase(_caseId) external onlyMediator(_caseId) {

    }

    function cancelCase(_caseId) external onlyMediator(_caseId) {

    }

    function withdraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        if(!success) {
            revert Mediation__FailedToWithdrawFunds();
        }
    }

    function withdrawToAddress(address payable _address, uint256 _amount) external onlyOwner {
        if(_amount > address(this).balance){
            revert Mediation__NotEnoughFundsInContract();
        }

        (bool success, ) = _address.call{value: _amount}("");
        if(!success) {
            revert Mediation__FailedToWithdrawFunds();
        }
    }

    function _getPriceByCategory(uint256 category) internal view returns(uint256) {
        if(category == Category.junior) {
            return juniorMediatorPrice;
        }
        else if(category == Category.intermediate){
           return intermediateMediatorPrice;
        }
        else if(category == Category.expert) {
            return expertMediatorPrice;
        }
    }

    //Get random word.
    function _requestRandomWords() internal {
        // Will revert if subscription is not set and funded.
        requestId = i_COORDINATOR.requestRandomWords(
        c_keyHash,
        s_subscriptionId,
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

    modifier receivePayment(uint256 _caseId) {
        _;
        let balance = ethBalances[_caseId] / numberOfSessions;
        let ethToSendToMediator = (balance*90)/100; //90%
        (bool success, ) = cases[_caseId].mediator.call{value: ethToSendToMediator}("");
        if(!success) {
            revert Mediation__FailedToSendPayment()
        }
    }

    modifier payByCategory(uint256 category, uint256 _numberOfSessions) {
        if(category == Category.junior) {
            require(msg.value == (juniorMediatorPrice/2)*_numberOfSessions, "Not enough or too much eth to create a case");
        }
        else if(category == Category.intermediate){
            require(msg.value == (intermediateMediatorPrice/2)*_numberOfSessions, "Not enough or too much eth to create a case");
        }
        else if(category == Category.expert) {
            require(msg.value == (expertMediatorPrice/2)*_numberOfSessions, "Not enough or too much eth to create a case");
        }
        _;
    }

    modifier onlyMediator(uint256 _caseId) {
        if(msg.sender != cases[_caseId].mediator) {
            revert Mediation__OnlyMediatorCanDoThis();
        }
    }

    modifier onlyMediatorOrOwner(uint256 _caseId) {
        require(msg.sender == cases[_caseId].mediator || msg.sender == Owner(), "Only Mediator or Owner can do this");
        _;
    }

    receive() external payable {}
    fallback() external payable {}
}
