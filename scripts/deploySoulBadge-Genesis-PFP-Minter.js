async function main() {
  Token = await ethers.getContractFactory('SharkzSoulBadge');
  badgeContract3 = await Token.deploy(
    'Genesis PFP Minter',
    'SZGPFP',
    'ipfs://QmdZjEj89w7Ww41URG1PTyq7bxxpyxrwbk7wB8Trjr6UxG',
    'ipfs://QmZ4FqfxQ3K216DkvzpyVSbrFhnD9Tgxjm38aP45MCEGyD'
  );
  await badgeContract3.deployed();
  console.log('Soul Badge - Genesis PFP Minter: ', badgeContract3.address);
  // npx hardhat --network rinkeby verify 0x5C2d076c3Eff1377937eAFdF8CF5E1244908ab7F "Genesis PFP Minter" "SZGPFP" "ipfs://QmdZjEj89w7Ww41URG1PTyq7bxxpyxrwbk7wB8Trjr6UxG" "ipfs://QmZ4FqfxQ3K216DkvzpyVSbrFhnD9Tgxjm38aP45MCEGyD"
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
