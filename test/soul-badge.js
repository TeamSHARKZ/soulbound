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

    // deploy badge contract
    const Token = await ethers.getContractFactory('SharkzSoulBadge');
    contract = await Token.deploy(
      'Genesis PFP Minter',
      'SZGM',
      'ipfs://collection.json',
      'ipfs://tokenBaseUri/'
    );
    await contract.deployed();
    await contract.setMintMode(1);
  });

  it('totalSupply() = 0', async function () {
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

  it('Mint mode 0: disable mint', async function () {
    // disable mint
    await contract.setMintMode(0);
    await expect(
      contract.ownerMint(soulContract.address, 0)
    ).to.be.revertedWith('Minting disabled');
  });

  it('Mint mode 1: public free mint, setMintSupply', async function () {
    // publc free mint
    await contract.setMintMode(1);
    await contract.ownerMint(soulContract.address, 0);

    await contract.setMintSupply(1);
    await expect(
      contract.ownerMint(soulContract.address, 0)
    ).to.be.revertedWith('Max minting supply reached');
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
    ).to.be.revertedWith('ERC5114SoulBadge: max token per soul reached');

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
