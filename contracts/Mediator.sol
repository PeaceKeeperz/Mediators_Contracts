// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol"; //testing purposes

/**./
 * @title Mediator
 *
 * @notice contract creates and stores mediator information. 
 */

contract Mediator {
    using SafeMath for uint256;

/* ============ State Variables ============ */

    uint256 public nextMediator;
    address public controller;

    mapping(uint256 => _Mediator) public mediators;
    mapping(uint256 => bool) public isAvailable; // is the mediator available?
    event Mediator(uint256 id, address owner, string timeZone, string[] Languages, string[] certifications, bool daoExperience, uint256 timestamp);

  /* ============ Struct ============ */

    struct _Mediator {
        uint256 id;
        address owner;
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
    constructor(address _controller){
        controller = _controller;
    }


    /**
     * @notice Creates a new Mediator
     *
     * @param _owner   Wallet address of the mediator 
     * @param _timeZone  timezone where they live?
     * @param _languages langugages they speak?
     * @param _certifications any certifications?
     * @param _daoExperiece any dao eperience?  
     */
    function createMediator(address _owner, string memory _timeZone, string[] memory _languages, 
    string[] memory _certifications, bool _daoExperience) public onlyOwner{ //onlyOwner implementation from another contract. 
        //require controller contract to be msg.sender.
        nextMediator = nextMediator.add(1);
        mediators[nextMediator] = _Mediator (
            nextMediator,
            _owner,
            _timeZone,
            _languages,
            _certifications,
            _daoExperience,
            block.timestamp
        );

        isAvailable[nextMediator] = true;
        //mint mediator NFT badge? send 
        emit Mediator(nextMediator, _owner, _timeZone, _languages, _certifications, _daoExperience, block.timestamp);
    }

    /**
    *
    * @dev Modifier function onlyOwner can call this
    *
    **/
    modifier onlyOwner() {
        require(msg.sender == controller, "You do not have permission to call this contract");
        _;
    }
}