const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Sharkz Soul Badge', function () {
  let ownerKey;
  let signerKey;
  let guestKey;
  let guestKey2;

  let soulContract;
  let contract;

  beforeEach(async function () {
    const accounts = await ethers.getSigners();
    ownerKey = accounts[0];
    signerKey = accounts[1];
    guestKey = accounts[2];
    guestKey2 = accounts[3];

    // Soul contract for our Soul badge
    const Soul = await ethers.getContractFactory('SharkzSoulID');
    soulContract = await Soul.deploy();
    await soulContract.deployed();
    // enable anyone to mint
    await soulContract.setMintMode(1);
    await soulContract.ownerMint(guestKey.address);
    await soulContract.ownerMint(ownerKey.address);
    await soulContract.ownerMint(guestKey2.address);

    // PFP contract
    const NFT = await ethers.getContractFactory('NFTERC721');
    nftContract = await NFT.deploy();

    // Soul Badge contract
    // deploy v1
    const v1 = await ethers.getContractFactory('SharkzSoulBadgeV1');
    contract = await upgrades.deployProxy(v1, [
      'Genesis PFP Minter',
      'SZGM',
      'ipfs://collection.json',
      'ipfs://tokenBaseUri/',
    ]);
    await contract.deployed();
    // enable anyone to mint
    const mintMode = 1;
    const mintSupply = 10000;
    const mintStartTime = 0;
    const mintEndTime = 0;
    const maxMintPerSoul = 1;
    await contract.setMintConfig(
      mintMode,
      mintSupply,
      mintStartTime,
      mintEndTime,
      maxMintPerSoul
    );

    // Claim contract
    const Claim = await ethers.getContractFactory('ClaimBadge');
    claimContract = await Claim.deploy();
  });

  it('v1.1 -> v2 -> v1.1', async function () {
    await contract.setAdmin(guestKey.address, true);
    expect(await contract.version()).to.equal('1.1');

    // upgrade to v2
    const v2Contract = await ethers.getContractFactory('SharkzSoulBadgeV2');
    contract = await upgrades.upgradeProxy(contract.address, v2Contract, [
      'Genesis PFP Minter',
      'SZGM',
      'ipfs://collection.json',
      'ipfs://tokenBaseUri/',
    ]);
    expect(await contract.version()).to.equal('2');

    // rewind to v1
    const v1Contract = await ethers.getContractFactory('SharkzSoulBadgeV1');
    contract = await upgrades.upgradeProxy(contract.address, v1Contract, [
      'Genesis PFP Minter',
      'SZGM',
      'ipfs://collection.json',
      'ipfs://tokenBaseUri/',
    ]);
    expect(await contract.version()).to.equal('1.1');
  });

  it('totalSupply() and ownerMint 1', async function () {
    expect(await contract.totalSupply()).to.equal(0);
    await contract.ownerMint(soulContract.address, 0);
    expect(await contract.totalSupply()).to.equal(1);
  });

  it('baseScore(), scoreByToken()', async function () {
    expect(await contract.baseScore()).to.equal(1);
    expect(await contract.scoreByToken(0)).to.equal(0);

    // mint by Soul #0
    await contract.ownerMint(soulContract.address, 0);
    expect(await contract.scoreByToken(0)).to.equal(1);

    // mint by Soul #1
    expect(await contract.scoreByToken(1)).to.equal(0);
    await contract.ownerMint(soulContract.address, 1);
    expect(await contract.scoreByToken(1)).to.equal(1);
  });

  it('Claim mint', async function () {
    await expect(
      contract.claimMint(soulContract.address, 1)
    ).to.be.revertedWith('Linked claim contract is not set');

    // setup claim contract linking
    await contract.setClaimContract(claimContract.address);
    await claimContract.setTarget(contract.address);

    await expect(
      contract.claimMint(soulContract.address, 1)
    ).to.be.revertedWith('Caller is not claim contract');

    // claim contract should check caller is Soul token owner
    await expect(
      claimContract.claim(soulContract.address, 0)
    ).to.be.revertedWith('Caller is not Soul token owner');

    expect(await contract.totalSupply()).to.equal(0);
    await claimContract.claim(soulContract.address, 1);
    await claimContract.connect(guestKey).claim(soulContract.address, 0);
    await claimContract.connect(guestKey2).claim(soulContract.address, 2);
    expect(await contract.totalSupply()).to.equal(3);
  });

  it('setMintSupply - max mint supply', async function () {
    // publc free mint
    await contract.setMintConfig(1, 10000, 0, 0, 1);
    await contract.ownerMint(soulContract.address, 0);

    await contract.setMintConfig(1, 1, 0, 0, 1);
    await expect(
      contract.ownerMint(soulContract.address, 0)
    ).to.be.revertedWith('Max minting supply reached');
  });

  it('setMintSupply - fail with mintConfig.mintStartTime not started', async function () {
    // publc free mint
    await contract.setMintConfig(1, 10000, 3000000000, 0, 1);
    await expect(
      contract.ownerMint(soulContract.address, 0)
    ).to.be.revertedWith('Minting is not started');
  });

  it('setMintSupply - fail with mintConfig.mintEndTime ended', async function () {
    // publc free mint
    await contract.setMintConfig(1, 10000, 0, 1, 1);
    await expect(
      contract.ownerMint(soulContract.address, 0)
    ).to.be.revertedWith('Minting ended');
  });

  it('Mint mode 0: disable mint', async function () {
    // disable mint
    await contract.setMintConfig(0, 10000, 0, 0, 1);

    // owner mint still pass through
    await contract.ownerMint(soulContract.address, 1);

    // other minting disabled
    await expect(
      contract.connect(guestKey).publicMint(soulContract.address, 0)
    ).to.be.revertedWith('Minting disabled');

    // re-enable minting
    await contract.setMintConfig(1, 10000, 0, 0, 1);
    contract.connect(guestKey).publicMint(soulContract.address, 0);
  });

  it('Mint mode 1: no restriction, use OwnerMint()', async function () {
    await contract.setMintConfig(1, 10000, 0, 0, 1);
    await contract.ownerMint(soulContract.address, 0);
  });

  it('Mint mode 1: no restriction use OwnerMint() fail with minting to no owner soul', async function () {
    await contract.setMintConfig(1, 10000, 0, 0, 1);
    await expect(
      contract.ownerMint(soulContract.address, 10)
    ).to.be.revertedWith('ERC5114SoulBadge: Soul token owner not found');
  });

  it('Mint mode 2: restrict to target token owner', async function () {
    // limited to target token owner
    await contract.setMintConfig(2, 10000, 0, 0, 1);
    await expect(
      contract.publicMint(soulContract.address, 1)
    ).to.be.revertedWith('Token contract is the zero address');

    await contract.setMintRestrictContract(nftContract.address);
    await expect(
      contract.publicMint(soulContract.address, 0)
    ).to.be.revertedWith('Caller is not Soul token owner');
    await expect(
      contract.publicMint(soulContract.address, 1)
    ).to.be.revertedWith('Caller is not target token owner');

    // create NFT token owner and then mint badge
    await nftContract.ownerMint(ownerKey.address, 1);
    await nftContract.ownerMint(guestKey.address, 1);

    await contract.connect(ownerKey).publicMint(soulContract.address, 1);
    expect(await contract.totalSupply()).to.equal(1);

    await contract.connect(guestKey).publicMint(soulContract.address, 0);
    expect(await contract.totalSupply()).to.equal(2);
  });

  it(`Minting - whitelistMint()`, async function () {
    await contract.setSigner(signerKey.address);

    const { chainId } = await ethers.provider.getNetwork();
    let sig = signWhitelist(
      chainId,
      contract.address,
      signerKey,
      ownerKey.address
    );

    // verify signature
    expect(await contract.verifySignature(sig)).to.equal(true);
    await contract.whitelistMint(sig, soulContract.address, 1);

    expect(await contract.totalSupply()).to.equal(1);
    expect(await contract.balanceOfSoul(soulContract.address, 0)).to.equal(0);
    expect(await contract.balanceOfSoul(soulContract.address, 1)).to.equal(1);
    expect(await contract.balanceOfSoul(soulContract.address, 2)).to.equal(0);

    await expect(
      contract.whitelistMint(sig, soulContract.address, 2)
    ).to.be.revertedWith('Caller is not Soul token owner');

    // whitelist mint for guest
    sig = signWhitelist(chainId, contract.address, signerKey, guestKey.address);
    await contract
      .connect(guestKey)
      .whitelistMint(sig, soulContract.address, 0);

    // whitelist mint for guest2
    sig = signWhitelist(
      chainId,
      contract.address,
      signerKey,
      guestKey2.address
    );
    await contract
      .connect(guestKey2)
      .whitelistMint(sig, soulContract.address, 2);

    expect(await contract.totalSupply()).to.equal(3);
    expect(await contract.balanceOfSoul(soulContract.address, 0)).to.equal(1);
    expect(await contract.balanceOfSoul(soulContract.address, 1)).to.equal(1);
    expect(await contract.balanceOfSoul(soulContract.address, 2)).to.equal(1);
  });

  it('ownerMint(), balanceOfSoul(), soulOwnerOf()', async function () {
    expect(await contract.balanceOfSoul(soulContract.address, 0)).to.equal(0);
    expect(await contract.balanceOfSoul(soulContract.address, 1)).to.equal(0);
    await expect(contract.soulOwnerOf(0)).to.be.revertedWith(
      'ERC5114SoulBadge: Soul token owner not found'
    );
    await expect(contract.soulOwnerOf(1)).to.be.revertedWith(
      'ERC5114SoulBadge: Soul token owner not found'
    );

    // mint by Soul #0
    await contract.ownerMint(soulContract.address, 0);
    await expect(
      contract.ownerMint(soulContract.address, 0)
    ).to.be.revertedWith('Max minting per soul reached');

    // mint by Soul #1
    await contract.ownerMint(soulContract.address, 1);

    expect(await contract.balanceOfSoul(soulContract.address, 0)).to.equal(1);
    expect(await contract.balanceOfSoul(soulContract.address, 1)).to.equal(1);

    expect(await contract.soulOwnerOf(0)).to.equal(guestKey.address);
    expect(await contract.soulOwnerOf(1)).to.equal(ownerKey.address);
  });

  it('ownerOf(), soulContracts[], soulTokens[]', async function () {
    await contract.ownerMint(soulContract.address, 1);
    await contract.ownerMint(soulContract.address, 0);

    [soulAddr0, soulTid0] = await contract.ownerOf(0);
    [soulAddr1, soulTid1] = await contract.ownerOf(1);
    expect(soulAddr0).to.equal(soulContract.address);
    expect(soulTid0).to.equal(1);
    expect(soulAddr1).to.equal(soulContract.address);
    expect(soulTid1).to.equal(0);

    expect(await contract.soulContracts(0)).to.equal(soulContract.address);
    expect(await contract.soulContracts(1)).to.equal(soulContract.address);
    expect(await contract.soulTokens(0)).to.equal(1);
    expect(await contract.soulTokens(1)).to.equal(0);
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
