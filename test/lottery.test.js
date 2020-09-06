const Lottery = artifacts.require("Lottery");
const assertRevert = require("./assertRevert");
const expectEvent = require("./expectEvent");
const { assert } = require("chai");

contract("Lottery", function ([deployer, user1, user2]) {
  let lottery;
  let betAmount = 5 * 10 ** 15;
  let betAmountBN = new web3.utils.BN("5000000000000000");
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

  describe("Distribute", function () {
    describe("When the answer is checkable", function () {
      it("should give the user the pot when the answer matches", async () => {
        // 두 글자 다 맞을 때
        await lottery.setAnswerForTest(
          "0xab98e92841b25739971d9ef4cc10ea8bc04ca521a30454bbfa0fc55ef1ada1b7",
          { from: deployer }
        );
        // 1 -> 4
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 2 -> 5
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 3 -> 6
        await lottery.betAndDistribute("0xab", {
          from: user1,
          value: betAmount,
        });
        // 4 -> 7
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 5 -> 8
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 6 -> 9
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });

        let potBefore = await lottery.getPot(); // == 0.01 eth
        let user1BalanceBefore = await web3.eth.getBalance(user1);

        // 7 -> 10 // user1 에게 pot이 간다.
        let receipt7 = await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });

        let potAfter = await lottery.getPot(); // == 0 eth
        let user1BalanceAfter = await web3.eth.getBalance(user1); // == before + 0.015 eth
        // betAndDistribute

        // pot의 변화량 확인
        assert.equal(
          potBefore.toString(),
          new web3.utils.BN("10000000000000000").toString()
        );
        assert.equal(potAfter.toString(), new web3.utils.BN("0").toString());
        // assert.equal(potBefore);
        user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
        assert.equal(
          user1BalanceBefore.add(potBefore).add(betAmountBN).toString(),
          new web3.utils.BN(user1BalanceAfter).toString()
        );
        // user(winner)의 밸런스 확인
      });
      it("should give the user the amount he or her bet when a single character matches", async () => {
        // 한 글자 맞았을때
        await lottery.setAnswerForTest(
          "0xab98e92841b25739971d9ef4cc10ea8bc04ca521a30454bbfa0fc55ef1ada1b7",
          { from: deployer }
        );
        // 1 -> 4
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 2 -> 5
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 3 -> 6
        await lottery.betAndDistribute("0xaf", {
          from: user1,
          value: betAmount,
        });
        // 4 -> 7
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 5 -> 8
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 6 -> 9
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });

        let potBefore = await lottery.getPot(); // == 0.01 eth
        let user1BalanceBefore = await web3.eth.getBalance(user1);

        // 7 -> 10 // user1 에게 pot이 간다.
        let receipt7 = await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });

        let potAfter = await lottery.getPot(); // == 0.01 eth
        let user1BalanceAfter = await web3.eth.getBalance(user1); // == before + 0.005 eth
        // betAndDistribute

        // pot의 변화량 확인
        assert.equal(potBefore.toString(), potAfter.toString());

        // assert.equal(potBefore);
        user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
        assert.equal(
          user1BalanceBefore.add(betAmountBN).toString(),
          new web3.utils.BN(user1BalanceAfter).toString()
        );
        console.log(user1BalanceBefore.add(betAmountBN).toString());
        // user(winner)의 밸런스 확인
      });
      it.only("should get the eth of user when the answer does not matches at all", async () => {
        // 두 글자 모두 틀렸을 때
        await lottery.setAnswerForTest(
          "0xab98e92841b25739971d9ef4cc10ea8bc04ca521a30454bbfa0fc55ef1ada1b7",
          { from: deployer }
        );
        // 1 -> 4
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 2 -> 5
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 3 -> 6
        await lottery.betAndDistribute("0xdf", {
          from: user1,
          value: betAmount,
        });
        // 4 -> 7
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 5 -> 8
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });
        // 6 -> 9
        await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });

        let potBefore = await lottery.getPot(); // == 0.01 eth
        let user1BalanceBefore = await web3.eth.getBalance(user1);

        // 7 -> 10 // user1 에게 pot이 간다.
        let receipt7 = await lottery.betAndDistribute("0xef", {
          from: user2,
          value: betAmount,
        });

        let potAfter = await lottery.getPot(); // == 0.015 eth
        let user1BalanceAfter = await web3.eth.getBalance(user1); // == before
        // betAndDistribute

        // pot의 변화량 확인
        assert.equal(
          potBefore.add(betAmountBN).toString(),
          potAfter.toString()
        );

        // assert.equal(potBefore);
        // user(winner)의 밸런스 확인
        user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
        assert.equal(
          user1BalanceBefore.toString(),
          new web3.utils.BN(user1BalanceAfter).toString()
        );
        console.log(user1BalanceBefore.add(betAmountBN).toString());
      });
    });
    describe("When the answer is not revealed(not mined)", function () {});
    describe("When the answer is not revealed(block limit is passed)", function () {});
  });

  describe("isMatch", function () {
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
