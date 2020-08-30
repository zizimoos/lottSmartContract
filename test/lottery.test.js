const Lottery = artifacts.require("Lottery");
const assertRevert = require("./assertRevert");

contract("Lottery", function ([deployer, user1, user2]) {
  let lottery;
  beforeEach(async () => {
    console.log("Before Each");
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
    it.only("should put th bet to the bet queue with 1 bet", async () => {
      // BET
      await lottery.bet("0xab", { from: user1, value: 5000000000000000 });
      // check CONTRACT balance == 0.005
      // check bet info
      // check log
    });
  });
});
