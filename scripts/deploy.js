const { ethers } = require("hardhat");

async function main() {
  const SecureSwapDEX = await ethers.getContractFactory("SecureSwapDEX");
  const secureSwapDEX = await SecureSwapDEX.deploy();

  await secureSwapDEX.deployed();

  console.log("SecureSwapDEX contract deployed to:", secureSwapDEX.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
