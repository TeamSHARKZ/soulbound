async function main() {
  Token = await ethers.getContractFactory('SharkzSoulBadge');
  badgeContract3 = await Token.deploy(
    'The Founderz',
    'SZF',
    'ipfs://QmXAyGgJEUdojvuAbsJJRf2Na5iMK7Pa3m8JghEpwCqzqW',
    'ipfs://QmNoZPsZE94eEwk2trai3kDXwfnGv14ZvvPdigQMbPsrfM'
  );
  await badgeContract3.deployed();
  console.log('Soul Badge - The Founderz: ', badgeContract3.address);
  // npx hardhat --network rinkeby verify 0x60730Fb44B8573ADD1625f9Fc86eB2C761c11BBC "The Founderz" "SZF" "ipfs://QmXAyGgJEUdojvuAbsJJRf2Na5iMK7Pa3m8JghEpwCqzqW" "ipfs://QmNoZPsZE94eEwk2trai3kDXwfnGv14ZvvPdigQMbPsrfM"
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
