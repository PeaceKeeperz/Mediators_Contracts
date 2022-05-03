//SPDX-License-Identifier: MIT
pragma Solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

interfaces IMediator {
    function getMediators(uint256 _category) external returns(address[]) {}
}

contract Mediation is VRFConsumerBaseV2 {
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

    address public s_owner;
    struct Case {
        uint256 caseId;
        address[] firstParty;
        address[] secondParty;
        address mediator;
        string tokenURI;
        bool caseClosed;
        uint256 caseCreatedAt;

    }
    uint256 nextCaseId;

    uint256 juniorMediatorPrice = 0.1 ether;
    uint256 intermediateMediatorPrice = 0.2 ether;
    uint256 expertMediatorPrice = 0.3 ether;

    //This container keep tracks of the amount eth for each case
    mapping(uint256 => uint256) private ethBalances;
    mapping(uint256 => Case) public cases;
    mapping(uint256 => bool) public caseExist;

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


    error Mediation__PartyDoesNotExist();
    error Mediation__CaseDoesNotExist();
    error Mediation__OnlyMediatorCanDoThis();
    error Mediation__FailedToCancelCase();
    error Mediation__FailedToPostponedCase();


    constructor(uint64 subscriptionId, address _mediator) VRFConsumerBaseV2(vrfCoordinator) {
        i_COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
        i_Mediator = IMediator(_mediator);
    }

    //discuss, if two uses are calling this function at the same time, what will happened with the Id

    function createCase(uint256 category) external payable payByCategory(category){
        ethBalances[nextCaseId] += msg.value;
        cases[nextCaseId] = new Case(
            nextCaseId,
            firstParty.push(msg.sender),
            ,
            ,
            ,
            false,
            block.timestamp
        );

        _assignMediator(category, nextCaseId);

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

    function joinCaseAsSecondParty(uint256 _caseId) external payable payByCategory(category){
        ethBalances[_caseId] += msg.value;
        cases[_caseId].secondParty.push(msg.sender);

        emit case_SecondPartyJoint(_caseId);
    }

    function joinCase(uint256 _caseId, uint256 _party) external {
        if(_party != 1 || _party != 2) {
            revert Mediation__PartyDoesNotExist();
        }
        if(!caseExist[_caseId]){
            revert Mediation__CaseDoesNotExist();
        }

        if(_party == 1) {
            cases[_caseId].firstParty.push(msg.sender);
        }
        else {
            cases[_caseId].secondParty.push(msg.sender);
        }

        emit case_JoinedCase(_caseId, _party, msg.sender);
    }

    function cancelCase(_caseId) external onlyMediator {

    }

    function closeCase(_caseId) external onlyMediator {

    }

    function postponeCase(_caseId) external onlyMediator {
        
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

    modifier payByCategory(uint256 category) {
        if(category == Category.junior) {
            require(msg.value == juniorMediatorPrice, "Not enough or too much eth to create a case");
        }
        else if(category == Category.intermediate){
            require(msg.value == intermediateMediatorPrice, "Not enough or too much eth to create a case");
        }
        else if(category == Category.expert) {
            require(msg.value == expertMediatorPrice, "Not enough or too much eth to create a case");
        }
        _;
    }

    modifier onlyMediator {
        if(msg.sender != mediator) {
            revert Mediation__OnlyMediatorCanDoThis();
        }
    }

    receive() external payable {}
    fallback() external payable {}
}
