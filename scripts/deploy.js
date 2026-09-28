const hre = require("hardhat");

async function main() {
  console.log("🚀 Starting DecentralizedIdentity deployment...\n");

  // Get the deployer account
  const [deployer, sampleUser] = await hre.ethers.getSigners();
  console.log("📋 Deployer account:", deployer.address);
  console.log(
    "💰 Account balance:",
    hre.ethers.formatEther(await hre.ethers.provider.getBalance(deployer.address)),
    "ETH\n"
  );

  // Deploy the contract
  console.log("📦 Deploying DecentralizedIdentity contract...");
  const DecentralizedIdentity = await hre.ethers.getContractFactory("DecentralizedIdentity");
  const identity = await DecentralizedIdentity.deploy();

  await identity.waitForDeployment();
  const contractAddress = await identity.getAddress();

  console.log("✅ DecentralizedIdentity deployed successfully!");
  console.log("📍 Contract address:", contractAddress);
  console.log("🔗 Network:", hre.network.name);
  console.log(
    "⛽ Gas used for deployment:",
    (await hre.ethers.provider.getTransactionReceipt(identity.deploymentTransaction().hash)).gasUsed.toString()
  );

  // Setup initial roles for demonstration
  console.log("\n🔧 Setting up initial roles...");

  // Deployer already holds DEFAULT_ADMIN_ROLE and ADMIN_ROLE from the constructor.
  // Grant CLAIM_ISSUER_ROLE to the deployer so it can issue sample claims below.
  const claimIssuerTx = await identity.addClaimIssuer(deployer.address);
  await claimIssuerTx.wait();
  console.log("✅ CLAIM_ISSUER_ROLE granted to deployer for testing");

  // Create a sample identity for demonstration
  console.log("\n👤 Creating sample identity...");

  const sampleMetadataURI = "ipfs://sample-identity-metadata";
  const createTx = await identity.createIdentity(sampleMetadataURI);
  await createTx.wait();
  console.log("✅ Sample identity created for deployer:", deployer.address);

  // If a second signer is available, create an identity for them too and issue a claim about them
  if (sampleUser) {
    console.log("\n👤 Creating sample identity for second test account...");
    const createTx2 = await identity.connect(sampleUser).createIdentity("ipfs://sample-subject-metadata");
    await createTx2.wait();
    console.log("✅ Sample identity created for:", sampleUser.address);

    // Issue a sample claim from deployer (issuer) about sampleUser (subject)
    console.log("\n📝 Issuing sample claim...");

    const claimType = hre.ethers.encodeBytes32String("KYC_VERIFIED");
    const claimData = hre.ethers.toUtf8Bytes("Sample KYC verification claim");
    const noExpiration = 0; // 0 = no expiration, per contract comments

    const issueTx = await identity.issueClaim(sampleUser.address, claimType, claimData, noExpiration);
    const issueReceipt = await issueTx.wait();
    console.log("✅ Sample claim issued about:", sampleUser.address);

    // Pull the claimId back out from the ClaimIssued event for reference
    const claimIssuedEvent = issueReceipt.logs
      .map((log) => {
        try {
          return identity.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((parsed) => parsed && parsed.name === "ClaimIssued");

    if (claimIssuedEvent) {
      console.log("🔑 Sample claim ID:", claimIssuedEvent.args.claimId);
    }
  }

  console.log("\n" + "=".repeat(60));
  console.log("🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉");
  console.log("=".repeat(60));
  console.log(`📋 Copy this contract address to your frontend:`);
  console.log(`📍 ${contractAddress}`);
  console.log("=".repeat(60));

  // Save deployment info
  const deploymentInfo = {
    contractAddress: contractAddress,
    network: hre.network.name,
    deployer: deployer.address,
    deploymentTime: new Date().toISOString(),
    sampleIdentity: deployer.address,
  };

  console.log("\n📄 Deployment Summary:", JSON.stringify(deploymentInfo, null, 2));

  return contractAddress;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then((contractAddress) => {
    console.log(`\n🔗 Contract deployed at: ${contractAddress}`);
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });