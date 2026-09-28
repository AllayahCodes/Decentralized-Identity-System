// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract DecentralizedIdentity is AccessControl, ReentrancyGuard {

// Define roles for access control
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant CLAIM_ISSUER_ROLE = keccak256("CLAIM_ISSUER_ROLE");

// Claim status options
enum ClaimStatus { Valid, Revoked, Expired }

// Delegation status options
enum DelegationStatus { Active, Revoked, Expired }

// Identity struct - basic profile information
struct Identity {
address owner; 

// The owner of this identity
string metadataURI; 

// URI pointing to off-chain metadata (e.g., IPFS)
uint256 creationDate; 

// When the identity was created
uint256 lastUpdated; 

// When the identity was last updated
bool active; 

// Whether the identity is active
mapping(bytes32 => bool) controllers; 

// Additional addresses that can control this identity
}

// Claim struct - verifiable attestation about an identity
struct Claim {
bytes32 id; 

// Unique identifier for the claim
address issuer; 

// Who issued this claim
address subject; 

// Who this claim is about
bytes32 claimType; 

// Type of claim (e.g., "KYC", "AGE_OVER_18")
bytes data; 

// The claim data (can be encrypted)
uint256 issuanceDate; 

// When the claim was issued
uint256 expirationDate; 

// When the claim expires (0 for no expiration)
ClaimStatus status; 

// Current status of the claim
bytes signature; 

// Issuer's signature of the claim
}

// Delegation struct - temporary authority granted to another address
struct Delegation {
bytes32 id; 

// Unique identifier for the delegation
address delegator; 

// Who granted the delegation
address delegate; 

// Who received the delegation
bytes32 permissions; 

// What the delegate can do (bitmask or hash to permissions)
uint256 creationDate; 

// When the delegation was created
uint256 expirationDate; 

// When the delegation expires
DelegationStatus status; 

// Current status of the delegation
}

// State variables
mapping(address => Identity) private identities; 

// Mapping of addresses to identities
mapping(bytes32 => Claim) private claims; 

// Mapping of claim IDs to claims
mapping(address => bytes32[]) private subjectClaims; 

// Claims about a subject
mapping(address => bytes32[]) private issuerClaims; 

// Claims issued by an issuer
mapping(bytes32 => Delegation) private delegations; 

// Mapping of delegation IDs to delegations
mapping(address => bytes32[]) private delegatorDelegations; 

// Delegations granted by a delegator
mapping(address => bytes32[]) private delegateDelegations;

// Delegations received by a delegate

