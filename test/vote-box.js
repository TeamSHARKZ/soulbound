const { expect } = require("chai");
const { ethers } = require("hardhat");

async function createPoll(
  contract,
  nftContract,
  soulIDContract,
  startTime,
  endTime,
  disableChange,
  onlyAllowlist,
  onlyTokenHolder,
  disableScore
) {
  const topic = "poll topic";
  const content = "";
  const maxPollOption = 3;
  await contract.createPoll(
    topic,
    content,
    maxPollOption,
    startTime,
    endTime,
    disableChange,
    onlyAllowlist,
    onlyTokenHolder,
    disableScore
  );
  const pid = (await contract.pollCount()) - 1;
  await contract.setPollTokenContract(pid, nftContract.address);
  await contract.setPollScoreContract(pid, soulIDContract.address);
}

describe("Vote Box", function () {
  let contract;
  let ownerKey;
  let whitelistKey;
  let guestKey;
  let nftContract;
  let soulIDContract;
  let badgeContract1;
  let badgeContract2;
  let defaultStartTime = 1;
  let defaultEndTime = 2000000000;

  beforeEach(async function () {
    const accounts = await ethers.getSigners();
    ownerKey = accounts[0];
    whitelistKey = accounts[1];
    guestKey = accounts[2];

    // deploy Soul ID
    const SoulID = await ethers.getContractFactory("SharkzSoulID");
    soulIDContract = await SoulID.deploy();
    await soulIDContract.deployed();
    // enable anyone to mint
    await soulIDContract.setMintMode(1);

    // Soul ID Data contract (MUST link it before using Soul ID)
    const TokenData = await ethers.getContractFactory("SoulData");
    dataContract = await TokenData.deploy();
    await dataContract.deployed();
    await soulIDContract.setSoulDataContract(dataContract.address);

    // deploy badge1
    const Badge = await ethers.getContractFactory("SharkzSoulBadge");
    badgeContract1 = await Badge.deploy(
      "Genesis PFP Minter",
      "SZGM",
      "ipfs://collection.json",
      "ipfs://tokenBaseUri/"
    );
    await badgeContract1.deployed();
    await badgeContract1.setMintConfig(1, 10000, 0, 0, 1);
    // deploy badge2
    badgeContract2 = await Badge.deploy(
      "Genesis Voter",
      "SZGV",
      "ipfs://collection.json",
      "ipfs://tokenBaseUri/"
    );
    await badgeContract2.deployed();
    await badgeContract2.setMintConfig(1, 10000, 0, 0, 1);

    // PFP NFT contract
    // const TokenNFT = await ethers.getContractFactory('NFT721Random');
    // nftContract = await TokenNFT.deploy();
    // await nftContract.setUnrevealURI('');
    // await nftContract.changeVRFSubId(3178);
    const TokenNFT = await ethers.getContractFactory("NFT721AStruct");
    nftContract = await TokenNFT.deploy();

    // Deploy VoteBox
    const Token = await ethers.getContractFactory("VoteBox");
    contract = await Token.deploy();
    await contract.deployed();

    const disableChange = 0;
    const onlyAllowlist = 0;
    const onlyTokenHolder = 0;
    const disableScore = 0;
    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      defaultStartTime,
      defaultEndTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );
  });

  it("Score enabled, Soul ID + Badge score", async function () {
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 0;
    const onlyAllowlist = 0;
    const onlyTokenHolder = 0;
    const disableScore = 0;
    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );

    // last poll id
    const pid = (await contract.pollCount()) - 1;
    const poll = await contract.polls(pid);
    expect(poll["scoreContract"]).to.equal(soulIDContract.address);

    // mint Soul ID
    await soulIDContract.ownerMint(ownerKey.address);
    expect(await soulIDContract.balanceOf(ownerKey.address)).to.equal(1);

    await contract.vote(pid, 3, 0);
    expect(await contract.getPollTotalVoteCount(pid)).to.equal(1);
    expect(await contract.getPollTotalScore(pid)).to.equal(1);
    expect(await contract.getPollOptionScore(pid, 3)).to.equal(1);

    // mint badge +3 voting score
    await soulIDContract.setBadgeContract(badgeContract1.address, 3, true); // + 3x badge qty
    await badgeContract1.ownerMint(soulIDContract.address, 0);
    // re-vote to update score
    await contract.vote(pid, 3, 0);
    expect(await contract.getPollOptionScore(pid, 3)).to.equal(4);
    expect(await contract.getPollTotalScore(pid)).to.equal(4);
    // await badgeContract1.burn(0);

    // mint badge +7 voting score
    await soulIDContract.setBadgeContract(badgeContract2.address, 7, true); // + 7x badge qty
    await badgeContract2.ownerMint(soulIDContract.address, 0);
    // re-vote to update score
    await contract.vote(pid, 3, 0);
    expect(await contract.getPollOptionScore(pid, 1)).to.equal(0);
    expect(await contract.getPollOptionScore(pid, 2)).to.equal(0);
    expect(await contract.getPollOptionScore(pid, 3)).to.equal(11);
    expect(await contract.getPollTotalScore(pid)).to.equal(11);

    // change to option 2
    await contract.vote(pid, 2, 0);
    expect(await contract.getPollOptionScore(pid, 1)).to.equal(0);
    expect(await contract.getPollOptionScore(pid, 2)).to.equal(11);
    expect(await contract.getPollOptionScore(pid, 3)).to.equal(0);
    expect(await contract.getPollTotalScore(pid)).to.equal(11);

    // change back to option 3
    await contract.vote(pid, 3, 0);
    expect(await contract.getPollOptionScore(pid, 1)).to.equal(0);
    expect(await contract.getPollOptionScore(pid, 2)).to.equal(0);
    expect(await contract.getPollOptionScore(pid, 3)).to.equal(11);
    expect(await contract.getPollTotalScore(pid)).to.equal(11);
  });

  it("Score disabled, Soul ID + Badge score", async function () {
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 0;
    const onlyAllowlist = 0;
    const onlyTokenHolder = 0;
    const disableScore = 1;
    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );

    // last poll id
    const pid = (await contract.pollCount()) - 1;
    const poll = await contract.polls(pid);
    expect(poll["scoreContract"]).to.equal(soulIDContract.address);

    // mint Soul ID
    await soulIDContract.ownerMint(ownerKey.address);
    await contract.vote(pid, 3, 0);
    expect(await contract.getPollTotalVoteCount(pid)).to.equal(1);
    expect(await contract.getPollTotalScore(pid)).to.equal(1);
    expect(await contract.getPollOptionScore(pid, 3)).to.equal(1);

    // remain the same svore when minted badge +3 voting score
    await soulIDContract.setBadgeContract(badgeContract1.address, 3, true); // + 3x badge qty
    await badgeContract1.ownerMint(soulIDContract.address, 0);
    expect(await contract.getPollTotalVoteCount(pid)).to.equal(1);
    expect(await contract.getPollTotalScore(pid)).to.equal(1);
    expect(await contract.getPollOptionScore(pid, 3)).to.equal(1);
  });

  it("Create Poll", async function () {
    const topic = "my topic";
    const content = "my content";
    const maxPollOption = 3;
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 1;
    const onlyAllowlist = 1;
    const onlyTokenHolder = 1;
    const disableScore = 1;
    await contract.createPoll(
      topic,
      content,
      maxPollOption,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );

    // last poll id
    const pid = (await contract.pollCount()) - 1;

    // setup token, score contracts
    await contract.setPollTokenContract(pid, nftContract.address);
    await contract.setPollScoreContract(pid, soulIDContract.address);

    const poll = await contract.polls(pid);
    expect(poll["topic"]).to.equal(topic);
    expect(poll["content"]).to.equal(content);
    expect(poll["optionCount"]).to.equal(maxPollOption);
    expect(poll["tokenContract"]).to.equal(nftContract.address);
    expect(poll["scoreContract"]).to.equal(soulIDContract.address);
    expect(await contract.getPollStartTime(pid)).to.equal(startTime);
    expect(await contract.getPollEndTime(pid)).to.equal(endTime);

    const settings = await contract.getPollSettings(pid);
    expect(settings["disableChange"]).to.equal(true);
    expect(settings["onlyAllowlist"]).to.equal(true);
    expect(settings["onlyTokenHolder"]).to.equal(true);
    expect(settings["disableScore"]).to.equal(true);
  });

  it(`Update Poll Start Time`, async function () {
    const topic = "my topic";
    const content = "my content";
    const maxPollOption = 3;
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 1;
    const onlyAllowlist = 1;
    const onlyTokenHolder = 1;
    const disableScore = 1;
    await contract.createPoll(
      topic,
      content,
      maxPollOption,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );

    // last poll id
    const pid = (await contract.pollCount()) - 1;
    expect(await contract.getPollStartTime(pid)).to.equal(startTime);

    // after update
    let customTime = 3876543211;
    await contract.setPollStartTime(pid, customTime);
    expect(await contract.getPollStartTime(pid)).to.equal(customTime);

    // check existing settings is not changed
    expect(await contract.getPollEndTime(pid)).to.equal(endTime);
    const settings = await contract.getPollSettings(pid);
    expect(settings["disableChange"]).to.equal(true);
    expect(settings["onlyAllowlist"]).to.equal(true);
    expect(settings["onlyTokenHolder"]).to.equal(true);
    expect(settings["disableScore"]).to.equal(true);
  });

  it(`Update Poll End Time`, async function () {
    const topic = "my topic";
    const content = "my content";
    const maxPollOption = 3;
    const startTime = 1111122222;
    const endTime = 2000000000;
    const disableChange = 1;
    const onlyAllowlist = 1;
    const onlyTokenHolder = 1;
    const disableScore = 1;
    await contract.createPoll(
      topic,
      content,
      maxPollOption,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );

    // last poll id
    const pid = (await contract.pollCount()) - 1;
    expect(await contract.getPollEndTime(pid)).to.equal(endTime);

    // after update
    let customTime = 3876543211;
    await contract.setPollEndTime(pid, customTime);
    expect(await contract.getPollEndTime(pid)).to.equal(customTime);

    // check existing settings is not changed
    expect(await contract.getPollStartTime(pid)).to.equal(startTime);
    const settings = await contract.getPollSettings(pid);
    expect(settings["disableChange"]).to.equal(true);
    expect(settings["onlyAllowlist"]).to.equal(true);
    expect(settings["onlyTokenHolder"]).to.equal(true);
    expect(settings["disableScore"]).to.equal(true);
  });

  it("setPollContent()", async function () {
    // last poll id
    const pid = (await contract.pollCount()) - 1;

    let poll = await contract.polls(pid);
    expect(poll["content"]).to.equal("");
    expect(await contract.getPollContent(pid)).to.equal("");

    // update poll content
    const content = "ipfs://abc.com/1.html";
    await contract.setPollContent(pid, content);

    poll = await contract.polls(pid);
    expect(poll["content"]).to.equal(content);
    expect(await contract.getPollContent(pid)).to.equal(content);
  });

  it("setPollOptionName()", async function () {
    const pid = (await contract.pollCount()) - 1;

    // update poll option name
    await contract.setPollOptionName(pid, 1, "My option A");
    expect(await contract.getPollOptionName(pid, 1)).to.equal("My option A");

    // update poll option name
    await contract.setPollOptionName(pid, 2, "My option B");
    expect(await contract.getPollOptionName(pid, 2)).to.equal("My option B");

    // update poll option name
    await contract.setPollOptionName(pid, 3, "My option C");
    expect(await contract.getPollOptionName(pid, 3)).to.equal("My option C");

    // vote for wrong poll option value
    await expect(
      contract.setPollOptionName(pid, 4, "My option D")
    ).to.be.revertedWith("Set option name for non-existing option");
  });

  it(`Poll time locked by startTime`, async function () {
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 0;
    const onlyAllowlist = 0;
    const onlyTokenHolder = 0;
    const disableScore = 0;
    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );
    const pid = (await contract.pollCount()) - 1;
    expect(await contract.isPollStarted(pid)).to.equal(true);

    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      4000000000,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );
    const pid2 = (await contract.pollCount()) - 1;
    expect(await contract.isPollStarted(pid2)).to.equal(false);
  });

  it(`Poll time locked by endTime`, async function () {
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 0;
    const onlyAllowlist = 0;
    const onlyTokenHolder = 0;
    const disableScore = 0;
    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );
    const pid = (await contract.pollCount()) - 1;
    expect(await contract.isPollStarted(pid)).to.equal(true);

    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      startTime,
      100,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );
    const pid2 = (await contract.pollCount()) - 1;
    expect(await contract.isPollStarted(pid2)).to.equal(false);
  });

  it("Vote for Vote for non-existing option", async function () {
    const pid = (await contract.pollCount()) - 1;

    // vote for wrong poll option value
    await expect(contract.vote(pid, 0, 0)).to.be.revertedWith(
      "Vote for non-existing option"
    );

    // vote for wrong poll option value
    await expect(contract.vote(pid, 4, 0)).to.be.revertedWith(
      "Vote for non-existing option"
    );

    // test success vote
    await contract.vote(pid, 1, 0);

    // verify voter vote is correctly stored
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(1);
    expect(await contract.getPollTotalVoteCount(pid)).to.equal(1);
  });

  it("Voter address", async function () {
    const pid = (await contract.pollCount()) - 1;
    await contract.vote(pid, 1, 0);
    expect(await contract.getVoterAddress(pid, 0)).to.equal(ownerKey.address);
  });

  it("Vote count", async function () {
    const pid = (await contract.pollCount()) - 1;

    // add one vote
    await contract.vote(pid, 2, 0);

    // verify voter vote is correctly stored
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(2);
    expect(await contract.getPollTotalVoteCount(pid)).to.equal(1);
  });

  it("Vote for nft owner (success)", async function () {
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 0;
    const onlyAllowlist = 0;
    const onlyTokenHolder = 1;
    const disableScore = 0;
    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );
    // await nftContract.setRandomSeed(1234);
    await nftContract.ownerMint(ownerKey.address, 1);

    // vote
    const pid = (await contract.pollCount()) - 1;
    await contract.vote(pid, 1, 0);

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(1);
    expect(await contract.getPollOptionVoteCount(pid, 1)).to.equal(1);
  });

  it("Vote for nft owner (fail)", async function () {
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 0;
    const onlyAllowlist = 0;
    const onlyTokenHolder = 1;
    const disableScore = 0;
    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );
    // last poll id
    const pid = (await contract.pollCount()) - 1;
    await expect(contract.vote(pid, 1, 0)).to.be.revertedWith(
      "Voter is not target token owner"
    );
  });

  it("Vote for allowlist (success)", async function () {
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 0;
    const onlyAllowlist = 1;
    const onlyTokenHolder = 0;
    const disableScore = 0;
    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );
    // last poll id
    const pid = (await contract.pollCount()) - 1;

    // setup new signer and test
    await contract.setSigner(whitelistKey.address);
    const { chainId } = await ethers.provider.getNetwork();
    const sig = signWhitelist(
      chainId,
      contract.address,
      whitelistKey,
      ownerKey.address,
      pid
    );
    await contract.vote(pid, 1, sig);

    expect(await contract.verifySignature(sig, pid)).to.equal(true);
    // expect(await contract.recoverSigner(sig, pid)).to.equal(whitelistKey.address);
  });

  it("Vote for allowlist (wrong signature)", async function () {
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 0;
    const onlyAllowlist = 1;
    const onlyTokenHolder = 0;
    const disableScore = 0;
    await createPoll(
      contract,
      nftContract,
      soulIDContract,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyTokenHolder,
      disableScore
    );
    // last poll id
    const pid = (await contract.pollCount()) - 1;

    await contract.setSigner(whitelistKey.address);
    const { chainId } = await ethers.provider.getNetwork();
    const sig = signWhitelist(
      chainId,
      contract.address,
      guestKey,
      ownerKey.address,
      pid
    );

    expect(await contract.verifySignature(sig, pid)).to.equal(false);
    // expect(await contract.recoverSigner(sig, pid)).to.equal(guestKey.address);

    await expect(contract.vote(pid, 1, sig)).to.be.revertedWith(
      "Voter is not allowed"
    );
  });

  it(`Vote option A`, async function () {
    const pid = (await contract.pollCount()) - 1;
    expect(await contract.getPollOptionVoteCount(pid, 1)).to.equal(0);
    expect(await contract.getPollOptionVoteCount(pid, 2)).to.equal(0);
    expect(await contract.getPollOptionVoteCount(pid, 3)).to.equal(0);

    // vote
    await contract.vote(pid, 1, 0);

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(1);
    expect(await contract.getPollOptionVoteCount(pid, 1)).to.equal(1);
    expect(await contract.getPollOptionVoteCount(pid, 2)).to.equal(0);
    expect(await contract.getPollOptionVoteCount(pid, 3)).to.equal(0);
  });

  it(`Vote option B`, async function () {
    const pid = (await contract.pollCount()) - 1;
    expect(await contract.getPollOptionVoteCount(pid, 2)).to.equal(0);

    // vote
    await contract.vote(pid, 2, 0);

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(2);
    expect(await contract.getPollOptionVoteCount(pid, 2)).to.equal(1);
  });

  it(`Vote option C`, async function () {
    const pid = (await contract.pollCount()) - 1;
    expect(await contract.getPollOptionVoteCount(pid, 3)).to.equal(0);

    // vote
    await contract.vote(pid, 3, 0);

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(3);
    expect(await contract.getPollOptionVoteCount(pid, 3)).to.equal(1);
  });

  it(`Vote change from option A -> B`, async function () {
    const pid = (await contract.pollCount()) - 1;

    // vote first time
    await contract.vote(pid, 1, 0);

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(1);
    expect(await contract.getPollOptionVoteCount(pid, 1)).to.equal(1);
    expect(await contract.getPollOptionVoteCount(pid, 2)).to.equal(0);

    // vote change
    await contract.vote(pid, 2, 0);

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(2);
    expect(await contract.getPollOptionVoteCount(pid, 1)).to.equal(0);
    expect(await contract.getPollOptionVoteCount(pid, 2)).to.equal(1);
  });

  it(`Vote change from option B -> C`, async function () {
    const pid = (await contract.pollCount()) - 1;

    // vote first time
    await contract.vote(pid, 2, 0);

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(2);
    expect(await contract.getPollOptionVoteCount(pid, 2)).to.equal(1);
    expect(await contract.getPollOptionVoteCount(pid, 3)).to.equal(0);

    // vote change
    await contract.vote(pid, 3, 0);

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(3);
    expect(await contract.getPollOptionVoteCount(pid, 2)).to.equal(0);
    expect(await contract.getPollOptionVoteCount(pid, 3)).to.equal(1);
  });

  it(`Vote change from option B -> A -> C`, async function () {
    const pid = (await contract.pollCount()) - 1;

    // vote first time
    await contract.vote(pid, 2, 0);

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(2);
    expect(await contract.getPollOptionVoteCount(pid, 2)).to.equal(1);

    // vote change
    await contract.vote(pid, 1, 0);

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(1);
    expect(await contract.getPollOptionVoteCount(pid, 1)).to.equal(1);

    // vote change
    const tx4 = await contract.vote(pid, 3, 0);
    await tx4.wait();

    // check score
    expect(await contract.getAddressVote(pid, ownerKey.address)).to.equal(3);
    expect(await contract.getPollOptionVoteCount(pid, 3)).to.equal(1);
  });
});

async function signWhitelist(
  chainId,
  contractAddress,
  whitelistKey,
  mintingAddress,
  pollId
) {
  // Domain data should match whats specified in the DOMAIN_SEPARATOR constructed in the contract
  // https://github.com/msfeldstein/EIP712-whitelisting/blob/main/contracts/EIP712Whitelisting.sol#L33-L43
  const domain = {
    name: "WhitelistToken",
    version: "1",
    chainId,
    verifyingContract: contractAddress,
  };

  // The types should match the TYPEHASH specified in the contract
  // https://github.com/msfeldstein/EIP712-whitelisting/blob/main/contracts/EIP712Whitelisting.sol#L27-L28
  const types = {
    Minter: [
      { name: "wallet", type: "address" },
      { name: "pollId", type: "uint256" },
    ],
  };

  const sig = await whitelistKey._signTypedData(domain, types, {
    wallet: mintingAddress,
    pollId: pollId,
  });

  return sig;
}
