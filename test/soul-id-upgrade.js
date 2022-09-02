const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('Sharkz Soul ID - upgradeable', function () {
  let ownerKey;
  let signerKey;
  let guestKey;
  let guestKey2;
  let guestKey3;
  let contract;
  let dataContract;
  let nftContract;
  let badgeContract1;
  let badgeContract2;

  beforeEach(async function () {
    const accounts = await ethers.getSigners();
    ownerKey = accounts[0];
    signerKey = accounts[1];
    guestKey = accounts[3];
    guestKey2 = accounts[4];
    guestKey3 = accounts[5];

    // PFP contract
    const TokenNFT = await ethers.getContractFactory('NFTERC721');
    nftContract = await TokenNFT.deploy();

    // Soul ID contract
    // deploy v1
    const v1 = await ethers.getContractFactory('SharkzSoulIDV1');
    contract = await upgrades.deployProxy(v1, []);
    await contract.deployed();
    // enable anyone to mint
    await contract.setMintMode(1);
    // Soul ID Data contract (MUST link it before using Soul ID)
    const TokenData = await ethers.getContractFactory('SoulData');
    dataContract = await TokenData.deploy();
    await dataContract.deployed();
    await contract.setSoulDataContract(dataContract.address);

    const Badge = await ethers.getContractFactory('SharkzSoulBadge');

    // deploy badge1
    badgeContract1 = await Badge.deploy(
      'Genesis PFP Minter',
      'SZGM',
      'ipfs://collection.json',
      'ipfs://tokenBaseUri/'
    );
    await badgeContract1.deployed();
    await badgeContract1.setMintMode(1);

    // deploy badge2
    badgeContract2 = await Badge.deploy(
      'Genesis PFP Minter',
      'SZGM',
      'ipfs://collection.json',
      'ipfs://tokenBaseUri/'
    );
    await badgeContract2.deployed();
    await badgeContract2.setMintMode(1);
  });

  it('v1 -> v2 -> v1', async function () {
    await contract.setAdmin(guestKey.address, true);
    expect(await contract.version()).to.equal(1);

    // upgrade to v2
    const v2Contract = await ethers.getContractFactory('SharkzSoulIDV2');
    contract = await upgrades.upgradeProxy(contract.address, v2Contract, []);
    expect(await contract.version()).to.equal(2);

    // rewind to v1
    const v1Contract = await ethers.getContractFactory('SharkzSoulIDV1');
    contract = await upgrades.upgradeProxy(contract.address, v1Contract, []);
    expect(await contract.version()).to.equal(1);
  });

  it(`tokenBadgeTraits() attach ERC721 badge`, async function () {
    // Mint ERC721 token
    expect(await nftContract.balanceOf(ownerKey.address)).to.equal(0);

    await nftContract.ownerMint(ownerKey.address, 1);
    expect(await nftContract.balanceOf(ownerKey.address)).to.equal(1);

    // Setup ERC721 badge for token 0
    await contract.ownerMint(ownerKey.address);
    // console.log(`token 0 owner`, await contract.ownerOf(0));

    await contract.setBadgeContract(nftContract.address, 3, true);
    badgeSetting = await contract.badgeSettings(0);
    // console.log(`badge setting(0)`, badgeSetting);

    // tokenBadgeTraits output test
    await dataContract.setTraitSeqCoding(0);
    traits = await contract.tokenBadgeTraits(0);
    expect(traits).to.equal(
      '{"trait_type":"ERC721 NFT ⠀","value":"NFTERC721"},'
    );
  });

  it(`tokenBadgeTraits() attach Soul Badge`, async function () {
    await contract.ownerMint(ownerKey.address);

    // Mint Soul Badge
    await contract.setBadgeContract(badgeContract1.address, 100, true); // score add 0 * badge balance
    await badgeContract1.ownerMint(contract.address, 0);

    // tokenBadgeTraits output test
    await dataContract.setTraitSeqCoding(0);
    traits = await contract.tokenBadgeTraits(0);
    expect(traits).to.equal(
      '{"trait_type":"Soul Badge ⠀","value":"Genesis PFP Minter"},'
    );
    await dataContract.setTraitSeqCoding(1);
    traits = await contract.tokenBadgeTraits(0);
    expect(traits).to.equal(
      '{"trait_type":"Soul Badge A","value":"Genesis PFP Minter"},'
    );
  });

  it('baseScore() add/remove badges', async function () {
    await contract.ownerMint(guestKey.address);
    await contract.ownerMint(ownerKey.address);

    // before attaching badge
    expect(await contract.scoreByToken(0)).to.equal(1);
    expect(await contract.scoreByToken(1)).to.equal(1);
    expect(await contract.scoreByAddress(guestKey.address)).to.equal(1);
    expect(await contract.scoreByAddress(ownerKey.address)).to.equal(1);

    // attach ERC721 pfp as badge
    await contract.setBadgeContract(nftContract.address, 100, true); // score add 100x score for PFP owner
    await nftContract.ownerMint(guestKey.address, 1);
    await nftContract.ownerMint(ownerKey.address, 1);
    expect(await contract.scoreByToken(0)).to.equal(101);
    expect(await contract.scoreByToken(1)).to.equal(101);
    expect(await contract.scoreByAddress(guestKey.address)).to.equal(101);
    expect(await contract.scoreByAddress(ownerKey.address)).to.equal(101);

    // attach badge #1, note, should submit Soul Contract and Soul Token ID with correct owner
    await contract.setBadgeContract(badgeContract1.address, 0, true); // score add 0 * badge balance
    await badgeContract1.ownerMint(contract.address, 1);

    expect(await contract.scoreByToken(0)).to.equal(101);
    expect(await contract.scoreByToken(1)).to.equal(101);
    expect(await contract.scoreByAddress(guestKey.address)).to.equal(101);
    expect(await contract.scoreByAddress(ownerKey.address)).to.equal(101);

    // attach badge #2, note, should submit Soul Contract and Soul Token ID with correct owner
    await contract.setBadgeContract(badgeContract2.address, 3, true); // score add 3 * badge balance
    await badgeContract2.ownerMint(contract.address, 1);

    expect(await contract.scoreByToken(0)).to.equal(101);
    expect(await contract.scoreByToken(1)).to.equal(104);
    expect(await contract.scoreByAddress(guestKey.address)).to.equal(101);
    expect(await contract.scoreByAddress(ownerKey.address)).to.equal(104);

    // detect badge #1
    await contract.setBadgeContract(badgeContract1.address, 0, false); // score add 0 * badge balance
    expect(await contract.scoreByToken(0)).to.equal(101);
    expect(await contract.scoreByToken(1)).to.equal(104);
    expect(await contract.scoreByAddress(guestKey.address)).to.equal(101);
    expect(await contract.scoreByAddress(ownerKey.address)).to.equal(104);

    // detect badge #2
    await contract.setBadgeContract(badgeContract2.address, 0, false); // score add 0 * badge balance
    expect(await contract.scoreByToken(0)).to.equal(101);
    expect(await contract.scoreByToken(1)).to.equal(101);
    expect(await contract.scoreByAddress(guestKey.address)).to.equal(101);
    expect(await contract.scoreByAddress(ownerKey.address)).to.equal(101);
  });

  it('baseScore()', async function () {
    expect(await contract.scoreByToken(0)).to.equal(0);
    expect(await contract.scoreByToken(1)).to.equal(0);
    expect(await contract.scoreByAddress(guestKey.address)).to.equal(0);
    expect(await contract.scoreByAddress(ownerKey.address)).to.equal(0);

    await contract.ownerMint(guestKey.address);
    await contract.ownerMint(ownerKey.address);

    expect(await contract.scoreByToken(0)).to.equal(1);
    expect(await contract.scoreByToken(1)).to.equal(1);
    expect(await contract.scoreByAddress(guestKey.address)).to.equal(1);
    expect(await contract.scoreByAddress(ownerKey.address)).to.equal(1);
  });

  it(`tokenIdOf(), balanceOf(), totalSupply()`, async function () {
    expect(await contract.balanceOf(guestKey.address)).to.equal(0);
    await contract.ownerMint(guestKey.address);
    expect(await contract.tokenIdOf(guestKey.address)).to.equal(0);
    expect(await contract.balanceOf(guestKey.address)).to.equal(1);
    expect(await contract.totalSupply()).to.equal(1);

    await contract.ownerMint(guestKey2.address);
    expect(await contract.tokenIdOf(guestKey2.address)).to.equal(1);
    expect(await contract.balanceOf(guestKey2.address)).to.equal(1);
    expect(await contract.totalSupply()).to.equal(2);
  });

  it(`tokenURI() no revert`, async function () {
    await contract.ownerMint(ownerKey.address);
    await contract.ownerMint(guestKey.address);
    await contract.tokenURI(0);
    await contract.tokenURI(1);
  });

  it('burn()', async function () {
    await contract.publicMint();
    expect(await contract.ownerOf(0)).to.equal(ownerKey.address);

    await contract.burn(0);
    await expect(contract.ownerOf(0)).to.be.revertedWith(
      'ERC4973SoulContainer: owner query for non-existent token'
    );
  });

  it(`Minting - ownerMint()`, async function () {
    await contract.ownerMint(guestKey.address);
    expect(await contract.balanceOf(guestKey.address)).to.equal(1);
    expect(await contract.totalSupply()).to.equal(1);
  });

  it(`Minting - publicMint()`, async function () {
    await contract.setMintMode(1);
    await contract.publicMint();
    expect(await contract.balanceOf(ownerKey.address)).to.equal(1);
    expect(await contract.totalSupply()).to.equal(1);
  });

  it(`Minting - publicMint() failed with "non-owner of NFT"`, async function () {
    await contract.setMintMode(2);
    await contract.setMintRestrictContract(nftContract.address);
    await expect(contract.publicMint()).to.be.revertedWith(
      'Caller is not a target token owner'
    );
  });

  it(`Minting - publicMint() failed with "one token one address"`, async function () {
    await contract.publicMint();
    await expect(contract.publicMint()).to.be.revertedWith(
      'ERC4973SoulContainer: one token per address'
    );
  });

  it(`Minting - whitelistMint()`, async function () {
    await contract.setSigner(signerKey.address);

    const { chainId } = await ethers.provider.getNetwork();
    const sig = signWhitelist(
      chainId,
      contract.address,
      signerKey,
      ownerKey.address
    );

    // verify signature
    expect(await contract.verifySignature(sig)).to.equal(true);
    await contract.whitelistMint(sig);
    expect(await contract.balanceOf(ownerKey.address)).to.equal(1);
    expect(await contract.totalSupply()).to.equal(1);
  });

  it('setGuardian() add guardian', async function () {
    await contract.publicMint();

    expect(await contract.isGuardian(guestKey.address, 0)).to.equal(false);
    expect(await contract.isGuardian(guestKey2.address, 0)).to.equal(false);
    expect(await contract.isGuardian(guestKey3.address, 0)).to.equal(false);

    await contract.setGuardian(guestKey.address, true, 0);
    await contract.setGuardian(guestKey2.address, true, 0);
    await contract.setGuardian(guestKey3.address, true, 0);

    expect(await contract.isGuardian(guestKey.address, 0)).to.equal(true);
    expect(await contract.isGuardian(guestKey2.address, 0)).to.equal(true);
    expect(await contract.isGuardian(guestKey3.address, 0)).to.equal(true);
  });

  it('setGuardian() add guardian fail with existing guardian', async function () {
    await contract.publicMint();

    expect(await contract.isGuardian(guestKey.address, 0)).to.equal(false);
    await contract.setGuardian(guestKey.address, true, 0);
    expect(await contract.isGuardian(guestKey.address, 0)).to.equal(true);

    // fail
    await expect(
      contract.setGuardian(guestKey.address, true, 0)
    ).to.be.revertedWith('ERC4973SoulContainer: guardian already existed');

    expect(await contract.isGuardian(guestKey.address, 0)).to.equal(true);
  });

  it('setGuardian() remove guardian', async function () {
    await contract.publicMint();

    await contract.setGuardian(guestKey.address, true, 0);
    await contract.setGuardian(guestKey2.address, true, 0);
    await contract.setGuardian(guestKey3.address, true, 0);
    expect(await contract.isGuardian(guestKey.address, 0)).to.equal(true);
    expect(await contract.isGuardian(guestKey2.address, 0)).to.equal(true);
    expect(await contract.isGuardian(guestKey3.address, 0)).to.equal(true);

    await contract.setGuardian(guestKey2.address, false, 0);
    expect(await contract.isGuardian(guestKey2.address, 0)).to.equal(false);

    await expect(
      contract.setGuardian(guestKey2.address, false, 0)
    ).to.be.revertedWith(
      'ERC4973SoulContainer: removing non-existent guardian'
    );

    await contract.setGuardian(guestKey.address, false, 0);
    expect(await contract.isGuardian(guestKey.address, 0)).to.equal(false);

    await contract.setGuardian(guestKey3.address, false, 0);
    expect(await contract.isGuardian(guestKey3.address, 0)).to.equal(false);
  });

  it('requestRenew(), reject with non token owner, request expired, missing guardian', async function () {
    await contract.publicMint(); // contract owner mint token #0
    await contract.connect(guestKey).publicMint(); // guest mint token #1

    await contract.setGuardian(guestKey.address, true, 0);

    // access denied for token #0
    await expect(contract.requestRenew(100, 1)).to.be.revertedWith(
      'ERC4973SoulContainer: query from non-owner or guardian'
    );

    await contract.requestRenew(1, 0); // expiry time = 1
    expect(await contract.isRequestApproved(0)).to.equal(false);
    expect(await contract.isRequestExpired(0)).to.equal(true);

    await contract.requestRenew(0, 0); // not expired
    expect(await contract.isRequestApproved(0)).to.equal(false);
    expect(await contract.isRequestExpired(0)).to.equal(false);

    await contract.setGuardian(guestKey.address, false, 0);
    await expect(contract.isRequestApproved(0)).to.be.revertedWith(
      'ERC4973SoulContainer: approval quorum require at least one guardian'
    );
  });

  it('approveRenew() expired', async function () {
    await contract.publicMint();

    // approver = 1 + 1 = 2, quorum = N/2 +1 = 2
    await contract.setGuardian(guestKey.address, true, 0);
    expect(await contract.getApprovalQuorum(0)).to.equal(2);

    // approve for expired request
    await contract.requestRenew(1, 0);
    await expect(contract.approveRenew(true, 0)).to.be.revertedWith(
      'ERC4973SoulContainer: request expired'
    );
  });

  it('approveRenew(), approval count, quorum, getApprovalCount(), isRequestApproved()', async function () {
    await contract.publicMint();

    // approver = 1 + 1 = 2, quorum = N/2 +1 = 2
    await contract.setGuardian(guestKey.address, true, 0);
    expect(await contract.getApprovalQuorum(0)).to.equal(2);

    // guardians number not enough
    await contract.setGuardian(guestKey.address, false, 0);
    await expect(contract.requestRenew(0, 0)).to.be.revertedWith(
      'ERC4973SoulContainer: approval quorum require at least one guardian'
    );
    await expect(contract.approveRenew(true, 0)).to.be.revertedWith(
      'ERC4973SoulContainer: approval quorum require at least one guardian'
    );

    // approver = 1 + 3 = 4, quorum = N/2 +1 = 3
    await contract.setGuardian(guestKey.address, true, 0);
    await contract.setGuardian(guestKey2.address, true, 0);
    await contract.setGuardian(guestKey3.address, true, 0);
    expect(await contract.getApprovalQuorum(0)).to.equal(3);
    await contract.requestRenew(0, 0);
    // approval count = 1
    expect(await contract.getApprovalCount(0)).to.equal(1);
    expect(await contract.isRequestApproved(0)).to.equal(false);

    // approval count = 2
    await contract.connect(guestKey).approveRenew(true, 0);
    expect(await contract.getApprovalCount(0)).to.equal(2);
    expect(await contract.isRequestApproved(0)).to.equal(false);

    // approval count = 3
    await contract.connect(guestKey2).approveRenew(true, 0);
    expect(await contract.getApprovalCount(0)).to.equal(3);
    expect(await contract.isRequestApproved(0)).to.equal(true);

    // approval count = 4
    await contract.connect(guestKey3).approveRenew(true, 0);
    expect(await contract.getApprovalCount(0)).to.equal(4);
    expect(await contract.isRequestApproved(0)).to.equal(true);

    // remove 1 approve, approval count = 3
    await contract.connect(guestKey2).approveRenew(false, 0);
    expect(await contract.getApprovalCount(0)).to.equal(3);
    expect(await contract.isRequestApproved(0)).to.equal(true);

    // remove 2 approve, approval count = 2
    await contract.connect(guestKey).approveRenew(false, 0);
    expect(await contract.getApprovalCount(0)).to.equal(2);
    expect(await contract.isRequestApproved(0)).to.equal(false);
  });

  it('renew()', async function () {
    await contract.publicMint();

    // approver = 1 + 2 = 3, quorum = N/2 +1 = 2
    await contract.setGuardian(guestKey.address, true, 0);
    await contract.setGuardian(guestKey2.address, true, 0);

    await contract.requestRenew(0, 0);
    await contract.approveRenew(true, 0);
    await contract.connect(guestKey).approveRenew(true, 0);

    await contract.renew(guestKey.address, 0);
    expect(await contract.ownerOf(0)).to.equal(guestKey.address);
  });
});

async function signWhitelist(
  chainId,
  contractAddress,
  whitelistKey,
  mintingAddress
) {
  // Domain data should match whats specified in the DOMAIN_SEPARATOR constructed in the contract
  // https://github.com/msfeldstein/EIP712-whitelisting/blob/main/contracts/EIP712Whitelisting.sol#L33-L43
  const domain = {
    name: 'WhitelistToken',
    version: '1',
    chainId,
    verifyingContract: contractAddress,
  };

  // The types should match the TYPEHASH specified in the contract
  // https://github.com/msfeldstein/EIP712-whitelisting/blob/main/contracts/EIP712Whitelisting.sol#L27-L28
  const types = {
    Minter: [{ name: 'wallet', type: 'address' }],
  };

  const sig = await whitelistKey._signTypedData(domain, types, {
    wallet: mintingAddress,
  });

  return sig;
}
