const { expect } = require("chai");
const { ethers } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("DecentralizedIdentity", function () {
  let DecentralizedIdentity;
  let identity;
  let owner;
  let issuer;
  let user1;
  let user2;
  let addr1;

  const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
  const CLAIM_ISSUER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("CLAIM_ISSUER_ROLE"));

  beforeEach(async function () {
    [owner, issuer, user1, user2, addr1] = await ethers.getSigners();

    DecentralizedIdentity = await ethers.getContractFactory("DecentralizedIdentity");
    identity = await DecentralizedIdentity.deploy();
    await identity.waitForDeployment();

    // Grant claim issuer role to the issuer account
    await identity.addClaimIssuer(issuer.address);
  });

  describe("Deployment", function () {
    it("Should set the right owner as default admin", async function () {
      expect(
        await identity.hasRole(await identity.DEFAULT_ADMIN_ROLE(), owner.address)
      ).to.equal(true);
    });

    it("Should assign admin role to owner", async function () {
      expect(await identity.hasRole(ADMIN_ROLE, owner.address)).to.equal(true);
    });
  });

  describe("Identity Creation", function () {
    it("Should create an identity successfully", async function () {
      await expect(
        identity.connect(user1).createIdentity("ipfs://metadata1")
      )
        .to.emit(identity, "IdentityCreated")
        .withArgs(user1.address, "ipfs://metadata1");
    });

    it("Should fail to create a duplicate identity", async function () {
      await identity.connect(user1).createIdentity("ipfs://metadata1");

      await expect(
        identity.connect(user1).createIdentity("ipfs://metadata1")
      ).to.be.revertedWith("Identity already exists");
    });

    it("Should allow admin to create an identity for someone else", async function () {
      await expect(
        identity.connect(owner).createIdentityFor(user1.address, "ipfs://metadata1")
      )
        .to.emit(identity, "IdentityCreated")
        .withArgs(user1.address, "ipfs://metadata1");
    });

    it("Should fail if non-admin tries to create identity for someone else", async function () {
      await expect(
        identity.connect(addr1).createIdentityFor(user1.address, "ipfs://metadata1")
      ).to.be.revertedWithCustomError(identity, "AccessControlUnauthorizedAccount");
    });
  });

  describe("Identity Updates", function () {
    beforeEach(async function () {
      await identity.connect(user1).createIdentity("ipfs://metadata1");
    });

    it("Should update identity metadata successfully", async function () {
      await expect(
        identity.connect(user1).updateIdentity("ipfs://metadata-updated")
      )
        .to.emit(identity, "IdentityUpdated")
        .withArgs(user1.address, "ipfs://metadata-updated");
    });

    it("Should fail to update a non-existent identity", async function () {
      await expect(
        identity.connect(user2).updateIdentity("ipfs://metadata-updated")
      ).to.be.revertedWith("Identity does not exist");
    });

    it("Should deactivate an identity successfully", async function () {
      await expect(identity.connect(user1).deactivateIdentity())
        .to.emit(identity, "IdentityDeactivated")
        .withArgs(user1.address);

      expect(await identity.isIdentityActive(user1.address)).to.equal(false);
    });

    it("Should fail to update a deactivated identity", async function () {
      await identity.connect(user1).deactivateIdentity();

      await expect(
        identity.connect(user1).updateIdentity("ipfs://metadata-updated")
      ).to.be.revertedWith("Identity is not active");
    });

    it("Should reactivate a deactivated identity", async function () {
      await identity.connect(user1).deactivateIdentity();

      await expect(identity.connect(user1).reactivateIdentity())
        .to.emit(identity, "IdentityReactivated")
        .withArgs(user1.address);

      expect(await identity.isIdentityActive(user1.address)).to.equal(true);
    });
  });

  describe("Controllers", function () {
    beforeEach(async function () {
      await identity.connect(user1).createIdentity("ipfs://metadata1");
    });

    it("Should add a controller successfully", async function () {
      await expect(identity.connect(user1).addController(addr1.address))
        .to.emit(identity, "ControllerAdded")
        .withArgs(user1.address, addr1.address);

      expect(await identity.isController(user1.address, addr1.address)).to.equal(true);
    });

    it("Should fail to add zero address as controller", async function () {
      await expect(
        identity.connect(user1).addController(ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid controller address");
    });

    it("Should remove a controller successfully", async function () {
      await identity.connect(user1).addController(addr1.address);

      await expect(identity.connect(user1).removeController(addr1.address))
        .to.emit(identity, "ControllerRemoved")
        .withArgs(user1.address, addr1.address);

      expect(await identity.isController(user1.address, addr1.address)).to.equal(false);
    });
  });

  describe("Claim Issuer Management", function () {
    it("Should grant claim issuer role successfully", async function () {
      await identity.connect(owner).addClaimIssuer(addr1.address);
      expect(await identity.hasRole(CLAIM_ISSUER_ROLE, addr1.address)).to.equal(true);
    });

    it("Should fail if non-admin tries to grant claim issuer role", async function () {
      await expect(
        identity.connect(addr1).addClaimIssuer(user1.address)
      ).to.be.revertedWithCustomError(identity, "AccessControlUnauthorizedAccount");
    });

    it("Should revoke claim issuer role successfully", async function () {
      await identity.connect(owner).removeClaimIssuer(issuer.address);
      expect(await identity.hasRole(CLAIM_ISSUER_ROLE, issuer.address)).to.equal(false);
    });
  });

  describe("Claims", function () {
    let claimType;

    beforeEach(async function () {
      await identity.connect(user1).createIdentity("ipfs://metadata1");
      claimType = ethers.encodeBytes32String("KYC_VERIFIED");
    });

    it("Should issue a claim successfully", async function () {
      const data = ethers.toUtf8Bytes("KYC passed");

      await expect(
        identity.connect(issuer).issueClaim(user1.address, claimType, data, 0)
      ).to.emit(identity, "ClaimIssued");
    });

    it("Should fail if non-issuer tries to issue a claim", async function () {
      const data = ethers.toUtf8Bytes("KYC passed");

      await expect(
        identity.connect(addr1).issueClaim(user1.address, claimType, data, 0)
      ).to.be.revertedWithCustomError(identity, "AccessControlUnauthorizedAccount");
    });

    it("Should fail to issue a claim about a non-existent identity", async function () {
      const data = ethers.toUtf8Bytes("KYC passed");

      await expect(
        identity.connect(issuer).issueClaim(user2.address, claimType, data, 0)
      ).to.be.revertedWith("Subject identity does not exist");
    });

    it("Should revoke a claim successfully", async function () {
      const data = ethers.toUtf8Bytes("KYC passed");
      const tx = await identity.connect(issuer).issueClaim(user1.address, claimType, data, 0);
      const receipt = await tx.wait();

      const event = receipt.logs
        .map((log) => {
          try {
            return identity.interface.parseLog(log);
          } catch {
            return null;
          }
        })
        .find((parsed) => parsed && parsed.name === "ClaimIssued");

      const claimId = event.args.claimId;

      await expect(identity.connect(issuer).revokeClaim(claimId))
        .to.emit(identity, "ClaimRevoked")
        .withArgs(claimId, issuer.address);
    });

    it("Should fail if someone other than the issuer tries to revoke a claim", async function () {
      const data = ethers.toUtf8Bytes("KYC passed");
      const tx = await identity.connect(issuer).issueClaim(user1.address, claimType, data, 0);
      const receipt = await tx.wait();

      const event = receipt.logs
        .map((log) => {
          try {
            return identity.interface.parseLog(log);
          } catch {
            return null;
          }
        })
        .find((parsed) => parsed && parsed.name === "ClaimIssued");

      const claimId = event.args.claimId;

      await expect(
        identity.connect(addr1).revokeClaim(claimId)
      ).to.be.revertedWith("Only the issuer can revoke a claim");
    });
  });

  describe("Delegation", function () {
    beforeEach(async function () {
      await identity.connect(user1).createIdentity("ipfs://metadata1");
    });

    it("Should grant a delegation successfully", async function () {
      const permissions = ethers.encodeBytes32String("MANAGE_CLAIMS");
      const expirationDate = Math.floor(Date.now() / 1000) + 86400;

      await expect(
        identity.connect(user1).grantDelegation(addr1.address, permissions, expirationDate)
      ).to.emit(identity, "DelegationGranted");
    });

    it("Should fail to grant delegation with a past expiration date", async function () {
      const permissions = ethers.encodeBytes32String("MANAGE_CLAIMS");
      const pastDate = Math.floor(Date.now() / 1000) - 86400;

      await expect(
        identity.connect(user1).grantDelegation(addr1.address, permissions, pastDate)
      ).to.be.revertedWith("Expiration date must be in the future");
    });

    it("Should revoke a delegation successfully", async function () {
      const permissions = ethers.encodeBytes32String("MANAGE_CLAIMS");
      const expirationDate = Math.floor(Date.now() / 1000) + 86400;

      const tx = await identity
        .connect(user1)
        .grantDelegation(addr1.address, permissions, expirationDate);
      const receipt = await tx.wait();

      const event = receipt.logs
        .map((log) => {
          try {
            return identity.interface.parseLog(log);
          } catch {
            return null;
          }
        })
        .find((parsed) => parsed && parsed.name === "DelegationGranted");

      const delegationId = event.args.delegationId;

      await expect(identity.connect(user1).revokeDelegation(delegationId))
        .to.emit(identity, "DelegationRevoked")
        .withArgs(delegationId, user1.address);
    });
  });

  describe("Identity Information Retrieval", function () {
    beforeEach(async function () {
      await identity.connect(user1).createIdentity("ipfs://metadata1");
    });

    it("Should retrieve identity information correctly", async function () {
      const info = await identity.getIdentityInfo(user1.address);

      expect(info[0]).to.equal(user1.address); // owner
      expect(info[1]).to.equal("ipfs://metadata1"); // metadataURI
      expect(info[4]).to.equal(true); // active
    });

    it("Should correctly report identity active status", async function () {
      expect(await identity.isIdentityActive(user1.address)).to.equal(true);
      expect(await identity.isIdentityActive(user2.address)).to.equal(false);
    });
  });
});