pragma solidity ^0.6.6;

import "@nomiclabs/buidler/console.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

//@title Pinned File System
//@notice Use it to pin a file hash to Earth coordinates so that people can advertise locally for different purposes corresponding to different applications.
//@dev pinf refers to pinned file which is a key value pair. Timestamped geographical coordinates are keys and files' hashes are values.
//Record ownership is stored to distinguish different decentralized applications records, ownership of the record is the source of knowledge.

contract Pinfs {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*Coordinates are stored as bytes32 
    example:
    bytes12 latitude;
    bytes12 longitude; 
    bytes24 coordinates = abi.encodePacked(latitude, longitude);
    bytes32 pin = abi.encodePacked(coordinates, block.timestamp);
    where the first 12 bytes are the lattitude 
*/
    struct Pin {
      bytes8 latitude;
      bytes8 longitude;
      bytes8 altitude;
      bytes8 timestamp;
    }

    mapping(bytes32 => bytes32) public pinfAt; //Geographical Position Registry pinId => file hash
    mapping(bytes32 => address) public ownerOf; //used to retrieve the owner or third party dapp/smartcontract having registered the record

    EnumerableSet.AddressSet allPins; 

//@dev easy retrieval of surrounding pins belonging to searched dapp through subgraph
    event Pinned(
        bytes32 _pinId,
        bytes32 filehash,
        bytes8 indexed latitude,
        bytes8 indexed longitude,
        address indexed pinner
    );

    event Unpinned(
        bytes32 _pinId,
        address unpinner
    );

    event ChangedPinOwner(
        bytes32 pinnedFileId,
        address previousOwner,
        address newOwner
    );

    event ChangedPinFile(
        bytes32 pinnedFileId,
        bytes32 previousFile,
        bytes32 newFile
    );

    //@notice lock the pin record so that it cannot be unpinned 
    event LockedPin(bytes32 oldPinId, bytes32 newPinId);

    //@dev if the record has expired check the sender is the owner
    modifier onlyOwner(bytes32 _pinId, address sender) {
        if (block.timestamp < parseId(_pinId).timestamp) + uint256(31536000)) {
            require(
                ownerOf[_pinId] == msg.sender,
                abi.encodePacked("PINFS: REQUIRED_PIN_OWNER_ADDRESS")
            );
        }
        _;
    }

    modifier checkLock(bytes32 _pinId) {
            require(parseId(_pinId).timestamp==0xffffffffffffffff);
    }

    //@notice altitude optional parameter of the Pinf function is implemented through function overloading
    function pinf(
        bytes32 _fileHash,
        bytes8 _latitude,
        bytes8 _longitude
    ) external returns (bytes32) {
        return pinf(_fileHash, _latitude, _longitude, 0);
    }

    //@notice add a pinned file and set its owner (to be anonymous just use a burner wallet)
    function pinf(
        bytes32 _fileHash,
        bytes8 _latitude,
        bytes8 _longitude,
        bytes8 _altitude
    ) public returns (bytes32 pinId) {
        bytes32 _pinId = _makePinfId(_latitude, _longitude, _altitude);
        _pin(_pinId, _fileHash);
        emit Pinned(
            _fileHash,
            _latitude,
            _longitude,
            _altitude,
            _pinId[23:],
            msg.sender
        );
        pinId = _pinId;
    }

    function unpinf(bytes32 _pinId)
        public
        onlyOwner(_pinId, msg.sender)
        checkLock(_pinId)
        returns (bool)
    {
        _unpin(_pinId);
        (
            bytes8 _latitude,
            bytes8 _longitude,
            bytes8 _altitude,
            bytes8 _timestamp
        ) = parseId(_pinId);
        emit Unpinned(_latitude, _longitude, _altitude, _timestamp, msg.sender);
        return true;
    }

    function _pin(bytes32 _pinId, bytes32 _fileHash) internal returns (bool) {
        _setPinnedFileAt(_pinId, _fileHash);
        _setOwnerOf(_pinId, msg.sender);
        allPins.add(_pinId);
        bytes8 _timestamp = parseId(_pinId).timestamp;
    }

    function _unpin(bytes32 _pinId) internal returns (bool) {
        _setPinnedFileAt(_pinId, bytes32(0));
        _setOwnerOf(_pinId, address(0));
        allPins.remove(_pinId);
    }

    function lockPinf(bytes32 _pinId)
        external
        returns (bool)
    {
        require(allPins.get(_pinId)!=0x00, "Pinfs: PINF_NOT_FOUND");
        (
            bytes8 _latitude,
            bytes8 _longitude,
            bytes8 _altitude,
            bytes8 _timestamp
        ) = parseId(_pinId);
        bytes32 _newPin = _makePinfId(_latitude, _longitude, _altitude);
        _setPinnedFileAt(_newPin, getPinf(_pinId));
        _setOwnerOf(_newPin, getOwnerOf(msg.sender));
        allPins.add();
        _unpin(_pinId);
        emit LockedPin(_pinId, _newPin);
        return _newPin;
    }

    function setPinOwner(bytes32 _pinId, address _newOwner)
        external
        onlyOwner(_pinId, msg.sender)
        returns (bytes32 pinfId)
    {
        emit ChangedPinOwner(_pinId, msg.sender, _newOwner);
        return _setOwnerOf(_pinId, _newOwner);
    }

    function setPinnedFileAt(bytes32 _pinId, bytes32 _fileHash)
        external
        onlyOwner(_pinId, msg.sender)
        returns (bool)
    {
        emit ChangedPinFile(_pinId, getPinf(_pinId), _fileHash);
        return _setPinnedFileAt(_pinId, _fileHash);
    }

    //@dev the pinned file id contains timestamped geographical coordinates: latitude, longitude, altitude and timestamp.
    function _makePinfId(
        bytes8 _latitude,
        bytes8 _longitude,
        bytes8 _altitude
    ) internal pure returns (bytes32) {
        uint256 _pinId = uint256(
            abi.encodePacked(
                _latitude,
                _longitude,
                _altitude,
                bytes8(block.timestamp)
            )
        );
        while (pinfAt[bytes32(_pinId)] != "") {
            _pinId += 1;
        }
        return bytes32(_pinId);
    }

    //@dev the pinned file registry contains location keys and file hash values
    function _setPinnedFileAt(bytes32 _pinId, bytes32 _fileHash)
        internal
        returns (bool)
    {
        pinfAt[_pinId] = _fileHash;
    }

    //@dev the ownership registry contains location keys and owners' addresses values
    function _setOwnerOf(bytes32 _pinId, address _pinOwner)
        internal
        returns (bool)
    {
        ownerOf[_pinId] = _pinOwner;
    }

    function getPinCount() public view returns (uint256) {
        return allPins.length;
    }

    function getPinf(bytes32 _pinId) public view returns (bytes32) {
        return pinfAt[_pinId];
    }

    function getOwnerOf(bytes32 _pinId) public view returns (bytes32) {
        return ownerOf[_pinId];
    }

    function parseId(bytes32 _pinId)
        public
        pure
        returns (
            bytes8 latitude,
            bytes8 longitude,
            bytes8 altitude,
            bytes8 timestamp
        )
    {
        (latitude, longitude, altitude, timestamp) = (
            abi.encodePacked(_pinId[0],_pinId[1],_pinId[2],_pinId[3],_pinId[4],_pinId[5],_pinId[6],_pinId[7]),
            abi.encodePacked(_pinId[0],_pinId[1],_pinId[2],_pinId[3],_pinId[4],_pinId[5],_pinId[6],_pinId[7]),
            abi.encodePacked(_pinId[0],_pinId[1],_pinId[2],_pinId[3],_pinId[4],_pinId[5],_pinId[6],_pinId[7]),
            abi.encodePacked(_pinId[24],_pinId[25],_pinId[26],_pinId[27],_pinId[28],_pinId[29],_pinId[30],_pinId[31])
             );
    }
}

// contract YourContract {

//   string public purpose = "🛠 Programming Unstoppable Money";

//   function setPurpose(string memory newPurpose) public {
//     purpose = newPurpose;
//     console.log(msg.sender,"set purpose to",purpose);
//   }

// }
