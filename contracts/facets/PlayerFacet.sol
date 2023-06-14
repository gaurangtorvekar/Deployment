// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/PlayerSlotLib.sol";
import {ERC721Facet} from "./ERC721Facet.sol";
import {ERC721FacetInternal} from "./ERC721FacetInternal.sol";
import "../utils/Strings.sol";
import "../utils/Base64.sol";
import "../ERC721Storage.sol";
// import {Message} from "../libraries/Message.sol";
// import {GasRouter} from "@hyperlane-xyz/core/contracts/GasRouter.sol";

/// @title Player Storage Library
/// @dev Library for managing storage of player data
library PlayerStorageLib {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("player.test.storage.a");

    using PlayerSlotLib for PlayerSlotLib.Player;
    using PlayerSlotLib for PlayerSlotLib.Slot;
    using PlayerSlotLib for PlayerSlotLib.TokenTypes;

    /// @dev Struct defining player storage
    struct PlayerStorage {
        uint256 totalSupply;
        uint256 playerCount;
        mapping(uint256 => address) owners;
        mapping(uint256 => PlayerSlotLib.Player) players;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        mapping(string => bool) usedNames;
        mapping(address => uint256[]) addressToPlayers;
        mapping(uint256 => PlayerSlotLib.Slot) slots;
    }

    /// @dev Function to retrieve diamond storage slot for player data. Returns a reference.
    function diamondStorage() internal pure returns (PlayerStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /// @notice Mints a new player
    /// @param _name The name of the player
    /// @param _uri The IPFS URI of the player metadata
    /// @param _isMale The gender of the player
    function _mint(string memory _name, string memory _uri, bool _isMale) internal {
        PlayerStorage storage s = diamondStorage();
        require(!s.usedNames[_name], "name is taken");
        require(bytes(_name).length <= 10);
        require(bytes(_name).length >= 3);
        s.playerCount++;
        s.players[s.playerCount] = PlayerSlotLib.Player(
            1, 0, 0, 1, 10, 1, 1, 1, 1, 1, 1, 1, 1, _name, _uri, _isMale, PlayerSlotLib.Slot(0, 0, 0, 0, 0, 0)
        );
        s.slots[s.playerCount] = PlayerSlotLib.Slot(0, 0, 0, 0, 0, 0);
        s.usedNames[_name] = true;
        s.owners[s.playerCount] = msg.sender;
        s.addressToPlayers[msg.sender].push(s.playerCount);
        s.balances[msg.sender]++;
    }

    function _playerCount() internal view returns (uint256) {
        PlayerStorage storage s = diamondStorage();
        return s.playerCount;
    }

    function _nameAvailable(string memory _name) internal view returns (bool) {
        PlayerStorage storage s = diamondStorage();
        return s.usedNames[_name];
    }

    /// @notice Changes the name of a player
    /// @param _id The id of the player
    /// @param _newName The new name of the player
    function _changeName(uint256 _id, string memory _newName) internal {
        PlayerStorage storage s = diamondStorage();
        require(s.owners[_id] == msg.sender);
        require(!s.usedNames[_newName], "name is taken");
        require(bytes(_newName).length > 3, "Cannot pass an empty hash");
        require(bytes(_newName).length < 10, "Cannot be longer than 10 chars");
        string memory existingName = s.players[_id].name;
        if (bytes(existingName).length > 0) {
            delete s.usedNames[existingName];
        }
        s.players[_id].name = _newName;
        s.usedNames[_newName] = true;
    }

    function _getPlayer(uint256 _id) internal view returns (PlayerSlotLib.Player memory player) {
        PlayerStorage storage s = diamondStorage();
        player = s.players[_id];
    }

    function _ownerOf(uint256 _id) internal view returns (address owner) {
        PlayerStorage storage s = diamondStorage();
        owner = s.owners[_id];
    }

    /// @notice Transfer the player to someone else
    /// @param _to Address of the account where the caller wants to transfer the player
    /// @param _id ID of the player to transfer
    function _transfer(address _to, uint256 _id) internal {
        PlayerStorage storage s = diamondStorage();
        require(s.owners[_id] == msg.sender);
        require(_to != address(0), "_to cannot be zero address");
        s.owners[_id] = _to;
        for (uint256 i = 0; i < s.balances[msg.sender]; i++) {
            if (s.addressToPlayers[msg.sender][i] == _id) {
                delete s.addressToPlayers[msg.sender][i];
                break;
            }
        }
        s.balances[msg.sender]--;
        s.balances[_to]++;
    }

    function _getPlayers(address _address) internal view returns (uint256[] memory) {
        PlayerStorage storage s = diamondStorage();
        return s.addressToPlayers[_address];
    }
}

/// @title Player Facet
/// @dev Contract managing interaction with player data
contract PlayerFacet is ERC721FacetInternal {
    // contract PlayerFacet {
    using Strings for uint256;

    event Mint(uint256 indexed id, address indexed owner, string name, string uri);
    event NameChange(address indexed owner, uint256 indexed id, string indexed newName);
    /**
     * @dev Emitted on `transferRemote` when a transfer message is dispatched.
     * @param destination The identifier of the destination chain.
     * @param recipient The address of the recipient on the destination chain.
     * @param amount The amount of tokens burnt on the origin chain.
     */
    event SentTransferRemote(uint32 indexed destination, bytes32 indexed recipient, uint256 amount);

    function playerCount() public view returns (uint256) {
        return PlayerStorageLib._playerCount();
    }

    // /**
    //  * @notice Transfers `_amountOrId` token to `_recipient` on `_destination` domain.
    //  * @dev Delegates transfer logic to `_transferFromSender` implementation.
    //  * @dev Emits `SentTransferRemote` event on the origin chain.
    //  * @param _destination The identifier of the destination chain.
    //  * @param _recipient The address of the recipient on the destination chain.
    //  * @param _amountOrId The amount or identifier of tokens to be sent to the remote recipient.
    //  * @return messageId The identifier of the dispatched message.
    //  */
    // function transferRemote(uint32 _destination, bytes32 _recipient, uint256 _amountOrId)
    //     public
    //     payable
    //     virtual
    //     returns (bytes32 messageId)
    // {
    //     // _transferFrom(msg.sender, address(this), _tokenId);
    //     messageId = _dispatchWithGas(
    //         _destination,
    //         Message.format(_recipient, _amountOrId, ""),
    //         msg.value, // interchain gas payment
    //         msg.sender // refund address
    //     );
    //     emit SentTransferRemote(_destination, _recipient, _amountOrId);
    // }

    /// @notice Mints a new player
    /// @dev Emits a Mint event
    /// @dev Calls the _mint function from the PlayerStorageLib
    /// @param _name The name of the player
    /// @param _uri The IPFS URI of the player metadata
    /// @param _isMale The gender of the player
    function mint(string memory _name, string memory _uri, bool _isMale) external {
        PlayerStorageLib._mint(_name, _uri, _isMale);
        uint256 count = playerCount();
        emit Mint(count, msg.sender, _name, _uri);

        _safeMint(msg.sender, count);
    }

    /// @notice Changes the name of a player
    /// @dev Emits a NameChange event
    /// @param _id The id of the player
    /// @param _newName The new name of the player
    function changeName(uint256 _id, string memory _newName) external {
        PlayerStorageLib._changeName(_id, _newName);
        emit NameChange(msg.sender, _id, _newName);
    }

    /// @notice Retrieves a player
    /// @param _playerId The id of the player
    /// @return player The player data
    function getPlayer(uint256 _playerId) external view returns (PlayerSlotLib.Player memory player) {
        player = PlayerStorageLib._getPlayer(_playerId);
    }

    function nameAvailable(string memory _name) external view returns (bool available) {
        available = PlayerStorageLib._nameAvailable(_name);
    }

    function ownerOfPlayer(uint256 _playerId) external view returns (address owner) {
        owner = PlayerStorageLib._ownerOf(_playerId);
    }

    /// @notice Retrieves the players owned by an address
    /// @param _address The owner address
    /// @return An array of player ids
    function getPlayers(address _address) external view returns (uint256[] memory) {
        return PlayerStorageLib._getPlayers(_address);
    }

    /// @notice Retrieves the current block timestamp
    /// @return The current block timestamp
    function getBlocktime() external view returns (uint256) {
        return (block.timestamp);
    }

    function constructAttributes(PlayerSlotLib.Player memory player) internal pure returns (string memory attributes) {
        attributes = string(
            abi.encodePacked(
                '[{"trait_type":"Name","value":',
                player.name,
                '},{"trait_type":"Level","value":',
                player.level.toString(),
                '},{"trait_type":"XP","value":',
                player.xp.toString(),
                '},{"trait_type":"Status","value":',
                player.status.toString(),
                '},{"trait_type":"Gender","value":',
                player.male ? "Male" : "Female",
                '},{"trait_type":"Strength","value":',
                player.strength.toString(),
                '},{"trait_type":"Health","value":',
                player.health.toString(),
                "}]"
            )
        );
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    // Bypass for a `--via-ir` bug (https://github.com/chiru-labs/ERC721A/pull/364).
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        // function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireMinted(tokenId);

        PlayerSlotLib.Player memory player = PlayerStorageLib._getPlayer(tokenId);
        string memory attributes = constructAttributes(player);

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"',
                        player.name,
                        '","description":"Player NFT from OmniKingdoms","image":"',
                        player.male ? ERC721Storage.layout()._maleImage : ERC721Storage.layout()._femaleImage,
                        '","attributes":',
                        attributes,
                        "}"
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    //function supportsInterface(bytes4 _interfaceID) external view returns (bool) {}

    /// @notice Mints corresponding ERC1155 tokens for a player
    /// @dev this function is for backwards compatibility so that the playerIDs match the number of ERC721 tokens held by this account
    // function historicalERC721Mint() public {
    //     uint256[] memory playerIDs = PlayerStorageLib._getPlayers(msg.sender);

    //     for (uint256 i = 0; i < playerIDs.length; i++) {
    //         if (!_exists(playerIDs[i])) {
    //             _safeMint(msg.sender, playerIDs[i]);
    //         }
    //     }
    // }
}
