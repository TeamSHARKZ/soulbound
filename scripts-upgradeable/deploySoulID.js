async function main() {
  // deploy UUPS upgradeable proxy contract
  // use Etherscan verify service to link proxy and verify implementation contract
  // use "timeout" and "pollingInterval" to avoid verification timeout
  // @see https://docs.openzeppelin.com/upgrades-plugins/1.x/api-hardhat-upgrades#deploy-proxy
  const v1 = await ethers.getContractFactory('SharkzSoulIDV1');
  contract = await upgrades.deployProxy(v1, [], {
    timeout: 0,
    pollingInterval: 5000,
  });
  await contract.deployed();
  console.log('Contract upgrade proxy deployed to:', contract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
