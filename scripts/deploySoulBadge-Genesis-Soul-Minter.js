async function main() {
  Token = await ethers.getContractFactory('SharkzSoulBadge');
  badgeContract1 = await Token.deploy(
    'Genesis Soul Minter',
    'SZGSM',
    'ipfs://QmaiyME31GGTrfYrLDojTp47VV2fgVYsFzyrDyEng6CNnq',
    'ipfs://QmaCC6Q5YMz9mFk1YKVKYUYcNgkXHCLvsSMicExP2aFoQ8'
  );
  await badgeContract1.deployed();
  console.log('Soul Badge - Genesis Soul Minter: ', badgeContract1.address);
  // npx hardhat --network rinkeby verify 0xa95E3565D1134B14B39fB3da36C1EA576e1541df "Genesis Soul Minter" "SZGSM" "ipfs://QmaiyME31GGTrfYrLDojTp47VV2fgVYsFzyrDyEng6CNnq" "ipfs://QmaCC6Q5YMz9mFk1YKVKYUYcNgkXHCLvsSMicExP2aFoQ8"
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
