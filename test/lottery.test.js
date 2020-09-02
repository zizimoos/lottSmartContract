const Lottery = artifacts.require("Lottery");
const assertRevert = require("./assertRevert");
const expectEvent = require("./expectEvent");
const { assert } = require("chai");

contract("Lottery", function ([deployer, user1, user2]) {
  let lottery;
  let betAmount = 5 * 10 ** 15;
  let bet_block_interval = 3;

  beforeEach(async () => {
    // console.log("Before Each");
    lottery = await Lottery.new();
  });

  it("getPot should return current pot", async () => {
    let pot = await lottery.getPot();
    assert.equal(0, pot);
  });

  describe("Bet", function () {
    it("should fail when the bet money is not 0.005ETH", async () => {
      //FAIL transaction
      await assertRevert(
        lottery.bet("0xab", { from: user1, value: 4000000000000000 })
      );
      // transaction object {chainId, value, to, from, gas(Limit), gasPrice}
    });
    it("should put the bet to the bet queue with 1 bet", async () => {
      // BET
      let receipt = await lottery.bet("0xab", {
        from: user1,
        value: betAmount,
      });
      // console.log(receipt);

      let pot = await lottery.getPot();
      assert.equal(pot, 0);

      // check CONTRACT balance == 0.005
      let contractBalance = await web3.eth.getBalance(lottery.address);
      assert.equal(contractBalance, betAmount);

      let currentBlockNumber = await web3.eth.getBlockNumber();
      let bet = await lottery.getBetInfo(0);

      assert.equal(
        bet.answerBlockNumber,
        currentBlockNumber + bet_block_interval
      );
      assert.equal(bet.bettor, user1);
      assert.equal(bet.challenges, "0xab");
      // check bet info
      // check log
      await expectEvent.inLogs(receipt.logs, "BET");
    });
  });

  describe.only("isMatch", function () {
    let blockHash =
      "0xab98e92841b25739971d9ef4cc10ea8bc04ca521a30454bbfa0fc55ef1ada1b7";
    it("should be bettingResult.win when two characters match", async () => {
      let matchingResult = await lottery.isMatch("0xab", blockHash);
      assert.equal(matchingResult, 1);
    });
    it("should be bettingResult.win when two characters match", async () => {
      let matchingResult = await lottery.isMatch("0xcd", blockHash);
      assert.equal(matchingResult, 0);
    });
    it("should be bettingResult.win when two characters match", async () => {
      let matchingResult = await lottery.isMatch("0xad", blockHash);
      assert.equal(matchingResult, 2);
      matchingResult = await lottery.isMatch("0xfb", blockHash);
      assert.equal(matchingResult, 2);
    });
  });
});
