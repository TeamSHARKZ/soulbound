async function main() {
  Token = await ethers.getContractFactory('SharkzSoulBadge');
  badgeContract2 = await Token.deploy(
    'Genesis Vote Caster',
    'SZGVC',
    'ipfs://QmP4RAvKt78t7a12pZougGGCn8grJ2fFf293nuzX6UnMHe',
    'ipfs://QmZRq5jFLJPGrjRh4T4BKrz9bwwrNmaxEGQZeW18uuy7L4'
  );
  await badgeContract2.deployed();
  console.log('Soul Badge - Genesis Vote Caster: ', badgeContract2.address);
  // npx hardhat --network rinkeby verify 0x5C2d076c3Eff1377937eAFdF8CF5E1244908ab7F "Genesis Vote Caster" "SZGVC" "ipfs://QmP4RAvKt78t7a12pZougGGCn8grJ2fFf293nuzX6UnMHe" "ipfs://QmZRq5jFLJPGrjRh4T4BKrz9bwwrNmaxEGQZeW18uuy7L4"
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
