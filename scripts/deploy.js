const { ethers, artifacts } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    // Get the contract factory
    const ContractFactory = await ethers.getContractFactory("NFTArena");

    // Deploy the contract
    const VRF_COORDINATOR_SEPOLIA = "0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B";
  const KEY_HASH_SEPOLIA = "0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae";
  const SUBSCRIPTION_ID = "46028468953454012881341962962912460145529398899847134984409356391396909394706";
     const contract = await ContractFactory.deploy(
    SUBSCRIPTION_ID,
    VRF_COORDINATOR_SEPOLIA,
    KEY_HASH_SEPOLIA
  );

    // Wait for deployment to complete
    await contract.waitForDeployment();

    const contractAddress = await contract.getAddress();
    console.log(`Contract deployed to: ${contractAddress}`);

    // Save contract details for the frontend
    saveFrontendFiles(contract, "NFTArena");
}

function saveFrontendFiles(contract, name) {
    const contractsDir = path.join(__dirname, "../src/contract_data/");

    // Ensure the directory exists
    if (!fs.existsSync(contractsDir)) {
        fs.mkdirSync(contractsDir, { recursive: true });
    }

    // Save contract address
    fs.writeFileSync(
        path.join(contractsDir, `${name}-address.json`),
        JSON.stringify({ address: contract.target }, null, 2) // Use contract.target for new ethers.js versions
    );

    // Save contract ABI
    const contractArtifact = artifacts.readArtifactSync(name);
    fs.writeFileSync(
        path.join(contractsDir, `${name}.json`),
        JSON.stringify(contractArtifact, null, 2)
    );

    // console.log(`Contract artifacts saved to ${contractsDir}`);
}

// Execute the deployment script
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
