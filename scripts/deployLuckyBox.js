const hre = require("hardhat");

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.

    // We get the contract to deploy
    chainLinkSubId = 3178;
    const Token = await ethers.getContractFactory("LuckyBox");
    contract = await Token.deploy(chainLinkSubId);
    await contract.deployed();
    console.log("Contract deployed to:", contract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
