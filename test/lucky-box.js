const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Lucky Box", function () {
  let contract;

  beforeEach(async function () {
    accounts = await ethers.getSigners();

    gasPrice = await ethers.provider.getGasPrice();
    gasLimit = ethers.utils.hexlify(3000000);

    //////// (dependent contract) VoteBox contract
    // const TokenNFT = await ethers.getContractFactory('NFT721Random');
    // nftContract = await TokenNFT.deploy();
    // await nftContract.setUnrevealURI('');
    // await nftContract.changeVRFSubId(3178);
    const TokenNFT = await ethers.getContractFactory("NFT721AStruct");
    nftContract = await TokenNFT.deploy();
    nftContractAddress = nftContract.address;

    const TokenVote = await ethers.getContractFactory("VoteBox");
    voteContract = await TokenVote.deploy();
    await voteContract.deployed();
    // create voting topic
    const topic = "my topic";
    const content = "my content";
    const maxPollOption = 3;
    const startTime = 1;
    const endTime = 2000000000;
    const disableChange = 0;
    const onlyAllowlist = 0;
    const onlyNftHolder = 0;
    const disableScore = 0;
    await voteContract.createPoll(
      topic,
      content,
      maxPollOption,
      startTime,
      endTime,
      disableChange,
      onlyAllowlist,
      onlyNftHolder,
      disableScore
    );
    await voteContract.setPollTokenContract(0, nftContract.address);
    // await voteContract.setPollScoreContract(0, nftContract.address);

    // create 20 voters for lucky draw potential winners
    for (let i = 0; i < 20; i++) {
      await voteContract.connect(accounts[i]).vote(0, 1, 0);
    }

    /////// contract deployment
    const chainlinkSubId = 3178;
    const Token = await ethers.getContractFactory("LuckyBox");
    contract = await Token.deploy(chainlinkSubId);
    await contract.deployed();
  });

  it("Create Lucky Draw", async function () {
    const topic = "Lucky draw test";
    const content = "https://example.com/";
    const poolSize = 10;
    const winnerSize = 3;
    const drawTime = 1600000000;
    const voteBoxPollId = 0;
    const voteBoxContract = voteContract.address;
    await contract.createDraw(
      topic,
      content,
      poolSize,
      winnerSize,
      drawTime,
      voteBoxPollId,
      voteBoxContract
    );

    const drawIndex = (await contract.eventCount()) - 1;
    const draw = await contract.drawEvents(drawIndex);
    expect(draw["topic"]).to.equal(topic);
    expect(draw["content"]).to.equal(content);
    expect(draw["poolSize"]).to.equal(poolSize);
    expect(draw["winnerSize"]).to.equal(winnerSize);
    expect(draw["drawTime"]).to.equal(drawTime);
    expect(draw["voteBoxPollId"]).to.equal(voteBoxPollId);
    expect(draw["voteBoxContract"]).to.equal(voteBoxContract);
  });

  it("Create Lucky Draw, Topic is empty", async function () {
    const topic = "";
    const content = "https://example.com/";
    const poolSize = 1;
    const winnerSize = 1;
    const drawTime = 1600000000;
    const voteBoxPollId = 0;
    const voteBoxContract = voteContract.address;
    await expect(
      contract.createDraw(
        topic,
        content,
        poolSize,
        winnerSize,
        drawTime,
        voteBoxPollId,
        voteBoxContract
      )
    ).to.be.revertedWith("Topic is empty");
  });

  it("Create Lucky Draw, Pool size zero", async function () {
    const topic = "Lucky draw test";
    const content = "https://example.com/";
    const poolSize = 0;
    const winnerSize = 1;
    const drawTime = 1600000000;
    const voteBoxPollId = 0;
    const voteBoxContract = voteContract.address;
    await expect(
      contract.createDraw(
        topic,
        content,
        poolSize,
        winnerSize,
        drawTime,
        voteBoxPollId,
        voteBoxContract
      )
    ).to.be.revertedWith("Pool size is zero");
  });

  it("Create Lucky Draw, Winner size zero", async function () {
    const topic = "Lucky draw test";
    const content = "https://example.com/";
    const poolSize = 1;
    const winnerSize = 0;
    const drawTime = 1600000000;
    const voteBoxPollId = 0;
    const voteBoxContract = voteContract.address;
    await expect(
      contract.createDraw(
        topic,
        content,
        poolSize,
        winnerSize,
        drawTime,
        voteBoxPollId,
        voteBoxContract
      )
    ).to.be.revertedWith("Winner size is zero");
  });

  it("Draw with random seed, get winners ids, get winner voter addresses", async function () {
    const topic = "Lucky draw test";
    const content = "https://example.com/";
    const drawTime = 1600000000;
    const voteBoxPollId = 0;
    const voteBoxContract = voteContract.address;
    let poolSize = 20;
    let winnerSize = 5;
    await contract.createDraw(
      topic,
      content,
      poolSize,
      winnerSize,
      drawTime,
      voteBoxPollId,
      voteBoxContract
    );

    // before draw
    expect(await contract.seededEventCount()).to.equal(0);
    await expect(contract.getAllWinners(0)).to.be.revertedWith(
      "Draw is not seeded"
    );

    // after draw
    contract.testDraw(1234);
    expect(await contract.seededEventCount()).to.equal(1);

    const winners = await contract.getAllWinners(0);
    expect(winners.length).to.equal(winnerSize);

    for (let i = 0; i < winners.length; i++) {
      let winnerId = winners[i];
      let winnerIdByIndex = await contract.getWinnerByIndex(0, i);
      // getAllWinners() = getWinnerByIndex() by winnerIndex
      expect(winnerIdByIndex).to.equal(winnerId);

      // getWinnerVoterAddress() = actual voter wallet address
      expect(await contract.getWinnerVoterAddress(0, i)).to.equal(
        accounts[winnerId].address
      );
    }
  });

  it("WinnerSize = PoolSize = 1 : 1", async function () {
    const topic = "Lucky draw test";
    const content = "https://example.com/";
    const drawTime = 1600000000;
    const voteBoxPollId = 0;
    const voteBoxContract = voteContract.address;
    let poolSize = 1;
    let winnerSize = 1;
    await contract.createDraw(
      topic,
      content,
      poolSize,
      winnerSize,
      drawTime,
      voteBoxPollId,
      voteBoxContract
    );
    contract.testDraw(1234);

    const winnerIds = await contract.getAllWinners(0);
    expect(winnerIds.length).to.equal(winnerSize);
    // all winners is unique
    let ids = [];
    for (i = 0; i < winnerIds.length; i++) {
      ids.push(winnerIds[i].toNumber());
    }
    console.log(`winners ${winnerSize} in ${poolSize}`, ids);

    const uniqueCount = new Set(ids).size;
    expect(uniqueCount).to.equal(winnerIds.length);
  });

  it("WinnerSize = PoolSize = 10 : 10", async function () {
    const topic = "Lucky draw test";
    const content = "https://example.com/";
    const drawTime = 1600000000;
    const voteBoxPollId = 0;
    const voteBoxContract = voteContract.address;
    let poolSize = 10;
    let winnerSize = 10;
    await contract.createDraw(
      topic,
      content,
      poolSize,
      winnerSize,
      drawTime,
      voteBoxPollId,
      voteBoxContract
    );
    contract.testDraw(1234);

    const winnerIds = await contract.getAllWinners(0);
    expect(winnerIds.length).to.equal(winnerSize);
    // all winners is unique
    let ids = [];
    for (i = 0; i < winnerIds.length; i++) {
      ids.push(winnerIds[i].toNumber());
    }
    console.log(`winners ${winnerSize} in ${poolSize}`, ids);

    const uniqueCount = new Set(ids).size;
    expect(uniqueCount).to.equal(winnerIds.length);
  });

  it("WinnerSize < PoolSize = 10 : 200", async function () {
    const topic = "Lucky draw test";
    const content = "https://example.com/";
    const drawTime = 1600000000;
    const voteBoxPollId = 0;
    const voteBoxContract = voteContract.address;
    let poolSize = 200;
    let winnerSize = 10;
    await contract.createDraw(
      topic,
      content,
      poolSize,
      winnerSize,
      drawTime,
      voteBoxPollId,
      voteBoxContract
    );
    contract.testDraw(1234);

    const winnerIds = await contract.getAllWinners(0);
    expect(winnerIds.length).to.equal(winnerSize);
    // all winners is unique
    let ids = [];
    for (i = 0; i < winnerIds.length; i++) {
      ids.push(winnerIds[i].toNumber());
    }
    console.log(`winners ${winnerSize} in ${poolSize}`, ids);

    const uniqueCount = new Set(ids).size;
    expect(uniqueCount).to.equal(winnerIds.length);
  });

  it("WinnerSize > PoolSize = 200 : 10", async function () {
    const topic = "Lucky draw test";
    const content = "https://example.com/";
    const drawTime = 1600000000;
    const voteBoxPollId = 0;
    const voteBoxContract = voteContract.address;
    let poolSize = 10;
    let winnerSize = 200;
    await contract.createDraw(
      topic,
      content,
      poolSize,
      winnerSize,
      drawTime,
      voteBoxPollId,
      voteBoxContract
    );
    contract.testDraw(1234);

    const winnerIds = await contract.getAllWinners(0);
    expect(winnerIds.length).to.equal(poolSize);
    // all winners is unique
    let ids = [];
    for (i = 0; i < winnerIds.length; i++) {
      ids.push(winnerIds[i].toNumber());
    }
    console.log(`winners ${winnerSize} in ${poolSize}`, ids);

    const uniqueCount = new Set(ids).size;
    expect(uniqueCount).to.equal(winnerIds.length);
  });

  it("WinnerSize < PoolSize = 10 : 15000", async function () {
    const topic = "Lucky draw test";
    const content = "https://example.com/";
    const drawTime = 1600000000;
    const voteBoxPollId = 0;
    const voteBoxContract = voteContract.address;
    let poolSize = 15000;
    let winnerSize = 10;
    await contract.createDraw(
      topic,
      content,
      poolSize,
      winnerSize,
      drawTime,
      voteBoxPollId,
      voteBoxContract
    );
    contract.testDraw(1234);

    const winnerIds = await contract.getAllWinners(0);
    expect(winnerIds.length).to.equal(winnerSize);
    // all winners is unique
    let ids = [];
    for (i = 0; i < winnerIds.length; i++) {
      ids.push(winnerIds[i].toNumber());
    }
    console.log(`winners ${winnerSize} in ${poolSize}`, ids);

    const uniqueCount = new Set(ids).size;
    expect(uniqueCount).to.equal(winnerIds.length);
  });
});
