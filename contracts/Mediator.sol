// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol"; //testing purposes

/**
 * @title Mediator
 *
 * @notice contract creates and stores mediator information.
 */

contract Keepers {
    using SafeMath for uint256;

    /* ============ State Variables ============ */

    uint256 public nextMediatorId;
    address public controller;
    address public mediationContract;

    mapping(uint256 => _Mediator) public mediators;
    mapping(uint256 => bool) public isAvailable; // is the mediator available?
    mapping(uint256 => bool) public isActive;
    event Mediator(
        uint256 id,
        uint256 openCaseCount,
        address owner,
        string timeZone,
        string[] Languages,
        string[] certifications,
        bool daoExperience,
        uint256 timestamp
    );

    /* ============ Struct ============ */

    struct _Mediator {
        uint256 id;
        address owner;
        uint256 openCaseCount;
        string timeZone;
        string[] Languages;
        string[] certifications;
        bool daoExperience;
        uint256 timestamp;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Set controller state variable
     * @param _controller   Address of pontental controller of this contract. For onlyOwner
     */
    constructor(address _controller, address _mediationContract) {
        controller = _controller;
        mediationContract = _mediationContract;
    }

    /**
     * @notice Creates a new Mediator
     *
     * @param _owner   Wallet address of the mediator
     * @param _timeZone  timezone where they live?
     * @param _languages langugages they speak?
     * @param _certifications any certifications?
     * @param _daoExperience any dao eperience?
     */
    function createMediator(
        address _owner,
        string memory _timeZone,
        string[] memory _languages,
        string[] memory _certifications,
        bool _daoExperience
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
            block.timestamp
        );
        isAvailable[nextMediatorId] = true;
        isActive[nextMediatorId] = true;
        //mint mediator NFT badge? send
        emit Mediator(
            nextMediatorId,
            0,
            _owner,
            _timeZone,
            _languages,
            _certifications,
            _daoExperience,
            block.timestamp
        );
    }

    function addCaseCount(uint _id) external onlyMediationContract {
        _Mediator storage mediator = mediators[_id];
        mediator.openCaseCount =  mediator.openCaseCount.add(1);
    }

    function minusCaseCount(uint _id) external onlyMediationContract {
        _Mediator storage mediator = mediators[_id];
        require(mediator.openCaseCount > 0, "Mediator has no open cases");
       mediator.openCaseCount =  mediator.openCaseCount.sub(1);
    }

    /**
     *
     * @dev Modifier function onlyOwner can call this
     *
     **/
    modifier onlyOwner() {
        require(
            msg.sender == controller,
            "You do not have permission to call this contract"
        );
        _;
    }

    modifier onlyMediationContract() {
        require(msg.sender == mediationContract,
        "Only Mediation Contract can call this.");
        _;
    }
}
