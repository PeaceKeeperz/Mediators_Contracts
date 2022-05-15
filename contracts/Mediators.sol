// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol"; //testing purposes

/**
 * @title Mediator
 *
 * @notice contract creates and stores mediator information.
 */

contract Mediators {
    using SafeMath for uint256;

    /* ============ State Variables ============ */

    uint256 public nextMediatorId;
    address public owner;
    address public mediationContract;
    address public cMediationContract;

    mapping(uint256 => _Mediator) public mediators;
    mapping(uint256 => address[]) private mediatorsByCategory;
    mapping(uint256 => bool) public isAvailable; // is the mediator available?
    mapping(uint256 => bool) public isActive;
    event Mediator(
        uint256 id,
        address owner,
        uint256 openCaseCount,
        string timeZone,
        string language,
        string certification,
        bool daoExperience,
        uint256 timestamp,
        uint256 category
    );


    /* ============ Struct ============ */

    struct _Mediator {
        uint256 id;
        address owner;
        uint256 openCaseCount;
        string timeZone;
        string Languages;
        string certifications;
        bool daoExperience;
        uint256 timestamp;
        uint256 category;
    }

    /* ============ Constructor ============ */

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Creates a new Mediator
     *
     * @param _owner   Wallet address of the mediator
     * @param _timeZone  timezone where they live?
     * @param _languages langugages they speak?
     * @param _certifications any certifications?
     * @param _daoExperience any dao eperience?
     * @param _category The category of the mediator
     */
    function createMediator(
        address _owner,
        string memory _timeZone,
        string memory _languages,
        string memory _certifications,
        bool _daoExperience,
        uint256 _category
    ) public onlyOwner {
        //onlyOwner implementation from another contract.
        //require controller contract to be msg.sender.
        nextMediatorId = nextMediatorId.add(1);
        mediators[nextMediatorId] = _Mediator(
            nextMediatorId,
            _owner,
            0,
            _timeZone,
            _languages,
            _certifications,
            _daoExperience,
            block.timestamp,
            _category
        );
        isAvailable[nextMediatorId] = true;
        isActive[nextMediatorId] = true;
        _updateMediatorByCategory(_category, mediators[nextMediatorId]);
        //mint mediator NFT badge? send
        emit Mediator(
            nextMediatorId,
            _owner,
            0,
            _timeZone,
            _languages,
            _certifications,
            _daoExperience,
            block.timestamp,
            _category
        );
    }

    function addCaseCount(uint256 _id) external returns (bool) {
        _Mediator storage mediator = mediators[_id];
        mediator.openCaseCount = mediator.openCaseCount.add(1);
        return true;
    }

    function minusCaseCount(uint256 _id) external returns (bool) {
        _Mediator storage mediator = mediators[_id];
        require(mediator.openCaseCount > 0, "Mediator has no open cases");
        mediator.openCaseCount = mediator.openCaseCount.sub(1);
        return true;
    }

    function _updateMediatorByCategory(
        uint256 _category,
        _Mediator memory mediator
    ) private onlyOwner {
        mediatorsByCategory[_category].push(mediator.owner);
    }

    function getAllMediatorsByCategory(uint256 _category)
        external
        view
        returns (address[] memory)
    {
        return mediatorsByCategory[_category];
    }

    function setMediationContract(address _mediationContract) public onlyOwner {
        mediationContract = _mediationContract;
    }

    function setcMediationContract(address _cMediationContract) public onlyOwner {
        cMediationContract = _cMediationContract;
    }

    /**
     *
     * @dev Modifier function onlyOwner can call this
     *
     **/
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "You do not have permission to call this contract"
        );
        _;
    }

    // used so only the mediation contract calls this. 
    modifier onlyMediation() {
        require(msg.sender == mediationContract || msg.sender == cMediationContract, "Permission Denied, nonMediationContact");
        _;
    }
}
