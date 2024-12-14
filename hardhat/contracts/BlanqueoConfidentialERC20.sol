// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import { ConfidentialERC20 } from "fhevm-contracts/contracts/token/ERC20/ConfidentialERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BlanqueoConfidentialERC20 is ConfidentialERC20 {
    using ECDSA for bytes32;

    mapping(address => bool) public registered;
    uint256 public immutable MINT_DEADLINE;
    address public immutable SIGNER; // Backend signer address

    struct Authorization {
        string id;
        uint256 deadline;
        bytes signature;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    event Mint(address indexed to, string id);

    constructor(address _signer) ConfidentialERC20("BlanqueoToken", "BLQ") {
        require(_signer != address(0), "Signer a2ddress cannot be zero");
        SIGNER = _signer;

        // Set deadline to March 31, 2025, at 23:59:59 UTC
        MINT_DEADLINE = 1746076799; // Unix timestamp for March 31, 2025
    }

    function mintConfidential(
        einput encryptedAmount,
        bytes calldata inputProof,
        Authorization calldata authorization
    ) public {
        require(block.timestamp <= MINT_DEADLINE, "Minting period has expired");
        require(!registered[msg.sender], "Citizen already registered");
        require(authorization.deadline >= block.timestamp, "Deposit signature expired");

        // Validate the backend signature
        bytes32 message = keccak256(
            abi.encode(msg.sender, encryptedAmount, inputProof, authorization.id, authorization.deadline)
        );

        require(message.recover(authorization.signature) == SIGNER, "Invalid Signature");

        // Decode the encrypted amount
        euint64 encryptedMintAmount = TFHE.asEuint64(encryptedAmount, inputProof);

        // Update balance and allow
        _balances[msg.sender] = TFHE.add(_balances[msg.sender], encryptedMintAmount);
        TFHE.allowThis(_balances[msg.sender]);
        TFHE.allow(_balances[msg.sender], msg.sender);

        registered[msg.sender] = true;

        emit Mint(msg.sender, authorization.id); // Emit event
    }

    function burnConfidential(einput encryptedAmount, bytes calldata inputProof) public {
        transfer(address(0), TFHE.asEuint64(encryptedAmount, inputProof));
    }

    function _transferNoEvent(
        address from,
        address to,
        euint64 amount,
        ebool isTransferable
    ) internal virtual override {
        if (from == address(0)) {
            revert ERC20InvalidSender(from);
        }

        /// @dev Add to the balance of `to` and subtract from the balance of `from`.
        euint64 transferValue = TFHE.select(isTransferable, amount, TFHE.asEuint64(0));
        euint64 newBalanceTo = TFHE.add(_balances[to], transferValue);
        _balances[to] = newBalanceTo;
        TFHE.allowThis(newBalanceTo);
        TFHE.allow(newBalanceTo, to);
        euint64 newBalanceFrom = TFHE.sub(_balances[from], transferValue);
        _balances[from] = newBalanceFrom;
        TFHE.allowThis(newBalanceFrom);
        TFHE.allow(newBalanceFrom, from);
    }
}
