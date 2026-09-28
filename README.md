# 🆔 Decentralized Identity System

A robust, self-sovereign identity (SSI) smart contract implemented in Solidity. This system enables individuals to own, manage, and share their digital identity without relying on centralized authorities. It features identity lifecycle management, verifiable attestations (claims), time-bound delegations, and role-based access control.

⚡ Features
1. 👤 Identity Management

🔐 Self-Sovereign Creation: Users can create their unique decentralized identities tied directly to their Ethereum address.

📦 Minimal On-Chain Footprint: Identifiers store minimal data on-chain with off-chain metadata links (e.g., IPFS URIs).

🔄 Control & Lifecycle: Identity owners can update metadata, deactivate/reactivate identities, and assign secondary controllers.


2. 📜 Claims System (Verifiable Attestations)

✍️ Authorized Issuance: Authorized issuers can create signed claims (e.g., KYC, AGE_OVER_18) about any valid identity subject.

🔑 Cryptographic Proofs: Built-in verification via standard function calls and OpenZeppelin ECDSA signatures.  

⏳ Revocation & Expiration: Complete lifecycle tracking for valid, revoked, and expired claims.


3. 🤝 Delegation Framework

⏱️ Temporary Permissions: Grant time-bound authority to delegate addresses with customizable permission bits.

🛠️ Flexible Access: Delegates can execute authorized actions on behalf of identity owners.   


4. 🛡️ Security & Access Control

🧱 OpenZeppelin Standard: Utilizes AccessControl for role hierarchies and ReentrancyGuard for execution safety.   

👑 Role Management: Built-in roles including ADMIN_ROLE and CLAIM_ISSUER_ROLE.  


🏗️ Contract Architecture
Core Data StructuresEnums

🚦ClaimStatus: { Valid, Revoked, Expired }   
🏷️ DelegationStatus: { Active, Revoked, Expired }   


Structs
👤 Identity: Stores owner address, metadata URI, timestamps, active status, and controller mappings.   
📑 Claim: Stores unique id, issuer, subject, claimType, encrypted/raw data, issuance/expiration timestamps, status, and signature.   
📜 Delegation: Tracks id, delegator, delegate, permission bitmasks, creation/expiration dates, and status.   

⚙️ Smart Contract Functions
👤 Identity Functions
createIdentity(string metadataURI)
Access / Role: Public  
Description: Registers a new self-sovereign identity.  

createIdentityFor(address identityAddress, string metadataURI)
Access / Role: ADMIN_ROLE   
Description: Admin helper to register an identity for an address.   
updateIdentity(string metadataURI)
Access / Role: Identity Owner  
Description: Updates off-chain metadata reference.  

deactivateIdentity() / reactivateIdentity()
Access / Role: Identity Owner   
Description: Toggles active status of an identity. 

addController(address controller)
Access / Role: Identity Owner  
Description: Assigns a secondary controller address.   

removeController(address controller)
Access / Role: Identity Owner  
Description: Removes a secondary controller address.   


📜 Claims Functions
issueClaim(address subject, bytes32 claimType, bytes data, uint256 expirationDate)
Access / Role: CLAIM_ISSUER_ROLE 
Description: Issues a cryptographic claim for a subject.  

revokeClaim(bytes32 claimId)
Access / Role: Issuer Only 
Description: Revokes an issued claim.   

expireClaim(bytes32 claimId)
Access / Role: Public 
Description: Updates claim status to Expired if past expiration time.  

verifyClaim(bytes32 claimId)
Access / Role: View  
Description: Returns validity status and claim metadata.  

verifyClaimSignature(bytes32 claimId)
Access / Role: View 
Description: Recovers signature using ECDSA and verifies against issuer.  

getClaimData(bytes32 claimId)
Access / Role: Restricted   
Description: Accesses claim data (Subject, Issuer, or Admin only). 

🤝 Delegation Functions
grantDelegation(address delegate, bytes32 permissions, uint256 expirationDate)
Access / Role: Identity Owner  
Description: Grants time-bound delegation rights. 

revokeDelegation(bytes32 delegationId)
Access / Role: Delegator Only
Description: Revokes an active delegation.  

isDelegationValid(bytes32 delegationId)
Access / Role: View  
Description: Checks if a delegation is currently active and unexpired.   

🚀 Installation & Deployment
📋 Prerequisites
🟢 Node.js (v16.x or higher)
👷 Hardhat or ⚒️ Foundry

🛠️ Steps
1. Clone the repository:
Bash
git clone [https://github.com/your-username/decentralized-identity-system.git](https://github.com/your-username/decentralized-identity-system.git)
cd decentralized-identity-system

2. Install dependencies:
Bash
npm install @openzeppelin/contracts

3. Compile the Smart Contract:
Bash
npx hardhat compile

4. Deploy:
Create a deployment script in scripts/deploy.js:

JavaScript
const hre = require("hardhat");

async function main() {
  const DecentralizedIdentity = await hre.ethers.getContractFactory("DecentralizedIdentity");
  const identityContract = await DecentralizedIdentity.deploy();

  await identityContract.deployed();
  console.log(`DecentralizedIdentity deployed to: ${identityContract.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

5. Run deployment:

Bash
npx hardhat run scripts/deploy.js --network

📌 Specification & Dependencies
💎 Solidity Version: ^0.8.25   
📄 License: MIT   
📚 External Dependencies:
@openzeppelin/contracts/access/AccessControl.sol[cite: 1]
@openzeppelin/contracts/security/ReentrancyGuard.sol[cite: 1]
@openzeppelin/contracts/utils/cryptography/ECDSA.sol[cite: 1]