// Events
event IdentityCreated(address indexed owner, string metadataURI);
event IdentityUpdated(address indexed owner, string metadataURI);
event IdentityDeactivated(address indexed owner);
event IdentityReactivated(address indexed owner);
event ControllerAdded(address indexed identity, address indexed controller);
event ControllerRemoved(address indexed identity, address indexed controller);
event ClaimIssued(
bytes32 indexed claimId,
address indexed issuer,
address indexed subject,
bytes32 claimType
);
event ClaimRevoked(bytes32 indexed claimId, address indexed issuer);
event ClaimExpired(bytes32 indexed claimId);
event DelegationGranted(
bytes32 indexed delegationId,
address indexed delegator,
address indexed delegate,
uint256 expirationDate
);
event DelegationRevoked(bytes32 indexed delegationId, address indexed delegator);
event DelegationExpired(bytes32 indexed delegationId);
/**
* @dev Constructor to initialize the contract.
*/
constructor() {

// Setup admin role for the deployer
_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
_grantRole(ADMIN_ROLE, msg.sender);

// Setup initial permissions
_setRoleAdmin(CLAIM_ISSUER_ROLE, ADMIN_ROLE);
}
/**
* @dev Modifier to check if caller is the identity owner or a controller.
*/
modifier onlyIdentityOwnerOrController(address identityAddress) {
require(
msg.sender == identityAddress ||
msg.sender == identities[identityAddress].owner ||
identities[identityAddress].controllers[keccak256(abi.encodePacked(msg.sender))],
"Not authorized to manage this identity"
);
_;
}
/**
* @dev Modifier to check if caller has a valid delegation.
*/
modifier onlyValidDelegate(address delegator, bytes32 requiredPermission) {
bool hasValidDelegation = false;
for (uint i = 0; i < delegatorDelegations[delegator].length; i++) {
bytes32 delegationId = delegatorDelegations[delegator][i];
Delegation storage delegation = delegations[delegationId];
if (
delegation.delegate == msg.sender &&
delegation.status == DelegationStatus.Active &&
(delegation.expirationDate == 0 || delegation.expirationDate > block.timestamp) &&
(delegation.permissions == bytes32(0) || delegation.permissions ==
requiredPermission)
) {
hasValidDelegation = true;
break;
}
}
require(
msg.sender == delegator || hasValidDelegation,
"No valid delegation for this action"
);
_;
}
/**
* @dev Create a new identity.
*/
function createIdentity(string memory metadataURI) public nonReentrant returns (bool) {
require(identities[msg.sender].owner == address(0), "Identity already exists");
Identity storage identity = identities[msg.sender];
identity.owner = msg.sender;
identity.metadataURI = metadataURI;
identity.creationDate = block.timestamp;
identity.lastUpdated = block.timestamp;
identity.active = true;
emit IdentityCreated(msg.sender, metadataURI);
return true;
}
/**
* @dev Create an identity for someone else.
*/
function createIdentityFor(address identityAddress, string memory metadataURI)
public nonReentrant onlyRole(ADMIN_ROLE) returns (bool) {
require(identityAddress != address(0), "Invalid address");
require(identities[identityAddress].owner == address(0), "Identity already exists");
Identity storage identity = identities[identityAddress];
identity.owner = identityAddress;
identity.metadataURI = metadataURI;
identity.creationDate = block.timestamp;
identity.lastUpdated = block.timestamp;
identity.active = true;
emit IdentityCreated(identityAddress, metadataURI);
return true;
}
/**
* @dev Update an existing identity.
*/
function updateIdentity(string memory metadataURI) public nonReentrant returns (bool) {
require(identities[msg.sender].owner != address(0), "Identity does not exist");
require(identities[msg.sender].active, "Identity is not active");
Identity storage identity = identities[msg.sender];
identity.metadataURI = metadataURI;
identity.lastUpdated = block.timestamp;
emit IdentityUpdated(msg.sender, metadataURI);
return true;
}
/**
* @dev Update someone else's identity.
*/
function updateIdentityFor(address identityAddress, string memory metadataURI)
public nonReentrant onlyIdentityOwnerOrController(identityAddress) returns (bool) {
require(identities[identityAddress].owner != address(0), "Identity does not exist");
require(identities[identityAddress].active, "Identity is not active");
Identity storage identity = identities[identityAddress];
identity.metadataURI = metadataURI;
identity.lastUpdated = block.timestamp;
emit IdentityUpdated(identityAddress, metadataURI);
return true;
}
/**
* @dev Deactivate an identity.
*/
function deactivateIdentity() public nonReentrant returns (bool) {
require(identities[msg.sender].owner != address(0), "Identity does not exist");
require(identities[msg.sender].active, "Identity is already inactive");
identities[msg.sender].active = false;
identities[msg.sender].lastUpdated = block.timestamp;
emit IdentityDeactivated(msg.sender);
return true;
}
/**
* @dev Reactivate an identity.
*/
function reactivateIdentity() public nonReentrant returns (bool) {
require(identities[msg.sender].owner != address(0), "Identity does not exist");
require(!identities[msg.sender].active, "Identity is already active");
identities[msg.sender].active = true;
identities[msg.sender].lastUpdated = block.timestamp;
emit IdentityReactivated(msg.sender);
return true;
}
/**
* @dev Add a controller to an identity.
*/
function addController(address controller) public nonReentrant returns (bool) {
require(identities[msg.sender].owner != address(0), "Identity does not exist");
require(controller != address(0), "Invalid controller address");
bytes32 controllerKey = keccak256(abi.encodePacked(controller));
require(!identities[msg.sender].controllers[controllerKey], "Controller already exists");
identities[msg.sender].controllers[controllerKey] = true;
identities[msg.sender].lastUpdated = block.timestamp;
emit ControllerAdded(msg.sender, controller);
return true;
}
/**
* @dev Remove a controller from an identity.
*/
function removeController(address controller) public nonReentrant returns (bool) {
require(identities[msg.sender].owner != address(0), "Identity does not exist");
bytes32 controllerKey = keccak256(abi.encodePacked(controller));
require(identities[msg.sender].controllers[controllerKey], "Controller does not exist");
identities[msg.sender].controllers[controllerKey] = false;
identities[msg.sender].lastUpdated = block.timestamp;
emit ControllerRemoved(msg.sender, controller);
return true;
}
/**
* @dev Issue a new claim about a subject.
*/
function issueClaim(
address subject,
bytes32 claimType,
bytes memory data,
uint256 expirationDate
) public nonReentrant onlyRole(CLAIM_ISSUER_ROLE) returns (bytes32) {
require(subject != address(0), "Invalid subject address");
require(identities[subject].owner != address(0), "Subject identity does not exist");
bytes32 claimId = keccak256(abi.encodePacked(
msg.sender,
subject,
claimType,
data,
block.timestamp
));
bytes32 messageHash = keccak256(abi.encodePacked(
claimId,
msg.sender,
subject,
claimType,
data,
block.timestamp,
expirationDate
));
bytes memory signature = createDummySignature(messageHash);
Claim storage claim = claims[claimId];
claim.id = claimId;
claim.issuer = msg.sender;
claim.subject = subject;
claim.claimType = claimType;
claim.data = data;
claim.issuanceDate = block.timestamp;
claim.expirationDate = expirationDate;
claim.status = ClaimStatus.Valid;
claim.signature = signature;
subjectClaims[subject].push(claimId);
issuerClaims[msg.sender].push(claimId);
emit ClaimIssued(claimId, msg.sender, subject, claimType);
return claimId;
}
/**
* @dev Helper function to create a dummy signature.
*/
function createDummySignature(bytes32 messageHash) private view returns (bytes memory) {
bytes32 r = bytes32(uint256(uint160(msg.sender)));
bytes32 s = bytes32(uint256(block.timestamp));
uint8 v = 27;
return abi.encodePacked(r, s, v);
}

