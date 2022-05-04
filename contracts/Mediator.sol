// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract Mediator {
    using SafeMath for uint256;

    uint256 public nextMediator;

    mapping(uint256 => _Mediator) public mediators;
    mapping(uint256 => bool) public isAvailable;
    event Mediator(uint256 id, address owner, string timeZone, string[] Languages, string[] certifications, uint256 timestamp);

    struct _Mediator {
        uint256 id,
        address owner,
        string timeZone,
        string[] Languages,
        string[] certifications,
        bool daoExperience,
        uint256 timestamp   
    }

    createMediator(address _owner, string _timeZone, string[] _language, string[] _certifications, bool _daoExperience) public { //onlyOwner implementation from another contract. 
        //require controller contract to be msg.sender.
        nextMediator = nextMediator.add(1);
        mediators[nextMediator] = _Mediator (
            nextMediator,
            _owner,
            _timeZone,
            _language,
            _certifications,
            _daoExperience,
            block.timestamp
        )

        //mint mediator NFT badge? send 
        emit Mediator(nextMediator, _owner, _timeZone, _language, _certifications, _daoExperience, block.timestamp);
    }
}