/**
* @dev Revoke a claim that you've issued.
*/
function revokeClaim(bytes32 claimId) public nonReentrant returns (bool) {
require(claims[claimId].id == claimId, "Claim does not exist");
require(claims[claimId].issuer == msg.sender, "Only the issuer can revoke a claim");
require(claims[claimId].status == ClaimStatus.Valid, "Claim is already revoked or expired");
claims[claimId].status = ClaimStatus.Revoked;
emit ClaimRevoked(claimId, msg.sender);
return true;
}
/**
* @dev Mark a claim as expired.
*/
function expireClaim(bytes32 claimId) public returns (bool) {
require(claims[claimId].id == claimId, "Claim does not exist");
require(claims[claimId].status == ClaimStatus.Valid, "Claim is already revoked or expired");
require(
claims[claimId].expirationDate > 0 &&
claims[claimId].expirationDate <= block.timestamp,
"Claim has not expired"
);
claims[claimId].status = ClaimStatus.Expired;
emit ClaimExpired(claimId);
return true;
}
/**
* @dev Verify a claim.
*/
function verifyClaim(bytes32 claimId) public view returns (
bool valid,
address issuer,
address subject,
bytes32 claimType,
uint256 issuanceDate,
uint256 expirationDate,
ClaimStatus status
) {
Claim storage claim = claims[claimId];
if (claim.id != claimId) {
return (false, address(0), address(0), bytes32(0), 0, 0, ClaimStatus.Revoked);
}
if (claim.status == ClaimStatus.Valid &&
claim.expirationDate > 0 &&
claim.expirationDate <= block.timestamp) {
return (
false,
claim.issuer,
claim.subject,
claim.claimType,
claim.issuanceDate,
claim.expirationDate,
ClaimStatus.Expired
);
}
return (
claim.status == ClaimStatus.Valid,
claim.issuer,
claim.subject,
claim.claimType,
claim.issuanceDate,
claim.expirationDate,
claim.status
);
}
/**
* @dev Internal helper to compute the Ethereum signed message hash.
*/
function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
}
/**
* @dev Verify a claim signature.
*/
function verifyClaimSignature(bytes32 claimId) public view returns (bool valid) {
Claim storage claim = claims[claimId];
if (claim.id != claimId) {
return false;
}
bytes32 messageHash = keccak256(abi.encodePacked(
claim.id,
claim.issuer,
claim.subject,
claim.claimType,
claim.data,
claim.issuanceDate,
claim.expirationDate
));

// Use our helper function to get the Ethereum signed message hash.
bytes32 ethSignedMessageHash = _toEthSignedMessageHash(messageHash);
address recoveredSigner = ECDSA.recover(ethSignedMessageHash, claim.signature);
return recoveredSigner == claim.issuer;
}
/**
* @dev Get claims issued about a subject.
*/
function getClaimsAbout(address subject) public view returns (bytes32[] memory) {
return subjectClaims[subject];
}
/**
* @dev Get claims issued by an issuer.
*/
function getClaimsBy(address issuer) public view returns (bytes32[] memory) {
return issuerClaims[issuer];
}
/**
* @dev Get claim data.
*/
function getClaimData(bytes32 claimId) public view returns (bytes memory) {
require(claims[claimId].id == claimId, "Claim does not exist");
require(
msg.sender == claims[claimId].subject ||
msg.sender == claims[claimId].issuer ||
hasRole(ADMIN_ROLE, msg.sender),
"Not authorized to access claim data"
);
return claims[claimId].data;
}
/**
* @dev Grant a delegation to another address.
*/
function grantDelegation(
address delegate,
bytes32 permissions,
uint256 expirationDate
) public nonReentrant returns (bytes32) {
require(delegate != address(0), "Invalid delegate address");
require(identities[msg.sender].owner != address(0), "Delegator identity does not exist");
require(expirationDate > block.timestamp, "Expiration date must be in the future");
bytes32 delegationId = keccak256(abi.encodePacked(
msg.sender,
delegate,
permissions,
block.timestamp
));
Delegation storage delegation = delegations[delegationId];
delegation.id = delegationId;
delegation.delegator = msg.sender;
delegation.delegate = delegate;
delegation.permissions = permissions;
delegation.creationDate = block.timestamp;
delegation.expirationDate = expirationDate;
delegation.status = DelegationStatus.Active;
delegatorDelegations[msg.sender].push(delegationId);
delegateDelegations[delegate].push(delegationId);
emit DelegationGranted(delegationId, msg.sender, delegate, expirationDate);
return delegationId;
}
/**
* @dev Revoke a delegation you've granted.
*/
function revokeDelegation(bytes32 delegationId) public nonReentrant returns (bool) {
require(delegations[delegationId].id == delegationId, "Delegation does not exist");
require(delegations[delegationId].delegator == msg.sender, "Only the delegator can revoke a delegation");
require(delegations[delegationId].status == DelegationStatus.Active, "Delegation is already revoked or expired");
delegations[delegationId].status = DelegationStatus.Revoked;
emit DelegationRevoked(delegationId, msg.sender);
return true;
}
/**
* @dev Mark a delegation as expired.
*/
function expireDelegation(bytes32 delegationId) public returns (bool) {
require(delegations[delegationId].id == delegationId, "Delegation does not exist");
require(delegations[delegationId].status == DelegationStatus.Active, "Delegation is already revoked or expired");
require(
delegations[delegationId].expirationDate <= block.timestamp,
"Delegation has not expired"
);
delegations[delegationId].status = DelegationStatus.Expired;
emit DelegationExpired(delegationId);
return true;
}
/**
* @dev Check if a delegation is valid.
*/
function isDelegationValid(bytes32 delegationId) public view returns (bool) {
if (delegations[delegationId].id != delegationId) {
return false;
}
if (delegations[delegationId].status != DelegationStatus.Active) {
return false;
}
if (delegations[delegationId].expirationDate <= block.timestamp) {
return false;
}
return true;
}
/**
* @dev Get delegations granted by a delegator.
*/
function getDelegationsBy(address delegator) public view returns (bytes32[] memory) {
return delegatorDelegations[delegator];
}
/**
* @dev Get delegations received by a delegate.
*/
function getDelegationsFor(address delegate) public view returns (bytes32[] memory) {
return delegateDelegations[delegate];
}
/**
* @dev Grant claim issuer role to an address.
*/
function addClaimIssuer(address issuer) public onlyRole(ADMIN_ROLE) {
grantRole(CLAIM_ISSUER_ROLE, issuer);
}
/**
* @dev Revoke claim issuer role from an address.
*/
function removeClaimIssuer(address issuer) public onlyRole(ADMIN_ROLE) {
revokeRole(CLAIM_ISSUER_ROLE, issuer);
}
/**
* @dev Check if an identity exists and is active.
*/
function isIdentityActive(address identityAddress) public view returns (bool) {
return identities[identityAddress].owner != address(0) && identities[identityAddress].active;
}
/**
* @dev Get identity information.
*/
function getIdentityInfo(address identityAddress) public view returns (
address owner,
string memory metadataURI,
uint256 creationDate,
uint256 lastUpdated,
bool active
) {
Identity storage identity = identities[identityAddress];
return (
identity.owner,
identity.metadataURI,
identity.creationDate,
identity.lastUpdated,
identity.active
);
}
/**
* @dev Check if an address is a controller for an identity.
*/
function isController(address identityAddress, address controllerAddress) public view returns
(bool) {
return
identities[identityAddress].controllers[keccak256(abi.encodePacked(controllerAddress))];
}
}